"""Tests de NOVA-2026 SNES : la batterie NES + le son SPC700."""
import os
from sim_snes import SNES
RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

snes = SNES(os.path.join(RACINE, 'nova-snes/nova.sfc'))

names = ['boutons','anciens','presses','image','etat',
         'nav_x','nav_inv','tir_cd',
         'vies','vague_num','boucle','chute',
         'score_u','score_d','score_c','record_u','record_d','record_c',
         'defil_lo','defil_hi','ennemis_restants','pause_cpt','graine','tmp','tmp2',
         'go_actif']
ZP = {n: i for i, n in enumerate(names)}
b = len(names)
for n, c in [('tir_actif',3),('tir_x',3),('tir_y',3),
             ('enn_etat',8),('enn_x',8),('enn_y',8),('enn_dx',8),
             ('enn_delai',8),('enn_type',8)]:
    ZP[n] = b; b += c
for n, c in [('snd_cpt',1),('snd_pitch_lo',1),('snd_pitch_hi',1),('ipl_index',1),
             ('snd_ptr',2),('snd_reste_lo',1),('snd_reste_hi',1),
             ('mus_active',1),('mel_pos',1),('mel_cpt',1),('bas_pos',1),('bas_cpt',1),
             ('bip_cpt',1),('bruit_cpt',1)]:
    ZP[n] = b; b += c

def zp(n): return snes.ram[ZP[n]]
def zpa(n, i): return snes.ram[ZP[n] + i]
def poke(n, v, i=0): snes.ram[ZP[n] + i] = v
def score(): return zp('score_c')*100 + zp('score_d')*10 + zp('score_u')
def bg1(word): return snes.vram[word*2], snes.vram[word*2+1]
def bg3(word): return snes.vram[word*2], snes.vram[word*2+1]
def defil(): return zp('defil_lo') | (zp('defil_hi') << 8)

IDLE, A, START, RIGHT, LEFT = 0x00, 0x80, 0x10, 0x01, 0x02

# ===== 1. boot -> titre, ciel etoile MULTICOLORE, musique =====
snes.step(900000)
assert zp('etat') == 0 and zp('mus_active') == 1
assert snes.apu_state == 'run' and snes.apu_out[1] == 0xEE, "pilote SPC700"
tiles_a = [bg1(0x0400 + i) for i in range(1024)]
tiles_b = [bg1(0x0800 + i) for i in range(1024)]
stars_a = sum(1 for t, a in tiles_a if t in (1, 2))
stars_b = sum(1 for t, a in tiles_b if t in (1, 2))
assert 15 < stars_a < 140 and 15 < stars_b < 140, f"ciel: {stars_a}/{stars_b}"
attrs = {a for t, a in tiles_a + tiles_b if t == 1}
assert attrs == {0x10, 0x14}, f"etoiles bicolores attendues: {attrs}"
brillantes = {a for t, a in tiles_a + tiles_b if t == 2}
assert brillantes <= {0x18}, f"brillantes blanches: {brillantes}"
t, a = bg3(0x0C00 + 11*32 + 11)
assert t == 0x27 and a == 0x28, f"titre: {t:02X}/{a:02X}"      # L_N, cyan
t, a = bg3(0x0C00 + 14*32 + 18)
assert t == 0x10, "record 000"
print(f"boot: titre BG3 cyan, ciel A={stars_a} B={stars_b} etoiles, "
      f"bleutees ET dorees (par la tilemap !)")
snes.frame(IDLE)
assert (0, 0, 901) in snes.spc_events, "melodie: LA4 attendu"
assert (0, 1, 225) in snes.spc_events, "basse: LA2 attendu"
print("son: pilote SPC700 en marche, arpege LA4 + basse LA2")
snes.render_mode1('nsnes-titre.png')

# ===== 2. Start -> entracte -> vague 1, le ciel defile en 16 bits =====
snes.frame(START); snes.frame(IDLE)
assert zp('etat') == 3 and zp('ennemis_restants') == 8
t, _ = bg3(0x0C00 + 11*32 + 11)
assert t == 0, "titre non efface"
assert all(zpa('enn_etat', i) == 1 for i in range(8))
assert any(v == 2 and p == 901 for _, v, p in snes.spc_events), "bip depart"
print("start: entracte, 8 drones en attente, titre efface (bip la4)")
d0 = defil()
n0 = len(snes.spc_events)
for _ in range(70): snes.frame(IDLE)
assert zp('etat') == 1, "vague non lancee"
assert defil() != d0 and defil() > 400, f"le ciel doit defiler: {defil()}"
# la nmi affiche l'etat d'AVANT le calcul de l'image : 1 a 2 px d'avance
ecart = (snes.regs.get(0x210E, 0) - defil()) % 512
assert ecart <= 2, f"BG1VOFS pas a jour (ecart {ecart})"
assert any(v == 2 and p == 1802 for _, v, p in snes.spc_events[n0:]), "bip vague la5"
assert any(zpa('enn_etat', i) == 2 for i in range(8)), "aucun drone en vol"
print(f"  vague 1 en vol, ciel a defil={defil()} (BG1VOFS 16 bits), bip la5")

# ===== 3. butees de pilotage =====
for _ in range(130): snes.frame(RIGHT)
assert zp('nav_x') == 232, f"butee droite: {zp('nav_x')}"
for _ in range(130): snes.frame(LEFT)
assert zp('nav_x') == 8, f"butee gauche: {zp('nav_x')}"
print("  butees de pilotage OK (8..232)")

# ===== 4. le canon : reservoir de 3, recharge, pew =====
n0 = len(snes.spc_events)
snes.frame(A)
assert sum(zpa('tir_actif', i) for i in range(3)) == 1, "premier tir"
assert any(v == 2 and p == 2143 for _, v, p in snes.spc_events[n0:]), "pew do6"
for _ in range(30): snes.frame(A)
assert sum(zpa('tir_actif', i) for i in range(3)) >= 2, "tir automatique"
print("  canon OK (tir auto, reservoir, pew do6)")

# ===== 5. l'autopilote : chasser et detruire =====
explosion_vue = False
vague_finie_avec_kills = False
shot_action = False
for f in range(4000):
    target = None
    for i in range(8):
        if zpa('enn_etat', i) == 2:
            target = i; break
        if zpa('enn_etat', i) == 3:
            explosion_vue = True
    if target is not None:
        poke('nav_x', max(8, min(232, zpa('enn_x', target) - 4)))
    snes.frame(A)
    if not shot_action and explosion_vue and score() >= 10:
        snes.render_mode1('nsnes-action.png'); shot_action = True
    if zp('etat') == 3 and score() >= 30:
        vague_finie_avec_kills = True
        break
assert vague_finie_avec_kills, f"autopilote inefficace: score={score()}"
assert zp('vague_num') >= 1 and explosion_vue
assert any(v == 3 and p == 1024 for _, v, p in snes.spc_events), "boum absent"
print(f"  autopilote: vague nettoyee (n°{zp('vague_num')}), score={score():03d}, "
      f"explosions vues ET entendues")

# ===== 6. collision, i-frames =====
for _ in range(95): snes.frame(IDLE)
assert zp('etat') == 1, f"etat={zp('etat')}"
poke('nav_inv', 0)
poke('enn_etat', 2, 0); poke('enn_type', 0, 0)
poke('enn_x', zp('nav_x') + 4, 0); poke('enn_y', 200, 0)
v0 = zp('vies')
snes.frame(IDLE)
assert zp('vies') == v0 - 1, "collision non detectee"
assert zp('nav_inv') > 80, "pas d'invincibilite"
assert zpa('enn_etat', 0) == 3, "le drone devrait exploser aussi"
print(f"  percute : vies {v0}->{zp('vies')}, invincibilite {zp('nav_inv')} images")
poke('enn_etat', 2, 1); poke('enn_type', 0, 1)
poke('enn_x', zp('nav_x') + 4, 1); poke('enn_y', 200, 1)
v0 = zp('vies')
snes.frame(IDLE)
assert zp('vies') == v0, "l'invincibilite ne protege pas"
print("  i-frames : le second drone passe au travers OK")

# ===== 7. game over : record, GAME OVER sur la couche fixe, silence =====
poke('vies', 1); poke('nav_inv', 0)
poke('enn_etat', 2, 2); poke('enn_type', 0, 2)
poke('enn_x', zp('nav_x') + 4, 2); poke('enn_y', 200, 2)
s_final = score()
n0 = len(snes.spc_events)
snes.frame(IDLE)
assert zp('etat') == 2, "game over attendu"
rec = zp('record_c')*100 + zp('record_d')*10 + zp('record_u')
assert rec == s_final, f"record {rec} != {s_final}"
assert zp('mus_active') == 0
fin = snes.spc_events[n0:]
assert any(v == 3 and p == 1024 for _, v, p in fin), "grondement absent"
assert any(v == 0 and p == 0 for _, v, p in fin), "melodie non coupee"
assert any(v == 1 and p == 0 for _, v, p in fin), "basse non coupee"
snes.frame(IDLE)
t, a = bg3(0x0C00 + 12*32 + 11)
assert t == 0x24 and a == 0x24, f"GAME OVER absent: {t:02X}"   # L_G, blanc
t, a = bg3(0x0C00 + 12*32 + 15)                                # l'espace
assert t == 0x00 and a == 0x00, "l'espace du GAME OVER"
print(f"  game over: record={rec:03d}, GAME OVER sur BG3, musique coupee + grondement")
snes.render_mode1('nsnes-gameover.png')

# ===== 8. retour titre (reset des textes), nouvelle partie =====
snes.frame(IDLE); snes.frame(START); snes.step(400000); snes.frame(IDLE)
assert zp('etat') == 0
t, _ = bg3(0x0C00 + 12*32 + 11)
assert t == 0, "GAME OVER non efface"
d = [bg3(0x0C00 + 14*32 + 18)[0]-0x10, bg3(0x0C00 + 14*32 + 19)[0]-0x10,
     bg3(0x0C00 + 14*32 + 20)[0]-0x10]
assert d[0]*100 + d[1]*10 + d[2] == rec, f"record affiche {d}"
assert zp('mus_active') == 1 and defil() == 0
snes.frame(IDLE); snes.frame(START); snes.step(400000); snes.frame(IDLE)
assert zp('etat') == 3 and score() == 0
assert zp('record_c')*100 + zp('record_d')*10 + zp('record_u') == rec
print(f"  retour titre (RECORD {rec:03d}), nouvelle partie, record conserve")

# ===== 9. le HUD sur la couche fixe =====
t, a = bg3(0x0C00 + 1*32 + 2)
assert t == 0x10 and a == 0x24, f"HUD score: {t:02X}"
t, _ = bg3(0x0C00 + 1*32 + 29)
assert t == 0x13, f"HUD vies=3: {t:02X}"
print("  HUD sur BG3 : score 000, vies 3 (plus un seul sprite de texte !)")

print("\nALL NOVA SNES TESTS PASSED")
