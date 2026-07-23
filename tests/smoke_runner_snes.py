"""Tests de NEO-RUNNER SNES : la batterie NES, sur 65816."""
import os
from sim_snes import SNES
RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

snes = SNES(os.path.join(RACINE, 'neo-runner-snes/neo-runner.sfc'))

names = ['boutons','anciens','presses','image','etat',
         'joueur_x_lo','joueur_x_hi','joueur_y','joueur_ysub','vy_lo','vy_hi',
         'au_sol','regard','camera_lo','camera_hi','prochaine_col',
         'vies','score_c','score_d',
         'col_actif','col_adr_hi','col_adr_lo','col_attr',
         'puce_actif','puce_adr_hi','puce_adr_lo','puce_attr',
         'sonde_x_lo','sonde_x_hi','sonde_y']
ZP = {n: i for i, n in enumerate(names)}
b = len(names)
ZP['carte_ptr'] = b; b += 2
ZP['src_ptr'] = b; b += 2
ZP['dst_ptr'] = b; b += 2
for n in ['rang_tmp','meta_tmp','tmp_lo','tmp_hi','compteur']:
    ZP[n] = b; b += 1
for n in ['drone_x_lo','drone_x_hi','drone_y','drone_dir','drone_actif']:
    ZP[n] = b; b += 3
ZP['monde'] = b

CARTE = 0x0500
def zp(n): return snes.ram[ZP[n]]
def poke(n, v): snes.ram[ZP[n]] = v
def cell(c, r): return snes.ram[CARTE + c*16 + r]
def player_x(): return zp('joueur_x_lo') | (zp('joueur_x_hi') << 8)
def camera(): return zp('camera_lo') | (zp('camera_hi') << 8)
def bg3(word):
    return snes.vram[word*2], snes.vram[word*2+1]
def bg1(word):
    return snes.vram[word*2], snes.vram[word*2+1]

IDLE, A, START, RIGHT = 0x00, 0x80, 0x10, 0x01
A_RIGHT = A | RIGHT

# ===== 1. boot =====
snes.step(700000)
assert zp('etat') == 0 and zp('monde') == 1
assert cell(0, 13) == 2 and all(cell(8, r) == 0 for r in range(15))
t, a = bg3(0x0C00 + 8*32 + 8)
assert t == 0x23 and a == 0x24, f"titre BG3: {t:02X}/{a:02X}"       # L_N, prio+pal1
t, a = bg3(0x0C00 + 3*32 + 5)
assert t == 0x03 and a == 0x2C, "liseret"
t, a = bg1(0x0400 + 4*32 + 27*32//32*0 + 0x1A)                       # col 26 (dessous...)
t, a = bg1(0x0400 + 26*32 + 2)                                       # sol : rangee 26
assert t == 0x02 and a == 0x10, f"sol monde1: {t:02X}/{a:02X}"       # neon, quartier cyan
t, a = bg1(0x0800 + 26*32 + 2)                                       # ecran droit : rose !
assert a == 0x14, f"quartier rose: {a:02X}"
print("boot: titre sur BG3 (couche fixe !), sol cyan ecran 1 / rose ecran 2")
assert snes.apu_state == 'run' and snes.apu_out[1] == 0xEE, "pilote SPC700"
snes.frame(IDLE)
assert (0, 0, 1350) in snes.spc_events, "melodie: MI5 attendu"
assert (0, 1, 225) in snes.spc_events, "basse: LA2 attendu"
print("son: pilote SPC700 signe present, arpege MI5 + basse LA2")
snes.render_mode1('rsnes-titre.png')

# ===== 2. Start =====
snes.frame(START); snes.frame(IDLE)
assert zp('etat') == 1
t, _ = bg3(0x0C00 + 8*32 + 8)
assert t == 0, "titre non efface"
assert any(v == 2 and p == 901 for _, v, p in snes.spc_events), "bip depart la4"
print("start: titre efface, en jeu (bip la4)")

# ===== 3. gravite, marche, saut =====
for _ in range(10): snes.frame(IDLE)
assert zp('joueur_y') == 192 and zp('au_sol') == 1
died = False
for f in range(400):
    snes.frame(RIGHT)
    if zp('vies') == 2: died = True; break
assert died, "aurait du tomber dans le trou"
assert any(v == 3 and p == 1024 for _, v, p in snes.spc_events), "pshh (bruit) absent"
snes.step(2500000)
assert zp('etat') == 1 and player_x() == 32
print(f"chute dans le trou (frame {f}), pshh sur la voix bruit, respawn, vies=2")

# ===== 4. le bot : finir LES DEUX mondes =====
def kill_drones():
    for i in range(3): snes.ram[ZP['drone_actif'] + i] = 0
kill_drones()
prev_x, max_cam, stuck, deaths = player_x(), 0, 0, 0
monde_courant, vies_avant = zp('monde'), zp('vies')
won = False
stuck_jump = False
shot_m1 = shot_m2 = False
for f in range(9000):
    x = player_x()
    jump = False
    if zp('au_sol'):
        stuck_jump = False
        look = (x + 20) >> 4
        if look < 64 and cell(look, 13) == 0 and cell(look, 12) == 0:
            jump = True
        stuck = stuck + 1 if x == prev_x else 0
        if stuck > 2: jump = True; stuck_jump = True
    prev_x = x
    if not zp('au_sol') and stuck_jump:
        btns = RIGHT if (f & 1) else IDLE
    else:
        btns = A_RIGHT if jump else RIGHT
    snes.frame(btns)
    if jump: snes.frame(RIGHT if not stuck_jump else IDLE)
    if not shot_m1 and zp('monde') == 1 and 150 <= x <= 200 and zp('au_sol'):
        snes.render_mode1('rsnes-monde1.png'); shot_m1 = True
    if not shot_m2 and zp('monde') == 2 and 280 <= x <= 340:
        snes.render_mode1('rsnes-monde2.png'); shot_m2 = True
    if zp('vies') < vies_avant:
        deaths += 1; vies_avant = zp('vies')
        snes.step(2500000); kill_drones()
        print(f"  (mort du bot a x={x}, frame {f}, monde {zp('monde')})")
        max_cam = 0; prev_x = player_x(); stuck = 0
        continue
    if zp('monde') != monde_courant:
        monde_courant = zp('monde')
        jingle_debut = len(snes.spc_events)
        snes.step(2500000); kill_drones()
        print(f"  * MONDE {monde_courant} atteint (frame {f})")
        max_cam = 0; prev_x = player_x(); stuck = 0
        continue
    c = camera()
    assert c >= max_cam, f"camera recule: {c} < {max_cam}"
    max_cam = c
    if zp('etat') == 3: won = True; break
    if zp('etat') == 2: break
print(f"bot: frames={f} won={won} deaths={deaths} x={player_x()} camera={max_cam} "
      f"score={zp('score_c')}{zp('score_d')}0")
assert won and zp('monde') == 2, "le bot doit finir les deux mondes"
assert max_cam == 768 and zp('prochaine_col') == 64
# les jingles : on laisse la fanfare finale se derouler (le bot est immobile)
n_win = len(snes.spc_events)
for _ in range(70): snes.frame(IDLE)
v2kon = [p for _, v, p in snes.spc_events if v == 2 and p]
fanfare = [1072, 1350, 1606, 1802]                     # do5 mi5 sol5 la5
assert v2kon[-4:] == fanfare, f"jingle de victoire finale: {v2kon[-4:]}"
# ... et la fanfare du monde 2 a bien sonne aussi (2 passages de chaque note ;
# les bips de saut du bot s'intercalent, on ne teste donc pas la contiguite)
assert all(v2kon.count(n) >= 2 for n in fanfare), "fanfare du monde 2 absente"
assert 803 in v2kon, "bip de saut absent"
apres = snes.spc_events[n_win:]
assert not any(v in (0, 1) and p for _, v, p in apres), "musique non coupee"
print("jingles: fanfare do5-mi5-sol5-la5 aux deux victoires, musique coupee a la fin")
if not shot_m2:
    snes.render_mode1('rsnes-monde2.png')

# ===== 5. puce : carte + VRAM + score =====
snes2 = SNES(os.path.join(RACINE, 'neo-runner-snes/neo-runner.sfc'))
snes2.step(700000)
snes2.frame(START); snes2.frame(IDLE)
r2 = snes2.ram
def zp2(n): return r2[ZP[n]]
sc0 = zp2('score_d')
r2[ZP['joueur_x_lo']] = 80; r2[ZP['joueur_x_hi']] = 0
r2[ZP['joueur_y']] = 150; r2[ZP['vy_lo']] = 0; r2[ZP['vy_hi']] = 0; r2[ZP['au_sol']] = 0
got = False
for _ in range(40):
    snes2.frame(IDLE)
    if zp2('score_d') == sc0 + 1: got = True; break
assert got and r2[CARTE + 5*16 + 11] == 0, "puce non ramassee"
assert any(v == 2 and p == 2143 for _, v, p in snes2.spc_events), "cling do6 absent"
snes2.frame(IDLE)
addr = (zp2('puce_adr_hi') << 8) | zp2('puce_adr_lo')
t, a = snes2.vram[addr*2], snes2.vram[addr*2+1]
assert t == 0x00 and a == 0x10, f"effacement puce VRAM: {t:02X}/{a:02X}"
print(f"puce ramassee : carte + VRAM (adresse ${addr:04X}, attr quartier) OK")

# ===== 6. stomp et collision fatale =====
d0 = ZP['drone_actif']
dx = r2[ZP['drone_x_lo']] | (r2[ZP['drone_x_hi']] << 8)
r2[ZP['joueur_x_lo']] = dx & 0xFF; r2[ZP['joueur_x_hi']] = dx >> 8
r2[ZP['joueur_y']] = 182; r2[ZP['vy_lo']] = 0; r2[ZP['vy_hi']] = 2; r2[ZP['au_sol']] = 0
stomped = False
for _ in range(10):
    snes2.frame(IDLE)
    if r2[d0] == 0: stomped = True; break
assert stomped and zp2('vy_hi') == 0xFD and zp2('vies') == 3
assert any(v == 3 and p == 1024 for _, v, p in snes2.spc_events), "crounch absent"
print("stomp de drone : rebond -3, crounch, pas de vie perdue OK")

print("\nALL RUNNER SNES TESTS PASSED")
