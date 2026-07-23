"""Mini simulateur 65816 + PPU SNES (sous-ensemble suffisant pour nos jeux).

Modele : WRAM 8 Ko (banque 0), ROM LoROM 32 Ko a $8000, MMIO $21xx/$42xx/$43xx,
DMA canal 0 (VRAM/CGRAM/OAM), HDMA canal 1 lu par le rendu (degrade),
NMI natif (push PBR,PCH,PCL,P / RTI symetrique). CPU: sous-ensemble 8 bits
(le jeu reste en sep #$30 — c'est le choix du portage).
"""
from PIL import Image

class SNES:
    def __init__(self, rom_path, sram=None):
        self.rom = open(rom_path, 'rb').read()
        assert len(self.rom) % 0x8000 == 0        # LoROM : n banques de 32 Ko
        # la SRAM survit a l'extinction : on peut la passer d'une instance
        # a l'autre pour simuler un cycle d'alimentation
        self.sram = sram if sram is not None else bytearray(0x2000)
        self.ram = bytearray(0x2000)
        self.vram = bytearray(0x10000)
        self.cgram = bytearray(512)
        self.oam = bytearray(544)
        self.regs = {}
        self.vaddr = 0
        self.cgaddr = 0
        self.cglatch = None
        self.oamaddr = 0
        self.scroll_latch = {}
        self.joy = 0
        self.nmitimen = 0
        self.frames = 0
        # --- APU (SPC700) : boites aux lettres $2140-$2143 ---
        # Etats: 'boot' (IPL dit AA/BB), 'upload' (dictée octet par octet),
        # 'run' (notre pilote: commandes voix/pitch, echo du compteur).
        self.apu_state = 'boot'
        self.apu_out = [0xAA, 0xBB, 0x00, 0x00]   # ce que lit le 65816
        self.apu_in = [0, 0, 0, 0]                # ce qu'il a ecrit
        self.apu_ram = bytearray(0x10000)
        self.apu_addr = 0
        self.apu_expect = 0                       # index IPL attendu (8 bits)
        self.apu_count = 0                        # octets recus au total
        self.spc_events = []                      # (frame, voix, pitch)
        # CPU
        self.A = self.X = self.Y = 0
        self.B = 0                     # l'octet HAUT cache de l'accumulateur
        self.S = 0x1FF
        self.P = 0x34
        self.PC = self.rom[0x7FFC] | (self.rom[0x7FFD] << 8)
        self.trace = None

    # ---------------- adressage long (24 bits, LoROM) ----------------
    def read_long(self, b, a):
        b &= 0xFF; a &= 0xFFFF
        if 0x70 <= (b & 0x7F) <= 0x7D:
            return self.sram[a & 0x1FFF]
        if (b & 0x7F) <= 0x3F:
            if a >= 0x8000:
                off = ((b & 0x3F) << 15) | (a & 0x7FFF)
                return self.rom[off] if off < len(self.rom) else 0
            return self.read(a)
        return 0

    def write_long(self, b, a, v):
        b &= 0xFF; a &= 0xFFFF
        if 0x70 <= (b & 0x7F) <= 0x7D:
            self.sram[a & 0x1FFF] = v & 0xFF
            return
        if (b & 0x7F) <= 0x3F and a < 0x8000:
            self.write(a, v)

    # ---------------- bus ----------------
    def read(self, a):
        a &= 0xFFFF
        if a < 0x2000: return self.ram[a]
        if a >= 0x8000: return self.rom[a - 0x8000]
        if a == 0x4210: return 0x80
        if a == 0x4212: return 0
        if a == 0x4219: return self.joy
        if 0x2140 <= a <= 0x2143: return self.apu_out[a - 0x2140]
        return self.regs.get(a, 0)

    def apu_write(self, port, v):
        self.apu_in[port] = v
        if self.apu_state == 'boot':
            if port == 0 and v == 0xCC:           # "pret ?" -> adresse recue
                self.apu_addr = self.apu_in[2] | (self.apu_in[3] << 8)
                self.apu_count = 0
                self.apu_expect = 0
                self.apu_state = 'upload'
                self.apu_out[0] = 0xCC            # "pret !"
        elif self.apu_state == 'upload':
            if port == 0:
                if v == self.apu_expect:          # un octet de plus
                    self.apu_ram[(self.apu_addr + self.apu_count) & 0xFFFF] = self.apu_in[1]
                    self.apu_count += 1
                    self.apu_expect = (self.apu_expect + 1) & 0xFF
                    self.apu_out[0] = v           # accuse de reception
                else:                             # index+2 : saut (ou nouveau bloc)
                    self.apu_addr = self.apu_in[2] | (self.apu_in[3] << 8)
                    if self.apu_in[1] == 0:       # port1 nul = "execute !"
                        self.apu_state = 'run'
                        self.spc_boot()           # init DSP + calage compteur...
                        for _ in range(3000):     # ...AVANT la 1re commande
                            self.spc_step()
                    self.apu_count = 0
                    self.apu_expect = 0
                    self.apu_out[0] = v
        else:                                     # 'run' : le pilote TOURNE
            if port == 3:                         # boite 3 = "nouvelle commande"
                self.spc_run(v)

    # --- mini-interpreteur SPC700 : on EXECUTE le blob assemble a la main ---
    def spc_boot(self):
        self.spc_pc = self.apu_addr
        self.spc_a = self.spc_x = 0
        self.spc_z = False
        self.dsp = {}
        self.dsp_addr = 0

    def spc_step(self):
        m = self.apu_ram
        def rd(a):
            if a == 0xF4: return self.apu_in[0]
            if a == 0xF5: return self.apu_in[1]
            if a == 0xF6: return self.apu_in[2]
            if a == 0xF7: return self.apu_in[3]
            return m[a]
        def wr(a, v):
            if a == 0xF2: self.dsp_addr = v; return
            if a == 0xF3:
                self.dsp[self.dsp_addr] = v
                if self.dsp_addr == 0x4C and v:       # KON : une note part !
                    voix = v.bit_length() - 1
                    pitch = self.dsp.get(voix*16+2, 0) | (self.dsp.get(voix*16+3, 0) << 8)
                    self.spc_events.append((self.frames, voix, pitch))
                if self.dsp_addr == 0x5C and v:       # KOF : silence
                    voix = v.bit_length() - 1
                    self.spc_events.append((self.frames, voix, 0))
                return
            if 0xF4 <= a <= 0xF7: self.apu_out[a - 0xF4] = v; return
            m[a] = v
        pc = self.spc_pc
        o = m[pc]
        def rel(off): return (pc + 2 + (off - 256 if off & 0x80 else off)) & 0xFFFF
        if   o == 0xCD: self.spc_x = m[pc+1]; self.spc_pc = pc+2
        elif o == 0xF5:
            self.spc_a = rd(((m[pc+1] | (m[pc+2] << 8)) + self.spc_x) & 0xFFFF)
            self.spc_pc = pc+3
        elif o == 0x68: self.spc_z = (self.spc_a == m[pc+1]); self.spc_pc = pc+2
        elif o == 0xF0: self.spc_pc = rel(m[pc+1]) if self.spc_z else pc+2
        elif o == 0xD0: self.spc_pc = pc+2 if self.spc_z else rel(m[pc+1])
        elif o == 0x2F: self.spc_pc = rel(m[pc+1])
        elif o == 0xC4: wr(m[pc+1], self.spc_a); self.spc_pc = pc+2
        elif o == 0xE4: self.spc_a = rd(m[pc+1]); self.spc_pc = pc+2
        elif o == 0xE8: self.spc_a = m[pc+1]; self.spc_pc = pc+2
        elif o == 0xF8: self.spc_x = rd(m[pc+1]); self.spc_pc = pc+2
        elif o == 0x3D: self.spc_x = (self.spc_x + 1) & 0xFF; self.spc_pc = pc+1
        elif o == 0x1C: self.spc_a = (self.spc_a << 1) & 0xFF; self.spc_pc = pc+1
        elif o == 0x28: self.spc_a &= m[pc+1]; self.spc_pc = pc+2
        elif o == 0x08: self.spc_a |= m[pc+1]; self.spc_z = self.spc_a == 0; self.spc_pc = pc+2
        elif o == 0x04:
            self.spc_a |= rd(m[pc+1]); self.spc_z = self.spc_a == 0; self.spc_pc = pc+2
        elif o == 0x64: self.spc_z = (self.spc_a == rd(m[pc+1])); self.spc_pc = pc+2
        else:
            raise RuntimeError(f"opcode SPC700 inconnu ${o:02X} en ${pc:04X}")

    def spc_run(self, attendu):
        """Fait tourner le pilote jusqu'a ce qu'il accuse reception (echo)."""
        for _ in range(20000):
            if self.apu_out[0] == attendu: return
            self.spc_step()
        raise RuntimeError(f"pilote SPC700 muet (echo {attendu} jamais recu)")

    def write(self, a, v):
        a &= 0xFFFF; v &= 0xFF
        if a < 0x2000: self.ram[a] = v; return
        if 0x2140 <= a <= 0x2143: self.apu_write(a - 0x2140, v); return
        if a == 0x2116: self.vaddr = (self.vaddr & 0xFF00) | v; return
        if a == 0x2117: self.vaddr = (self.vaddr & 0x00FF) | (v << 8); return
        if a == 0x2118: self.vram[(self.vaddr & 0x7FFF) * 2] = v; return
        if a == 0x2119:
            self.vram[(self.vaddr & 0x7FFF) * 2 + 1] = v
            pas = 32 if (self.regs.get(0x2115, 0x80) & 3) == 1 else 1
            self.vaddr = (self.vaddr + pas) & 0xFFFF
            return
        if a == 0x2121: self.cgaddr = v * 2; self.cglatch = None; return
        if a == 0x2122:
            self.cgram[self.cgaddr % 512] = v
            self.cgaddr += 1
            return
        if a == 0x2102: self.oamaddr = (self.oamaddr & 0x100) | v; return
        if a == 0x2103: self.oamaddr = ((v & 1) << 8) | (self.oamaddr & 0xFF); return
        if a == 0x2104:
            self.oam[self.oamaddr * 2 % 544] = v   # (simplifie : DMA seulement)
            return
        if 0x210D <= a <= 0x2114:
            prev = self.scroll_latch.get(a)
            if prev is None:
                self.scroll_latch[a] = v
                self.regs[a] = (self.regs.get(a, 0) & 0xFF00) | v
            else:
                self.regs[a] = ((v & 7) << 8) | prev
                self.scroll_latch[a] = None
            return
        if a == 0x4200: self.nmitimen = v; self.regs[a] = v; return
        if a == 0x420B and v: self.do_dma(); return
        if a == 0x4203:                      # multiplication materielle 8x8
            self.regs[a] = v
            p = self.regs.get(0x4202, 0) * v
            self.regs[0x4216] = p & 0xFF
            self.regs[0x4217] = (p >> 8) & 0xFF
            return
        if a == 0x4206:                      # division materielle 16/8
            self.regs[a] = v
            n = self.regs.get(0x4204, 0) | (self.regs.get(0x4205, 0) << 8)
            q, r = (0xFFFF, n) if v == 0 else divmod(n, v)
            self.regs[0x4214] = q & 0xFF
            self.regs[0x4215] = (q >> 8) & 0xFF
            self.regs[0x4216] = r & 0xFF
            self.regs[0x4217] = (r >> 8) & 0xFF
            return
        self.regs[a] = v

    def do_dma(self):
        dmap = self.regs.get(0x4300, 0)
        bbad = self.regs.get(0x4301, 0)
        src = self.regs.get(0x4302, 0) | (self.regs.get(0x4303, 0) << 8)
        srcb = self.regs.get(0x4304, 0)          # la BANQUE de la source
        size = self.regs.get(0x4305, 0) | (self.regs.get(0x4306, 0) << 8)
        if size == 0: size = 0x10000
        fixed = bool(dmap & 8)
        mode = dmap & 7
        oam_i = self.oamaddr * 2
        for i in range(size):
            b = self.read_long(srcb, src if fixed else (src + i))
            if bbad == 0x18 or bbad == 0x19:      # mode 1 : alterne 18/19
                self.write(0x2118 + (i & 1 if mode == 1 else 0), b)
            elif bbad == 0x22:
                self.write(0x2122, b)
            elif bbad == 0x04:
                self.oam[(oam_i + i) % 544] = b
            else:
                self.write(0x2100 + bbad, b)

    # ---------------- CPU (sous-ensemble 8 bits) ----------------
    def push(self, v): self.ram[self.S] = v & 0xFF; self.S -= 1
    def pull(self): self.S += 1; return self.ram[self.S]
    def setnz(self, v):
        self.P = (self.P & ~0x82) | (0x80 if v & 0x80 else 0) | (0x02 if v == 0 else 0)
    def fetch(self):
        v = self.read(self.PC); self.PC = (self.PC + 1) & 0xFFFF; return v
    def fetch16(self):
        lo = self.fetch(); return lo | (self.fetch() << 8)

    def nmi(self):
        if not (self.nmitimen & 0x80): return
        self.push(0)                       # PBR
        self.push(self.PC >> 8)
        self.push(self.PC & 0xFF)
        self.push(self.P)
        self.PC = self.rom[0x7FEA] | (self.rom[0x7FEB] << 8)

    def step(self, n=1):
        for _ in range(n):
            self.op()

    def op(self):
        pc0 = self.PC
        o = self.fetch()
        A, X, Y = self.A, self.X, self.Y
        def adc(v):
            c = self.P & 1
            r = (self.A & 0xFF) + v + c
            self.P = (self.P & ~0x41) | (1 if r > 0xFF else 0) | \
                     (0x40 if (~((self.A ^ v)) & (self.A ^ r) & 0x80) else 0)
            self.A = r & 0xFF; self.setnz(self.A)
        def sbc(v): adc(v ^ 0xFF)
        def cmp_(reg, v):
            r = (reg - v) & 0x1FF
            self.P = (self.P & ~0x01) | (1 if reg >= v else 0)
            self.setnz((reg - v) & 0xFF)
        def bra(cond):
            off = self.fetch()
            if cond:
                self.PC = (self.PC + (off - 256 if off & 0x80 else off)) & 0xFFFF

        # ---------- le 65816 grandeur nature : largeurs M/X et 24 bits ----------
        m16 = not (self.P & 0x20)              # accumulateur 16 bits ?
        i16 = not (self.P & 0x10)              # index 16 bits ?
        def setnz16(v):
            self.P = (self.P & ~0x82) | (0x80 if v & 0x8000 else 0) | \
                     (0x02 if v == 0 else 0)
        def getC(): return self.A | (self.B << 8)
        def setC(v):
            self.A = v & 0xFF; self.B = (v >> 8) & 0xFF

        # --- adressage long (24 bits) : lda/sta f:..., et pointeurs [dp] ---
        if o in (0xAF, 0xBF):                  # LDA long / long,X
            ea = self.fetch16() | (self.fetch() << 16)
            if o == 0xBF: ea += self.X
            if m16:
                v = self.read_long(ea >> 16, ea) | \
                    (self.read_long(ea >> 16, ea + 1) << 8)
                setC(v); setnz16(v)
            else:
                self.A = self.read_long(ea >> 16, ea); self.setnz(self.A)
            return
        if o in (0x8F, 0x9F):                  # STA long / long,X
            ea = self.fetch16() | (self.fetch() << 16)
            if o == 0x9F: ea += self.X
            self.write_long(ea >> 16, ea, self.A)
            if m16: self.write_long(ea >> 16, ea + 1, self.B)
            return
        if o in (0xA7, 0xB7, 0x97):            # LDA/STA [dp](,Y) — pointeur long
            d = self.fetch()
            ptr = self.ram[d] | (self.ram[(d+1) & 0xFF] << 8) | \
                  (self.ram[(d+2) & 0xFF] << 16)
            ea = ptr + (self.Y if o != 0xA7 else 0)
            if o == 0x97:
                self.write_long(ea >> 16, ea, self.A)
            else:
                self.A = self.read_long(ea >> 16, ea); self.setnz(self.A)
            return
        if o == 0x1A:                          # INC A (n'existait pas sur 6502 !)
            if m16: v = (getC() + 1) & 0xFFFF; setC(v); setnz16(v)
            else: self.A = (self.A + 1) & 0xFF; self.setnz(self.A)
            return
        if o == 0x3A:                          # DEC A
            if m16: v = (getC() - 1) & 0xFFFF; setC(v); setnz16(v)
            else: self.A = (self.A - 1) & 0xFF; self.setnz(self.A)
            return

        # --- accumulateur 16 bits (rep #$20) : le sous-ensemble du cours ---
        if m16 and o in (0xA9, 0xA5, 0x85, 0xAD, 0x8D, 0x69, 0x65, 0xE9,
                         0xC9, 0x0A, 0x48, 0x68):
            def adc16(v):
                c = self.P & 1
                C0 = getC()
                r = C0 + v + c
                self.P = (self.P & ~0x41) | (1 if r > 0xFFFF else 0) | \
                         (0x40 if (~(C0 ^ v) & (C0 ^ r) & 0x8000) else 0)
                setC(r & 0xFFFF); setnz16(getC())
            if   o == 0xA9: v = self.fetch16(); setC(v); setnz16(v)
            elif o == 0xA5:
                d = self.fetch()
                v = self.ram[d] | (self.ram[(d+1) & 0xFF] << 8)
                setC(v); setnz16(v)
            elif o == 0x85:
                d = self.fetch()
                self.ram[d] = self.A; self.ram[(d+1) & 0xFF] = self.B
            elif o == 0xAD:
                a = self.fetch16()
                v = self.read(a) | (self.read(a+1) << 8); setC(v); setnz16(v)
            elif o == 0x8D:
                a = self.fetch16()
                self.write(a, self.A); self.write(a+1, self.B)
            elif o == 0x69: adc16(self.fetch16())
            elif o == 0x65:
                d = self.fetch()
                adc16(self.ram[d] | (self.ram[(d+1) & 0xFF] << 8))
            elif o == 0xE9: adc16(self.fetch16() ^ 0xFFFF)
            elif o == 0xC9:
                v = self.fetch16(); C0 = getC()
                self.P = (self.P & ~0x01) | (1 if C0 >= v else 0)
                setnz16((C0 - v) & 0xFFFF)
            elif o == 0x0A:
                C0 = getC()
                self.P = (self.P & ~1) | (C0 >> 15)
                setC((C0 << 1) & 0xFFFF); setnz16(getC())
            elif o == 0x48: self.push(self.B); self.push(self.A)
            elif o == 0x68:
                self.A = self.pull(); self.B = self.pull()
                setnz16(getC())
            return

        # --- index 16 bits (rep #$10) : idem ---
        if i16 and o in (0xA2, 0xA0, 0xE0, 0xC0, 0xE8, 0xCA, 0xC8, 0x88,
                         0xDA, 0xFA, 0x5A, 0x7A, 0xA8, 0xAA):
            if   o == 0xA2: self.X = self.fetch16(); setnz16(self.X)
            elif o == 0xA0: self.Y = self.fetch16(); setnz16(self.Y)
            elif o == 0xE0:
                v = self.fetch16()
                self.P = (self.P & ~0x01) | (1 if self.X >= v else 0)
                setnz16((self.X - v) & 0xFFFF)
            elif o == 0xC0:
                v = self.fetch16()
                self.P = (self.P & ~0x01) | (1 if self.Y >= v else 0)
                setnz16((self.Y - v) & 0xFFFF)
            elif o == 0xE8: self.X = (self.X + 1) & 0xFFFF; setnz16(self.X)
            elif o == 0xCA: self.X = (self.X - 1) & 0xFFFF; setnz16(self.X)
            elif o == 0xC8: self.Y = (self.Y + 1) & 0xFFFF; setnz16(self.Y)
            elif o == 0x88: self.Y = (self.Y - 1) & 0xFFFF; setnz16(self.Y)
            elif o == 0xDA: self.push(self.X >> 8); self.push(self.X & 0xFF)
            elif o == 0xFA:
                self.X = self.pull(); self.X |= self.pull() << 8
                setnz16(self.X)
            elif o == 0x5A: self.push(self.Y >> 8); self.push(self.Y & 0xFF)
            elif o == 0x7A:
                self.Y = self.pull(); self.Y |= self.pull() << 8
                setnz16(self.Y)
            elif o == 0xA8: self.Y = getC(); setnz16(self.Y)   # TAY copie B aussi !
            elif o == 0xAA: self.X = getC(); setnz16(self.X)
            return

        if   o == 0x78 or o == 0x18 and False: pass
        if   o == 0x78: pass                                   # SEI
        elif o == 0x18: self.P &= ~1                           # CLC
        elif o == 0x38: self.P |= 1                            # SEC
        elif o == 0xFB: pass                                   # XCE
        elif o == 0xE2:                                        # SEP
            self.P |= self.fetch()
            if self.P & 0x10:                  # index redevenus 8 bits :
                self.X &= 0xFF; self.Y &= 0xFF # les octets hauts s'evaporent
        elif o == 0xC2: self.P &= ~self.fetch()                # REP
        elif o == 0xEA: pass                                   # NOP
        # --- LDA ---
        elif o == 0xA9: self.A = self.fetch(); self.setnz(self.A)
        elif o == 0xA5: self.A = self.read(self.fetch()); self.setnz(self.A)
        elif o == 0xB5: self.A = self.read((self.fetch() + X) & 0xFF); self.setnz(self.A)
        elif o == 0xAD: self.A = self.read(self.fetch16()); self.setnz(self.A)
        elif o == 0xBD: self.A = self.read(self.fetch16() + X); self.setnz(self.A)
        elif o == 0xB9: self.A = self.read(self.fetch16() + Y); self.setnz(self.A)
        elif o == 0xB1:
            d = self.fetch()
            ptr = self.ram[d] | (self.ram[(d + 1) & 0xFF] << 8)
            self.A = self.read(ptr + Y); self.setnz(self.A)
        # --- LDX / LDY ---
        elif o == 0xA2: self.X = self.fetch(); self.setnz(self.X)
        elif o == 0xA6: self.X = self.read(self.fetch()); self.setnz(self.X)
        elif o == 0xAE: self.X = self.read(self.fetch16()); self.setnz(self.X)
        elif o == 0xBE: self.X = self.read(self.fetch16() + Y); self.setnz(self.X)
        elif o == 0xA0: self.Y = self.fetch(); self.setnz(self.Y)
        elif o == 0xA4: self.Y = self.read(self.fetch()); self.setnz(self.Y)
        elif o == 0xAC: self.Y = self.read(self.fetch16()); self.setnz(self.Y)
        elif o == 0xBC: self.Y = self.read(self.fetch16() + X); self.setnz(self.Y)
        # --- STA / STX / STY / STZ ---
        elif o == 0x85: self.write(self.fetch(), self.A)
        elif o == 0x95: self.write((self.fetch() + X) & 0xFF, self.A)
        elif o == 0x8D: self.write(self.fetch16(), self.A)
        elif o == 0x9D: self.write(self.fetch16() + X, self.A)
        elif o == 0x99: self.write(self.fetch16() + Y, self.A)
        elif o == 0x91:
            d = self.fetch()
            ptr = self.ram[d] | (self.ram[(d + 1) & 0xFF] << 8)
            self.write(ptr + Y, self.A)
        elif o == 0x86: self.write(self.fetch(), self.X)
        elif o == 0x8E: self.write(self.fetch16(), self.X)
        elif o == 0x8C: self.write(self.fetch16(), self.Y)
        elif o == 0x84: self.write(self.fetch(), self.Y)
        elif o == 0x64: self.write(self.fetch(), 0)
        elif o == 0x74: self.write((self.fetch() + X) & 0xFF, 0)
        elif o == 0x9C: self.write(self.fetch16(), 0)
        elif o == 0x9E: self.write(self.fetch16() + X, 0)
        # --- arith / logique ---
        elif o == 0x69: adc(self.fetch())
        elif o == 0x65: adc(self.read(self.fetch()))
        elif o == 0x6D: adc(self.read(self.fetch16()))
        elif o == 0x79: adc(self.read(self.fetch16() + Y))
        elif o == 0x7D: adc(self.read(self.fetch16() + X))
        elif o == 0x75: adc(self.read((self.fetch() + X) & 0xFF))
        elif o == 0xE9: sbc(self.fetch())
        elif o == 0xF5: sbc(self.read((self.fetch() + X) & 0xFF))
        elif o == 0xF9: sbc(self.read(self.fetch16() + Y))
        elif o == 0xFD: sbc(self.read(self.fetch16() + X))
        elif o == 0xE5: sbc(self.read(self.fetch()))
        elif o == 0xC9: cmp_(self.A, self.fetch())
        elif o == 0xD9: cmp_(self.A, self.read(self.fetch16() + Y))
        elif o == 0xDD: cmp_(self.A, self.read(self.fetch16() + X))
        elif o == 0xD5: cmp_(self.A, self.read((self.fetch() + X) & 0xFF))
        elif o == 0xC5: cmp_(self.A, self.read(self.fetch()))
        elif o == 0xCD: cmp_(self.A, self.read(self.fetch16()))
        elif o == 0xE0: cmp_(self.X, self.fetch())
        elif o == 0xE4: cmp_(self.X, self.read(self.fetch()))
        elif o == 0xC0: cmp_(self.Y, self.fetch())
        elif o == 0xC4: cmp_(self.Y, self.read(self.fetch()))
        elif o == 0x29: self.A &= self.fetch(); self.setnz(self.A)
        elif o == 0x25: self.A &= self.read(self.fetch()); self.setnz(self.A)
        elif o == 0x39: self.A &= self.read(self.fetch16() + Y); self.setnz(self.A)
        elif o == 0x19: self.A |= self.read(self.fetch16() + Y); self.setnz(self.A)
        elif o == 0x59: self.A ^= self.read(self.fetch16() + Y); self.setnz(self.A)
        elif o == 0x09: self.A |= self.fetch(); self.setnz(self.A)
        elif o == 0x05: self.A |= self.read(self.fetch()); self.setnz(self.A)
        elif o == 0x0D: self.A |= self.read(self.fetch16()); self.setnz(self.A)
        elif o == 0x49: self.A ^= self.fetch(); self.setnz(self.A)
        elif o == 0x45: self.A ^= self.read(self.fetch()); self.setnz(self.A)
        elif o == 0x0A:
            self.P = (self.P & ~1) | (self.A >> 7)
            self.A = (self.A << 1) & 0xFF; self.setnz(self.A)
        elif o == 0x4A:
            self.P = (self.P & ~1) | (self.A & 1)
            self.A >>= 1; self.setnz(self.A)
        # --- inc/dec ---
        elif o == 0xE6:
            a = self.fetch(); v = (self.read(a) + 1) & 0xFF
            self.write(a, v); self.setnz(v)
        elif o == 0xC6:
            a = self.fetch(); v = (self.read(a) - 1) & 0xFF
            self.write(a, v); self.setnz(v)
        elif o == 0xEE:
            a = self.fetch16(); v = (self.read(a) + 1) & 0xFF
            self.write(a, v); self.setnz(v)
        elif o == 0xCE:
            a = self.fetch16(); v = (self.read(a) - 1) & 0xFF
            self.write(a, v); self.setnz(v)
        elif o == 0xF6:
            a = (self.fetch() + X) & 0xFF; v = (self.read(a) + 1) & 0xFF
            self.write(a, v); self.setnz(v)
        elif o == 0xD6:
            a = (self.fetch() + X) & 0xFF; v = (self.read(a) - 1) & 0xFF
            self.write(a, v); self.setnz(v)
        elif o == 0xE8: self.X = (X + 1) & 0xFF; self.setnz(self.X)
        elif o == 0xC8: self.Y = (Y + 1) & 0xFF; self.setnz(self.Y)
        elif o == 0xCA: self.X = (X - 1) & 0xFF; self.setnz(self.X)
        elif o == 0x88: self.Y = (Y - 1) & 0xFF; self.setnz(self.Y)
        # --- transferts / pile ---
        elif o == 0xAA: self.X = self.A; self.setnz(self.X)
        elif o == 0xA8: self.Y = self.A; self.setnz(self.Y)
        elif o == 0x8A: self.A = self.X; self.setnz(self.A)
        elif o == 0x98: self.A = self.Y; self.setnz(self.A)
        elif o == 0x9A: self.S = 0x100 | self.X
        elif o == 0x48: self.push(self.A)
        elif o == 0x68: self.A = self.pull(); self.setnz(self.A)
        elif o == 0xDA: self.push(self.X)
        elif o == 0xFA: self.X = self.pull(); self.setnz(self.X)
        elif o == 0x5A: self.push(self.Y)
        elif o == 0x7A: self.Y = self.pull(); self.setnz(self.Y)
        # --- branches / sauts ---
        elif o == 0xF0: bra(self.P & 2)
        elif o == 0xD0: bra(not (self.P & 2))
        elif o == 0x90: bra(not (self.P & 1))
        elif o == 0xB0: bra(self.P & 1)
        elif o == 0x30: bra(self.P & 0x80)
        elif o == 0x10: bra(not (self.P & 0x80))
        elif o == 0x4C: self.PC = self.fetch16()
        elif o == 0x20:
            t = self.fetch16()
            r = (self.PC - 1) & 0xFFFF
            self.push(r >> 8); self.push(r & 0xFF)
            self.PC = t
        elif o == 0x60:
            lo = self.pull(); hi = self.pull()
            self.PC = ((hi << 8) | lo) + 1 & 0xFFFF
        elif o == 0x40:
            self.P = self.pull()
            lo = self.pull(); hi = self.pull()
            self.pull()                    # PBR
            self.PC = (hi << 8) | lo
        else:
            raise RuntimeError(f"opcode inconnu ${o:02X} en ${pc0:04X}")

    # ---------------- une image ----------------
    def frame(self, joy=None, budget=25000):
        if joy is not None: self.joy = joy
        self.nmi()
        self.step(budget)
        self.frames += 1

    # ---------------- rendu ----------------
    def color(self, i):
        c = self.cgram[i * 2] | (self.cgram[i * 2 + 1] << 8)
        return ((c & 31) << 3, ((c >> 5) & 31) << 3, ((c >> 10) & 31) << 3)

    def gradient_rows(self):
        """Rejoue la table HDMA du canal 1 : couleur 0 par ligne."""
        addr = self.regs.get(0x4312, 0) | (self.regs.get(0x4313, 0) << 8)
        if not (self.regs.get(0x420C, 0) & 2) or addr < 0x8000:
            return [self.color(0)] * 224
        rows, p = [], addr - 0x8000
        while len(rows) < 224:
            n = self.rom[p]
            if n == 0: break
            lo, hi = self.rom[p + 3], self.rom[p + 4]
            c = lo | (hi << 8)
            rgb = ((c & 31) << 3, ((c >> 5) & 31) << 3, ((c >> 10) & 31) << 3)
            rows += [rgb] * n
            p += 5
        while len(rows) < 224: rows.append(rows[-1] if rows else (0, 0, 0))
        return rows[:224]

    def tile2_pixel(self, base, tile, px, py):
        o = base + tile * 16 + py * 2
        b0, b1 = self.vram[o], self.vram[o + 1]
        m = 0x80 >> px
        return (1 if b0 & m else 0) | (2 if b1 & m else 0)

    def render_mode1(self, path, scale=2):
        """BG1 4bpp (32x32/64x32/32x64, defilement) + BG3 2bpp fixe + OBJ."""
        img = Image.new('RGB', (256, 224))
        px = img.load()
        fond = self.gradient_rows()
        bg1sc = self.regs.get(0x2107, 0)
        base1 = ((bg1sc >> 2) & 0x3F) * 0x400 * 2
        taille = bg1sc & 3
        chars1 = (self.regs.get(0x210B, 0) & 0xF) * 0x1000 * 2
        hofs = self.regs.get(0x210D, 0)
        vofs = self.regs.get(0x210E, 0)
        tm = self.regs.get(0x212C, 0x11)
        bg3 = tm & 4
        bg3sc = self.regs.get(0x2109, 0)
        base3 = ((bg3sc >> 2) & 0x3F) * 0x400 * 2
        chars3 = ((self.regs.get(0x210C, 0) & 0xF) * 0x1000) * 2
        for y in range(224):
            for x in range(256):
                gx, gy = (x + hofs), (y + vofs)
                if taille == 1:
                    ecran = (gx // 256) & 1
                    off = base1 + ecran * 0x800
                    gx &= 255; gy %= 256
                elif taille == 2:
                    ecran = (gy // 256) & 1
                    off = base1 + ecran * 0x800
                    gx &= 255; gy &= 255
                else:
                    off = base1
                    gx &= 255; gy &= 255
                e = (gy // 8) * 32 + gx // 8
                lo = self.vram[off + e * 2]
                hi = self.vram[off + e * 2 + 1]
                ci = self.tile_pixel(chars1, lo, gx % 8, gy % 8) if tm & 1 else 0
                px[x, y] = self.color(((hi >> 2) & 7) * 16 + ci) if ci else fond[y]
        for s in range(127, -1, -1):
            sx, sy = self.oam[s*4], self.oam[s*4+1]
            tile, attr = self.oam[s*4+2], self.oam[s*4+3]
            if sy >= 224: continue
            for iy in range(8):
                if sy + iy >= 224: break
                for ix in range(8):
                    if sx + ix > 255: break
                    jx = 7 - ix if attr & 0x40 else ix
                    ci = self.tile_pixel(0x8000, tile, jx, iy)
                    if ci:
                        px[sx+ix, sy+iy] = self.color(128 + ((attr >> 1) & 7) * 16 + ci)
        if bg3:
            for y in range(224):
                ty, iy = y // 8, y % 8
                for x in range(256):
                    e = ty * 32 + x // 8
                    lo = self.vram[base3 + e * 2]
                    hi = self.vram[base3 + e * 2 + 1]
                    if not (hi & 0x20): continue      # seule la priorite passe devant
                    ci = self.tile2_pixel(chars3, lo, x % 8, iy)
                    if ci:
                        px[x, y] = self.color(((hi >> 2) & 7) * 4 + ci)
        img.resize((256*scale, 224*scale), Image.NEAREST).save(path)
        print(f"  saved {path}")

    def tile_pixel(self, base, tile, px, py):
        o = base + tile * 32 + py * 2
        b0, b1 = self.vram[o], self.vram[o + 1]
        b2, b3 = self.vram[o + 16], self.vram[o + 17]
        m = 0x80 >> px
        return ((1 if b0 & m else 0) | (2 if b1 & m else 0) |
                (4 if b2 & m else 0) | (8 if b3 & m else 0))

    def render(self, path, scale=2):
        img = Image.new('RGB', (256, 224))
        px = img.load()
        fond = self.gradient_rows()
        for y in range(224):
            ty, iy = y // 8, y % 8
            for x in range(256):
                tx, ix = x // 8, x % 8
                e = ty * 32 + tx
                lo = self.vram[0x0800 + e * 2]
                hi = self.vram[0x0800 + e * 2 + 1]
                pal = (hi >> 2) & 7
                ci = self.tile_pixel(0x2000, lo, ix, iy)
                px[x, y] = self.color(pal * 16 + ci) if ci else fond[y]
        for s in range(127, -1, -1):
            sx, sy = self.oam[s * 4], self.oam[s * 4 + 1]
            tile, attr = self.oam[s * 4 + 2], self.oam[s * 4 + 3]
            if sy >= 224: continue
            pal = (attr >> 1) & 7
            for iy in range(8):
                if sy + iy >= 224: break
                for ix in range(8):
                    if sx + ix > 255: break
                    ci = self.tile_pixel(0x8000, tile, ix, iy)
                    if ci:
                        px[sx + ix, sy + iy] = self.color(128 + pal * 16 + ci)
        img.resize((256 * scale, 224 * scale), Image.NEAREST).save(path)
        print(f"  saved {path}")
