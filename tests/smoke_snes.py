"""Tests du casse-brique SNES : la meme batterie que la version NES."""
import os
from sim_snes import SNES
RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

snes = SNES(os.path.join(RACINE, 'casse-brique-snes/casse-brique.sfc'))

# page directe : meme ordre de declaration que dans main.s
names = ['boutons','anciens','presses','image','etat',
         'balle_x','balle_xs','balle_y','balle_ys',
         'balle_dx_lo','balle_dx_hi','balle_dy_lo','balle_dy_hi',
         'raquette_x','vies','niveau',
         'score_u','score_d','score_c','record_u','record_d','record_c',
         'briques_restantes',
         'effacer_actif','effacer_vlo','effacer_vhi',
         'effacer_t1','effacer_a1','effacer_t2','effacer_a2',
         'capsule_type','capsule_x','capsule_y','capsule_suivante',
         'raquette_large','balle_lente','pause_cpt','vitesse_extra',
         'col_tuile','lig_tuile','col_brique','lig_brique',
         'adr_lo','adr_hi','tmp_lo','tmp_hi','tmp2']
ZP = {n: i for i, n in enumerate(names)}
b = len(names); ZP['motif_ptr'] = b; b += 2
for n in ['go_actif','balle_perdue','balle2_active',
          'balle2_x','balle2_xs','balle2_y','balle2_ys',
          'balle2_dx_lo','balle2_dx_hi','balle2_dy_lo','balle2_dy_hi']:
    ZP[n] = b; b += 1

GRILLE = 0x0440          # premiere adresse du segment BSS (voir snes.cfg)
def zp(n): return snes.ram[ZP[n]]
def poke(n, v): snes.ram[ZP[n]] = v
def grille(i): return snes.ram[GRILLE + i]
def score(): return zp('score_c')*100 + zp('score_d')*10 + zp('score_u')
def tilemap(word):
    """une case de la tilemap BG1 : (tuile, attributs)"""
    return snes.vram[0x0800 + (word - 0x0400)*2], snes.vram[0x0800 + (word - 0x0400)*2 + 1]

IDLE, A, START = 0x00, 0x80, 0x10

# ===== 1. boot -> titre =====
snes.step(400000)
assert zp('etat') == 3, f"etat={zp('etat')}"
t, _ = tilemap(0x058A)
assert t == 0x22, f"titre: {t:02X}"                       # L_C
t, _ = tilemap(0x05F2)
assert t == 0x10, "record 000"
t, a = tilemap(0x0440 + 2*32 - 32*1)                      # mur rangee 2 : $0440
t, a = tilemap(0x0440)
assert t == 0x07 and a == 0x00, f"mur: {t:02X}/{a:02X}"
print(f"boot: titre SNES OK (texte, record, murs), etat=TITRE")
# le SPC700 : pilote televerse, DSP configure, et la musique demarre
assert snes.apu_state == 'run', "poignee de main IPL ratee"
assert snes.dsp.get(0x3D) == 0x08, "voix 3 pas en bruit (NON)"
assert snes.dsp.get(0x5D) == 0x03, "repertoire d'echantillons (DIR)"
assert snes.apu_ram[0x310] == 0xA3, "BRR du carre absent de la RAM SPC"
snes.frame(IDLE)
assert (0, 0, 1072) in snes.spc_events, "melodie: DO5 ($0430) attendu"
assert (0, 1, 268) in snes.spc_events, "basse: DO3 ($010C) attendu"
print("son: pilote SPC700 en marche, 1res notes DO5 (carre) + DO3 (triangle)")
snes.render('snes-titre.png')

# ===== 2. Start -> niveau 1 =====
snes.frame(START); snes.frame(IDLE)
assert zp('etat') == 0 and zp('niveau') == 1 and zp('vies') == 3
assert zp('briques_restantes') == 90
assert all(grille(c) == 3 for c in range(15)), "rangee doree"
t, a = tilemap(0x0481)
assert t == 0x01 and a == 0x0C, f"brique doree VRAM: {t:02X}/{a:02X}"   # tuile brique, palette OR
t, a = tilemap(0x0521)
assert t == 0x01 and a == 0x04, f"brique normale VRAM: {t:02X}/{a:02X}" # palette ORANGE
t, _ = tilemap(0x058A)
assert t == 0x00, "titre non efface"
print("start: niveau 1 charge — la MEME tuile est doree ou orange par la palette !")

# ===== 3. lancement =====
for _ in range(3): snes.frame(IDLE)
assert zp('balle_x') == 124 and zp('balle_y') == 192
snes.frame(A); snes.frame(IDLE)
assert zp('etat') == 1
assert zp('balle_dy_hi') == 0xFE and zp('balle_dy_lo') == 0x00
print(f"lance: dy=-2.0, dx={'+' if zp('balle_dx_hi')==1 else '-'}1.0")

# ===== 4. premiere brique =====
before = zp('briques_restantes')
for f in range(600):
    snes.frame(IDLE)
    if zp('briques_restantes') < before: break
assert zp('briques_restantes') == before - 1 and score() == 1
print(f"  1re brique cassee (frame {f}), score={score():03d}")

# ===== 5. les 5 zones de la raquette (valeurs identiques a la NES) =====
def bounce(offset, dx_before, want_dx, want_dy, label):
    poke('raquette_x', 100)
    poke('balle_x', 100 + offset); poke('balle_xs', 0)
    poke('balle_y', 193); poke('balle_ys', 0)
    poke('balle_dx_lo', 0); poke('balle_dx_hi', dx_before)
    poke('balle_dy_lo', 0); poke('balle_dy_hi', 2)
    snes.frame(IDLE)
    got_dx = (zp('balle_dx_hi'), zp('balle_dx_lo'))
    got_dy = (zp('balle_dy_hi'), zp('balle_dy_lo'))
    assert got_dx == want_dx, f"zone {label} dx: {got_dx}"
    assert got_dy == want_dy, f"zone {label} dy: {got_dy}"
bounce(-5, 0x01, (0xFE, 0x00), (0xFF, 0x00), "0")
bounce(0,  0x01, (0xFE, 0x80), (0xFE, 0x40), "1")
bounce(8,  0xFF, (0xFF, 0x80), (0xFD, 0xC0), "2g")
bounce(8,  0x01, (0x00, 0x80), (0xFD, 0xC0), "2d")
bounce(14, 0x01, (0x01, 0x80), (0xFE, 0x40), "3")
bounce(22, 0x01, (0x02, 0x00), (0xFF, 0x00), "4")
print("  5 zones de rebond OK (les memes angles que sur NES)")
z = [p for (f, v, p) in snes.spc_events if v == 2 and p][-6:]
assert z == [803, 901, 1072, 1072, 901, 803], f"sons de zone: {z}"
print("  ... et on les ENTEND : sol4 au bord, la4, do5 au centre")

# ===== 6. brique solide -> fissuree -> detruite ; doree =====
def teleport(row, col, dy_hi=0xFF):
    x = 8 + col * 16 + 2
    y = (4 + row) * 8 - 4 + 2          # zone briques : rangees de tuiles 4-9
    poke('balle_x', x); poke('balle_xs', 0)
    poke('balle_y', y); poke('balle_ys', 0)
    poke('balle_dx_lo', 0); poke('balle_dx_hi', 0)
    poke('balle_dy_lo', 0); poke('balle_dy_hi', dy_hi)

idx = 3 * 16 + 5
snes.ram[GRILLE + idx] = 2
b0, s0 = zp('briques_restantes'), score()
teleport(3, 5); snes.frame(IDLE)
assert grille(idx) == 4 and score() == s0, "fissure"
snes.frame(IDLE)                        # la nmi redessine
t, a = tilemap(0x04E1 + 5*2)            # rangee 7 (brique lig 3), col brique 5
assert t == 0x05 and a == 0x08, f"tuile fissuree VRAM: {t:02X}/{a:02X}"
teleport(3, 5); snes.frame(IDLE)
assert grille(idx) == 0 and score() == s0 + 2, "destruction fissuree"
print("  solide -> fissuree (tuile $05 acier) -> detruite (+2) OK")

idx2 = 3 * 16 + 7
snes.ram[GRILLE + idx2] = 3
s0 = score()
teleport(3, 7); snes.frame(IDLE)
assert score() == s0 + 5, "doree = 5 pts"
print("  doree (+5) OK")

# ===== 7. capsules + multiball =====
def park():
    poke('balle_x', 60); poke('balle_xs', 0)
    poke('balle_y', 100); poke('balle_ys', 0)
    poke('balle_dx_lo', 0); poke('balle_dx_hi', 0)
    poke('balle_dy_lo', 0); poke('balle_dy_hi', 0)
park()
poke('capsule_type', 1); poke('capsule_x', zp('raquette_x') + 8); poke('capsule_y', 182)
for _ in range(20): snes.frame(IDLE)
assert zp('raquette_large') > 140, "raquette large"
park()
poke('capsule_type', 3); poke('capsule_x', zp('raquette_x') + 8); poke('capsule_y', 182)
v0 = zp('vies')
for _ in range(20): snes.frame(IDLE)
assert zp('vies') == v0 + 1, "vie bonus"
park()
poke('balle_dx_hi', 1)
poke('capsule_type', 4); poke('capsule_x', zp('raquette_x') + 8); poke('capsule_y', 182)
for _ in range(20): snes.frame(IDLE)
assert zp('balle2_active') == 1 and zp('balle2_dx_hi') == 0xFF, "multiball"
print("  capsules LARGE / VIE / MULTIBALL attrapees, dx miroir OK")
snes.render('snes-multiball.png')

# la balle 2 tombe : pas de vie perdue
v0 = zp('vies')
poke('balle2_x', 120); poke('balle2_y', 213)
poke('balle2_dx_lo', 0); poke('balle2_dx_hi', 0)
poke('balle2_dy_lo', 0); poke('balle2_dy_hi', 2)
poke('raquette_x', 8)
for _ in range(8): snes.frame(IDLE)
assert zp('balle2_active') == 0 and zp('vies') == v0
print("  perte de la balle 2 sans drame OK")

# ===== 8. fin de niveau -> damier =====
poke('briques_restantes', 1)
snes.ram[GRILLE + 5] = 1
teleport(0, 5); snes.frame(IDLE)
assert zp('etat') == 4, "entracte"
for _ in range(125): snes.frame(IDLE)
snes.step(400000)
assert zp('niveau') == 2 and zp('etat') == 0
assert zp('briques_restantes') == 53 and zp('vitesse_extra') == 0x40
t, a = tilemap(0x0521)
assert t == 0x03 and a == 0x08, f"plancher solide: {t:02X}/{a:02X}"
print("  niveau 2 (damier, 53 briques, +0,25 px/img) OK")

# ===== 9. game over -> record -> titre =====
snes.frame(A); snes.frame(IDLE)          # lancer la balle du niveau 2
assert zp('etat') == 1, f"lancement niveau 2: etat={zp('etat')}"
s_final = score()
poke('vies', 1)
poke('balle_x', 120); poke('balle_y', 213); poke('balle_ys', 0)
poke('balle_dx_hi', 0); poke('balle_dx_lo', 0)
poke('balle_dy_hi', 2); poke('balle_dy_lo', 0)
for _ in range(10): snes.frame(IDLE)
assert zp('etat') == 2, "game over"
go = [(v, p) for (f, v, p) in snes.spc_events if f >= snes.frames - 12]
assert (3, 1024) in go, "grondement de fin absent (voix bruit)"
assert (0, 0) in go and (1, 0) in go, "musique non arretee (KOF)"
rec = zp('record_c')*100 + zp('record_d')*10 + zp('record_u')
assert rec == s_final
snes.frame(IDLE)
t, _ = tilemap(0x05CB)
assert t == 0x2D, "GAME OVER absent"                       # L_G
print(f"  game over, record={rec:03d}, GAME OVER a l'ecran")
snes.render('snes-gameover.png')

snes.frame(IDLE); snes.frame(START); snes.step(400000); snes.frame(IDLE)
assert zp('etat') == 3
d = tilemap(0x05F2)[0]-0x10, tilemap(0x05F3)[0]-0x10, tilemap(0x05F4)[0]-0x10
assert d[0]*100 + d[1]*10 + d[2] == rec, f"record affiche: {d}"
snes.frame(IDLE); snes.frame(START); snes.step(400000); snes.frame(IDLE)
assert zp('etat') == 0 and score() == 0
assert zp('record_c')*100 + zp('record_d')*10 + zp('record_u') == rec
print(f"  retour titre (RECORD {rec:03d}), nouvelle partie, record conserve")

# ===== 10. la capture du coeur =====
poke('etat', 4); poke('pause_cpt', 1); poke('niveau', 2)
snes.frame(IDLE); snes.step(400000)
for _ in range(3): snes.frame(IDLE)
snes.frame(A)
for _ in range(25): snes.frame(IDLE)
poke('capsule_type', 3); poke('capsule_x', 170); poke('capsule_y', 110)
snes.frame(IDLE)
snes.render('snes-coeur.png')

print("\nALL SNES TESTS PASSED")
