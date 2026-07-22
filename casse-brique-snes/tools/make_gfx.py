#!/usr/bin/env python3
"""L'atelier graphique du casse-brique SNES.

La SNES dessine en 4 bits par pixel : 16 couleurs par tuile (contre 4 sur
NES). Écrire ça octet par octet en assembleur serait un supplice : ce script
transforme du pixel-art LISIBLE (des grilles de caractères hexadécimaux) en
binaires prêts pour la console :

  gfx_bg.bin    les tuiles du décor (briques, murs, police...)
  gfx_obj.bin   les tuiles des sprites (balle, raquette, capsules)
  palettes.bin  les 512 octets de CGRAM (couleurs 15 bits : 0BBBBBGGGGGRRRRR)
  gradient.bin  la table HDMA du dégradé de fond (voir le README)

Format 4bpp SNES : chaque tuile 8x8 = 32 octets. Les plans de bits 0 et 1
sont entrelacés ligne par ligne (16 octets), puis les plans 2 et 3 (16
octets). Chaque pixel = 4 bits répartis sur les 4 plans.
"""
import struct, sys, os

OUT = os.path.dirname(os.path.abspath(__file__)) + "/../"

def couleur(r, g, b):
    """RGB 0-255 -> mot CGRAM 15 bits (5 bits par canal, bleu en tête)."""
    return (b >> 3 << 10) | (g >> 3 << 5) | (r >> 3)

def tuile_4bpp(rows):
    """8 chaînes de 8 caractères hex ('.'=0) -> 32 octets SNES 4bpp."""
    px = [[0 if c == '.' else int(c, 16) for c in row] for row in rows]
    out = bytearray()
    for plane_pair in (0, 2):
        for y in range(8):
            lo = hi = 0
            for x in range(8):
                lo = (lo << 1) | ((px[y][x] >> plane_pair) & 1)
                hi = (hi << 1) | ((px[y][x] >> (plane_pair + 1)) & 1)
            out += bytes((lo, hi))
    return bytes(out)

VIDE = ["........"] * 8

# =============================================================================
#  LES PALETTES — 8 palettes de fond + 8 de sprites, 16 couleurs chacune
# =============================================================================
#  Convention "matériau" : 1=éclat, 2=clair, 3=base, 4=sombre, 5=contour.
#  La MÊME tuile de brique devient orange, acier ou or selon la palette que
#  la tilemap lui attribue : c'est le grand luxe de la SNES.

def materiau(eclat, clair, base, sombre, contour, extra=None):
    pal = [0, eclat, clair, base, sombre, contour]
    pal += extra or []
    pal += [0] * (16 - len(pal))
    return pal[:16]

TEXTE = [couleur(248, 248, 248), couleur(168, 176, 192), couleur(40, 48, 64),
         couleur(255, 216, 64)]                    # 6,7,8,9 : blanc, gris, ombre, or

pal_bg = []
# pal 0 : murs d'acier + texte du bandeau
pal_bg.append(materiau(couleur(216, 228, 240), couleur(144, 160, 180),
                       couleur(88, 104, 124), couleur(48, 60, 76),
                       couleur(16, 22, 30), TEXTE))
# pal 1 : brique ORANGE
pal_bg.append(materiau(couleur(255, 220, 160), couleur(255, 152, 56),
                       couleur(224, 104, 16), couleur(160, 64, 0),
                       couleur(80, 24, 0), TEXTE))
# pal 2 : brique ACIER (les solides)
pal_bg.append(materiau(couleur(232, 240, 248), couleur(168, 184, 200),
                       couleur(112, 128, 144), couleur(72, 88, 104),
                       couleur(32, 40, 48), TEXTE))
# pal 3 : brique OR
pal_bg.append(materiau(couleur(255, 248, 192), couleur(255, 216, 64),
                       couleur(224, 168, 0), couleur(160, 112, 0),
                       couleur(80, 64, 0), TEXTE))
while len(pal_bg) < 8:
    pal_bg.append([0] * 16)

pal_obj = []
# pal 0 : la balle (nacre brillante)
pal_obj.append(materiau(couleur(255, 255, 255), couleur(224, 232, 240),
                        couleur(160, 176, 200), couleur(96, 112, 144),
                        couleur(40, 48, 72)))
# pal 1 : la raquette (métal cyan lumineux)
pal_obj.append(materiau(couleur(224, 255, 255), couleur(96, 216, 240),
                        couleur(32, 144, 192), couleur(16, 80, 112),
                        couleur(8, 32, 48), [couleur(160, 240, 255)]))
# pal 2 : les capsules (or + rouge + blanc)
pal_obj.append(materiau(couleur(255, 248, 192), couleur(255, 216, 64),
                        couleur(224, 168, 0), couleur(160, 112, 0),
                        couleur(80, 64, 0),
                        [couleur(255, 96, 96), couleur(200, 24, 24),
                         couleur(120, 0, 0), couleur(248, 248, 248)]))
while len(pal_obj) < 8:
    pal_obj.append([0] * 16)

with open(OUT + "palettes.bin", "wb") as f:
    for pal in pal_bg + pal_obj:
        for c in pal:
            f.write(struct.pack("<H", c))

# =============================================================================
#  LES TUILES DU DÉCOR
# =============================================================================
bg = {}

# --- la brique biseautée, moitiés gauche/droite (marges : bas et côtés) ------
bg[0x01] = ["........",
            ".1111111",
            ".1222222",
            ".2233333",
            ".2333333",
            ".3334444",
            ".4444444",
            "........"]
bg[0x02] = ["........",
            "1111114.",
            "2223344.",
            "3333344.",
            "3334444.",
            "4444445.",
            "4445555.",
            "........"]
# --- la même, rivetée (les solides encaissent 2 coups) ------------------------
bg[0x03] = [r.replace('3', '3') for r in bg[0x01]]
bg[0x03] = ["........",
            ".1111111",
            ".1211122",
            ".2251333",
            ".2315333",
            ".3334444",
            ".4444444",
            "........"]
bg[0x04] = ["........",
            "1111114.",
            "2211244.",
            "3351344.",
            "3315444.",
            "4444445.",
            "4445555.",
            "........"]
# --- la fissurée --------------------------------------------------------------
bg[0x05] = ["........",
            ".1115.11",
            ".125.222",
            ".22.5333",
            ".235.333",
            ".33.4444",
            ".445.444",
            "........"]
bg[0x06] = ["........",
            "11.5114.",
            "225.344.",
            "33.5344.",
            "335.444.",
            "44.5445.",
            "44.5555.",
            "........"]
# --- le mur d'acier, plaque boulonnée -----------------------------------------
bg[0x07] = ["12222223",
            "23333334",
            "23133134",
            "23333334",
            "23333334",
            "23133134",
            "23333334",
            "34444445"]

# --- la police : les glyphes 1 bit de la version NES, enrichis d'une ombre ----
FONTE = {   # (identique à la CHR NES : chaque octet = une ligne de pixels)
    0x10: [0x7C,0xC6,0xCE,0xD6,0xE6,0xC6,0x7C,0x00],
    0x11: [0x30,0x70,0x30,0x30,0x30,0x30,0xFC,0x00],
    0x12: [0x78,0xCC,0x0C,0x38,0x60,0xCC,0xFC,0x00],
    0x13: [0x78,0xCC,0x0C,0x38,0x0C,0xCC,0x78,0x00],
    0x14: [0x1C,0x3C,0x6C,0xCC,0xFE,0x0C,0x1E,0x00],
    0x15: [0xFC,0xC0,0xF8,0x0C,0x0C,0xCC,0x78,0x00],
    0x16: [0x38,0x60,0xC0,0xF8,0xCC,0xCC,0x78,0x00],
    0x17: [0xFC,0xCC,0x0C,0x18,0x30,0x30,0x30,0x00],
    0x18: [0x78,0xCC,0xCC,0x78,0xCC,0xCC,0x78,0x00],
    0x19: [0x78,0xCC,0xCC,0x7C,0x0C,0x18,0x70,0x00],
    0x1B: [0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00],
    0x20: [0x30,0x78,0xCC,0xCC,0xFC,0xCC,0xCC,0x00],   # A
    0x21: [0xFC,0x66,0x66,0x7C,0x66,0x66,0xFC,0x00],   # B
    0x22: [0x3C,0x66,0xC0,0xC0,0xC0,0x66,0x3C,0x00],   # C
    0x23: [0xF8,0x6C,0x66,0x66,0x66,0x6C,0xF8,0x00],   # D
    0x24: [0xFE,0x62,0x68,0x78,0x68,0x62,0xFE,0x00],   # E
    0x25: [0x78,0x30,0x30,0x30,0x30,0x30,0x78,0x00],   # I
    0x26: [0x38,0x6C,0xC6,0xC6,0xC6,0x6C,0x38,0x00],   # O
    0x27: [0xFC,0x66,0x66,0x7C,0x60,0x60,0xF0,0x00],   # P
    0x28: [0x78,0xCC,0xCC,0xCC,0xDC,0x78,0x1C,0x00],   # Q
    0x29: [0xFC,0x66,0x66,0x7C,0x6C,0x66,0xE6,0x00],   # R
    0x2A: [0x78,0xCC,0xE0,0x70,0x1C,0xCC,0x78,0x00],   # S
    0x2B: [0xFC,0xB4,0x30,0x30,0x30,0x30,0x78,0x00],   # T
    0x2C: [0xCC,0xCC,0xCC,0xCC,0xCC,0xCC,0x7C,0x00],   # U
    0x2D: [0x3C,0x66,0xC0,0xCE,0xC6,0x66,0x3E,0x00],   # G
    0x2E: [0xC6,0xEE,0xFE,0xD6,0xC6,0xC6,0xC6,0x00],   # M
    0x2F: [0xCC,0xCC,0xCC,0xCC,0xCC,0x78,0x30,0x00],   # V
}
def glyphe_ombre(bits):
    """Glyphe blanc (couleur 6) + ombre portée (couleur 8) décalée de +1,+1."""
    rows = []
    for y in range(8):
        row = ""
        for x in range(8):
            ici = (bits[y] >> (7 - x)) & 1
            ombre = (bits[y - 1] >> (8 - x)) & 1 if y > 0 and x > 0 else 0
            row += '6' if ici else ('8' if ombre else '.')
        rows.append(row)
    return rows

for num, bits in FONTE.items():
    bg[num] = glyphe_ombre(bits)

NB_BG = 0x30
with open(OUT + "gfx_bg.bin", "wb") as f:
    for i in range(NB_BG):
        f.write(tuile_4bpp(bg.get(i, VIDE)))

# =============================================================================
#  LES TUILES DES SPRITES
# =============================================================================
obj = {}
# --- la balle, une bille nacrée avec son reflet --------------------------------
obj[0x00] = ["..3443..",
             ".322234.",
             "3112234.",
             "31223344",
             "32233444",
             "32334445",
             ".344445.",
             "..4455.."]
# --- la raquette : capot métallique, liseré lumineux ---------------------------
obj[0x01] = ["........",
             "...6666.",
             "..612222",
             ".6122333",
             ".6233344",
             "..634444",
             "...5555.",
             "........"]
obj[0x02] = ["........",
             "66666666",
             "22222222",
             "23333333",
             "33334444",
             "44444444",
             "55555555",
             "........"]
obj[0x03] = ["........",
             ".6666...",
             "222216..",
             "333316..",
             "443326..",
             "44436...",
             ".5555...",
             "........"]
# --- les capsules : pilule dorée, symbole selon le bonus ----------------------
def pilule(symbole):
    rows = ["........",
            ".122221.",
            "12333321",
            "12333321",
            "12344321",
            ".144441.",
            "........",
            "........"]
    out = []
    for y, row in enumerate(rows):
        new = ""
        for x, c in enumerate(row):
            s = symbole[y][x]
            new += s if s != '.' else c
        out.append(new)
    return out

BLANC9 = '9'   # dans la palette capsule, 9 = blanc pur
obj[0x04] = pilule(["........", "........", "........",
                    ".9....9.", ".999999.", "........", "........", "........"])  # élargir
obj[0x05] = pilule(["........", "........", "...99...",
                    "...99...", "........", "........", "........", "........"])  # lente
obj[0x06] = ["........",                                                            # vie :
             ".66.66..",                                                            # un cœur
             "67767760",
             "67777760",
             ".677760.",
             "..6760..",
             "...6....",
             "........"]
obj[0x06] = [r.replace('0', '.') for r in obj[0x06]]
obj[0x07] = pilule(["........", "........", ".99..99.",
                    ".99..99.", "........", "........", "........", "........"])  # multiball

NB_OBJ = 0x08
with open(OUT + "gfx_obj.bin", "wb") as f:
    for i in range(NB_OBJ):
        f.write(tuile_4bpp(obj.get(i, VIDE)))

# =============================================================================
#  LE DÉGRADÉ DE FOND — une table HDMA (voir le README, c'est LA magie SNES)
# =============================================================================
#  Chaque entrée : [nombre de lignes][adresse CGRAM x2][couleur lo][couleur hi]
#  On fait glisser la couleur 0 (le fond) du bleu nuit vers le violet profond.
with open(OUT + "gradient.bin", "wb") as f:
    ETAPES = 28
    for i in range(ETAPES):
        t = i / (ETAPES - 1)
        r = int(8 + 40 * t)
        g = int(8 + 6 * t)
        b = int(40 + 48 * t)
        c = couleur(r, g, b)
        f.write(bytes([8, 0, 0]) + struct.pack("<H", c))   # 8 lignes par étape
    f.write(bytes([0]))                                    # fin de table

print("gfx_bg.bin  :", NB_BG, "tuiles de décor (4bpp)")
print("gfx_obj.bin :", NB_OBJ, "tuiles de sprites")
print("palettes.bin: 512 octets de CGRAM")
print("gradient.bin: table HDMA du ciel")
