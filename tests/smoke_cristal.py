"""Tests de CRISTAL-2026 (phase 1) : banques, 16 bits, division, SRAM."""
import os
from sim_snes import SNES
RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

ROM = os.path.join(RACINE, 'cristal-2026/cristal.sfc')

names = ['boutons','anciens','presses','image','etat','curseur',
         'heros_x','heros_y','direction','pose','pose_cpt','sous_pas',
         'or_lo','or_hi','pas_lo','pas_hi','coffre_ouvert','sauve_ok',
         'msg_cpt','msg_ecrire','msg_effacer','coffre_maj',
         'sonde_x','sonde_y','dec_lo','dec_hi','som_lo','som_hi','tmp','tmp2']
ZP = {n: i for i, n in enumerate(names)}
b = len(names)
ZP['chiffres'] = b; b += 10
ZP['salle_ptr'] = b; b += 3
ZP['sram_ptr'] = b; b += 3
ZP['tampon_sauve'] = b; b += 16

snes = SNES(ROM)
def zp(n): return snes.ram[ZP[n]]
def poke(n, v): snes.ram[ZP[n]] = v
def bg1(w): return snes.vram[w*2], snes.vram[w*2+1]
def bg3(w): return snes.vram[w*2], snes.vram[w*2+1]
def OR(): return zp('or_lo') | (zp('or_hi') << 8)
def PAS(): return zp('pas_lo') | (zp('pas_hi') << 8)

IDLE, A, START = 0x00, 0x80, 0x10
HAUT, BAS, GAUCHE, DROITE = 0x08, 0x04, 0x02, 0x01
def lettre(c): return 0x20 + ord(c) - 65        # A-Z -> $20-$39

# ===== 1. la ROM fait 256 Ko, l'en-tete declare la SRAM =====
assert len(snes.rom) == 0x40000, f"ROM de {len(snes.rom)} octets"
assert snes.rom[0x7FD6] == 0x02, "type cartouche: ROM+SRAM+pile"
assert snes.rom[0x7FD7] == 0x08 and snes.rom[0x7FD8] == 0x03, "tailles ROM/SRAM"
# ... et les graphismes vivent bien HORS de la banque 0 :
assert any(snes.rom[0x8000:0x10000]), "la banque $81 doit contenir les donnees"
print("cartouche: 256 Ko, 8 banques, SRAM 8 Ko declaree, donnees en banque $81")

# ===== 2. boot sans sauvegarde : titre, pas de CONTINUER =====
snes.step(900000)
assert zp('etat') == 0 and zp('sauve_ok') == 0
t, a = bg3(0x0C00 + 8*32 + 10)
assert t == lettre('C') and a == 0x28, f"titre: {t:02X}/{a:02X}"
t, a = bg3(0x0C00 + 14*32 + 9)
assert t == lettre('N') and a == 0x24, "NOUVELLE PARTIE"
t, _ = bg3(0x0C00 + 16*32 + 9)
assert t == 0, "CONTINUER ne doit PAS apparaitre sans sauvegarde"
snes.frame(IDLE)
assert (0, 0, 1350) in snes.spc_events, "theme du cristal: MI5"
assert (0, 1, 225) in snes.spc_events, "basse: LA2"
snes.frame(IDLE)                 # l'OAM part en DMA a la nmi SUIVANTE
assert snes.oam[16] == 58 and snes.oam[18] == 0x18, "le curseur du menu"
print("boot: titre OK, CONTINUER masque (SRAM vierge), theme du cristal")
snes.render_mode1('cristal-titre.png')

# le bas ne bouge pas le curseur (une seule option)
snes.frame(BAS); snes.frame(IDLE)
assert zp('curseur') == 0, "curseur bloque sans sauvegarde"

# ===== 3. nouvelle partie : la salle est dessinee DEPUIS LA BANQUE $81 =====
snes.frame(START); snes.step(300000); snes.frame(IDLE)
assert zp('etat') == 1
assert zp('heros_x') == 120 and zp('heros_y') == 168
t, a = bg1(0x0400 + 2*32)
assert t == 0x02 and a == 0x10, f"mur: {t:02X}/{a:02X}"
t, a = bg1(0x0400 + 12*32 + 15)
assert t == 0x03, "tapis"
t, a = bg1(0x0400 + 5*32 + 15)
assert t == 0x04 and a == 0x14, f"cristal: {t:02X}/{a:02X}"
t, a = bg1(0x0400 + 17*32 + 23)
assert t == 0x08 and a == 0x18, f"coffre ferme: {t:02X}/{a:02X}"
t, _ = bg3(0x0C00 + 8*32 + 10)
assert t == 0, "titre non efface"
t, _ = bg3(0x0C22)
assert t == lettre('O'), "label OR"
t, _ = bg3(0x0C25)
assert t == 0x10, "or = 0"
print("salle: 896 cases lues en adressage long (X 16 bits), HUD en place")

# ===== 4. marcher : collisions, pas comptes en 16 BITS =====
x0 = zp('heros_x')
for _ in range(40): snes.frame(DROITE)
assert zp('heros_x') == x0 + 40 and zp('direction') == 3
assert PAS() == 2, f"40 px = 2 pas: {PAS()}"      # 16 px = 1 pas
for _ in range(45): snes.frame(GAUCHE)
assert zp('heros_x') == x0 + 40 - 45
for _ in range(300): snes.frame(HAUT)
assert zp('heros_y') == 56, f"bloque par le cristal a y=56: {zp('heros_y')}"
for _ in range(5): snes.frame(HAUT)
assert zp('heros_y') == 56, "le cristal est solide"
print(f"marche: collisions OK (bute sur le cristal), {PAS()} pas comptes")

# le compteur 16 bits + la DIVISION MATERIELLE : 255 -> 256
poke('pas_lo', 255); poke('pas_hi', 0); poke('sous_pas', 15)
poke('heros_x', 120); poke('heros_y', 168)
snes.frame(DROITE)                                  # 1 px -> le 16e : pas #256
assert PAS() == 256 and zp('pas_hi') == 1, "l'inc 16 bits doit deborder"
snes.frame(IDLE)
digits = [bg3(0x0C36 + i)[0] - 0x10 for i in range(5)]
assert digits == [0, 0, 2, 5, 6], f"00256 attendu: {digits}"
print("16 bits: pas 255->256 (rep #$20), affiche 00256 par la division materielle")

# ===== 5. le coffre : +250 OR en une addition 16 bits =====
poke('heros_x', 184); poke('heros_y', 152); poke('direction', 1)
n0 = len(snes.spc_events)
snes.frame(A); snes.frame(IDLE)
assert zp('coffre_ouvert') == 1 and OR() == 250, f"or={OR()}"
t, a = bg1(0x0400 + 17*32 + 23)
assert t == 0x0C, f"coffre ouvert a l'ecran: {t:02X}"
digits = [bg3(0x0C25 + i)[0] - 0x10 for i in range(5)]
assert digits == [0, 0, 2, 5, 0], f"OR 00250: {digits}"
assert any(v == 2 and p == 1606 for _, v, p in snes.spc_events[n0:]), "son du coffre"
snes.frame(A); snes.frame(IDLE)
assert OR() == 250, "le coffre ne paie qu'une fois !"
print("coffre: +250 or (adc 16 bits), tuiles changees au VBlank, une seule fois")

# ===== 6. sauvegarder au cristal =====
poke('heros_x', 120); poke('heros_y', 56); poke('direction', 1)
pas_avant, or_avant = PAS(), OR()
n0 = len(snes.spc_events)
snes.frame(A); snes.frame(IDLE)
s = snes.sram
assert bytes(s[0:4]) == b'CR26', f"signature: {bytes(s[0:4])}"
assert s[4] == 1 and s[5] == 120 and s[6] == 56 and s[7] == 1
assert (s[8] | s[9] << 8) == or_avant and (s[10] | s[11] << 8) == pas_avant
assert s[12] == 1, "coffre_ouvert sauvegarde"
somme = sum(s[0:14])
assert (s[14] | s[15] << 8) == somme, "somme de controle"
assert any(v == 2 and p == 1802 for _, v, p in snes.spc_events[n0:]), "note du cristal"
t, a = bg3(0x0C00 + 24*32 + 7)
assert t == lettre('P') and a == 0x24, "PARTIE SAUVEGARDEE affiche"
print(f"sauvegarde: 16 octets en SRAM (or={or_avant}, pas={pas_avant}, "
      f"somme={somme:04X}), message affiche")
snes.render_mode1('cristal-salle.png')
for _ in range(155): snes.frame(IDLE)
t, _ = bg3(0x0C00 + 24*32 + 7)
assert t == 0, "le message doit s'effacer"
print("le message s'efface tout seul (file d'attente nmi)")

# ===== 7. ON ETEINT LA CONSOLE. La pile veille sur la SRAM... =====
snes2 = SNES(ROM, sram=snes.sram)
snes2.step(900000)
r2 = snes2.ram
assert r2[ZP['sauve_ok']] == 1, "la sauvegarde doit etre reconnue"
t, a = snes2.vram[(0x0C00 + 16*32 + 9)*2], snes2.vram[(0x0C00 + 16*32 + 9)*2+1]
assert t == lettre('C'), "CONTINUER doit apparaitre"
snes2.frame(IDLE)
snes2.frame(BAS); snes2.frame(IDLE)
assert r2[ZP['curseur']] == 1, "curseur sur CONTINUER"
snes2.frame(START); snes2.step(300000); snes2.frame(IDLE)
assert r2[ZP['etat']] == 1
assert r2[ZP['heros_x']] == 120 and r2[ZP['heros_y']] == 56
assert (r2[ZP['or_lo']] | r2[ZP['or_hi']] << 8) == or_avant
assert (r2[ZP['pas_lo']] | r2[ZP['pas_hi']] << 8) == pas_avant
assert r2[ZP['coffre_ouvert']] == 1
t, _ = snes2.vram[(0x0400 + 17*32 + 23)*2], 0
assert t == 0x0C, "le coffre doit etre redessine OUVERT"
digits = [snes2.vram[(0x0C25 + i)*2] - 0x10 for i in range(5)]
assert digits == [0, 0, 2, 5, 0], f"or restaure: {digits}"
print("CYCLE D'ALIMENTATION: eteint, rallume -> CONTINUER restaure tout "
      f"(x=120 y=56, or={or_avant}, pas={pas_avant}, coffre ouvert)")
snes2.render_mode1('cristal-continuer.png')

# ===== 8. la pile fatigue : UN octet corrompu, et la somme le sait =====
sram_corrompue = bytearray(snes.sram)
sram_corrompue[8] ^= 0x01                    # l'or perd un bit...
snes3 = SNES(ROM, sram=sram_corrompue)
snes3.step(900000)
assert snes3.ram[ZP['sauve_ok']] == 0, "la corruption doit etre detectee !"
t = snes3.vram[(0x0C00 + 16*32 + 9)*2]
assert t == 0, "CONTINUER doit disparaitre (donnees corrompues)"
print("corruption: 1 bit change -> somme fausse -> CONTINUER refuse. "
      "Voila le 'donnees corrompues' des vraies cartouches !")

print("\nALL CRISTAL TESTS PASSED")
