#!/usr/bin/env python3
"""L'atelier graphique de NEO-RUNNER SNES.

Produit :
  gfx_bg.bin    tuiles du monde (4bpp : immeubles, neons, puces, antenne)
  gfx_bg3.bin   tuiles du bandeau (2bpp : chiffres, icones, lettres)
  gfx_obj.bin   sprites (robot 2 poses, drone 2 phases)
  palettes.bin  512 octets de CGRAM
  gradient.bin  table HDMA du ciel nocturne

Format 2bpp SNES : 16 octets/tuile, plans 0 et 1 ENTRELACES ligne par ligne
(la NES les rangeait l'un apres l'autre : meme idee, autre rangement).
"""
import struct, os

OUT = os.path.dirname(os.path.abspath(__file__)) + "/../"

def couleur(r, g, b):
    return (b >> 3 << 10) | (g >> 3 << 5) | (r >> 3)

def tuile_4bpp(rows):
    px = [[0 if c == '.' else int(c, 16) for c in row] for row in rows]
    out = bytearray()
    for pp in (0, 2):
        for y in range(8):
            lo = hi = 0
            for x in range(8):
                lo = (lo << 1) | ((px[y][x] >> pp) & 1)
                hi = (hi << 1) | ((px[y][x] >> (pp + 1)) & 1)
            out += bytes((lo, hi))
    return bytes(out)

def tuile_2bpp(rows):
    px = [[0 if c == '.' else int(c, 16) for c in row] for row in rows]
    out = bytearray()
    for y in range(8):
        lo = hi = 0
        for x in range(8):
            lo = (lo << 1) | (px[y][x] & 1)
            hi = (hi << 1) | ((px[y][x] >> 1) & 1)
        out += bytes((lo, hi))
    return bytes(out)

VIDE = ["........"] * 8

# =============================================================================
#  PALETTES
# =============================================================================
#  BG 2bpp (le bandeau) : 8 palettes de 4 couleurs dans CGRAM 0-31.
#  BG 4bpp (le monde)  : palettes 4 et 5 (CGRAM 64-95) = les deux quartiers.
#  Le MEME immeuble a son neon cyan ou rose selon la palette de la case.

def quartier(neon, neon_sombre):
    return [0,
            couleur(184, 200, 216),    # 1  arete eclairee
            couleur(104, 120, 160),    # 2  facade claire
            couleur(68, 80, 112),      # 3  facade
            couleur(42, 52, 72),       # 4  facade sombre
            couleur(16, 24, 40),       # 5  contour
            couleur(255, 216, 80),     # 6  fenetre allumee
            couleur(160, 128, 32),     # 7  fenetre eteinte
            neon,                      # 8  le NEON du quartier !
            neon_sombre,               # 9
            couleur(255, 240, 160),    # 10 or brillant (puces)
            couleur(255, 216, 64),     # 11 or
            couleur(208, 152, 24),     # 12 or sombre
            couleur(128, 96, 8),       # 13 or fonce
            couleur(255, 80, 80),      # 14 balise rouge
            0]

pal256 = [0] * 256
# --- BG 2bpp : bandeau ---
pal256[4:8]   = [0, couleur(248, 248, 248), couleur(168, 176, 192), couleur(32, 40, 56)]   # texte
pal256[8:12]  = [0, couleur(255, 216, 64), couleur(208, 152, 24), couleur(80, 60, 8)]      # icone or
pal256[12:16] = [0, couleur(64, 232, 248), couleur(24, 136, 168), couleur(8, 48, 64)]      # liseret neon
# --- BG 4bpp : les deux quartiers ---
pal256[64:80] = quartier(couleur(64, 232, 248), couleur(24, 136, 168))    # palette 4 : cyan
pal256[80:96] = quartier(couleur(255, 112, 200), couleur(176, 48, 120))   # palette 5 : rose
# --- sprites ---
pal256[128:144] = [0,
    couleur(248, 252, 255), couleur(208, 216, 232), couleur(152, 164, 192),
    couleur(96, 108, 140),  couleur(40, 48, 72),    couleur(255, 64, 64),
    couleur(160, 16, 16),   couleur(64, 232, 248),  couleur(255, 216, 64),
    0, 0, 0, 0, 0, 0]                                       # robot
pal256[144:160] = [0,
    couleur(120, 244, 255), couleur(64, 200, 224),  couleur(24, 128, 160),
    couleur(8, 64, 88),     couleur(255, 80, 80),   couleur(140, 8, 8),
    couleur(200, 208, 216), couleur(120, 128, 144), 0, 0, 0, 0, 0, 0, 0]   # drone

with open(OUT + "palettes.bin", "wb") as f:
    for c in pal256:
        f.write(struct.pack("<H", c))

# =============================================================================
#  BG1 4bpp : le monde (memes numeros de tuiles que la version NES !)
# =============================================================================
bg = {}
bg[0x01] = ["13333331",        # l'immeuble : facade + fenetres allumees
            "23444442",
            "24466442",
            "24466442",
            "23444442",
            "24466442",
            "24466442",
            "53444445"]
bg[0x02] = ["88888888",        # le dessus de toit : liseret NEON
            "89999998",
            "12222221",
            "23333332",
            "24444442",
            "24444442",
            "23333332",
            "54444445"]
bg[0x04] = ["........",        # la puce de donnees, quart haut-gauche
            "........",
            "........",
            "......5A",
            ".....5AB",
            "....5ABB",
            "....ABBC",
            "....ABCC"]
bg[0x05] = ["........",
            "........",
            "........",
            "A5......",
            "BA5.....",
            "BBA5....",
            "CBBA....",
            "CCBA...."]
bg[0x06] = ["....ABCC",
            "....ABBC",
            ".....5AB",
            "......5A",
            "........",
            "........",
            "........",
            "........"]
bg[0x07] = ["CCBA....",
            "CBBA....",
            "BA5.....",
            "A5......",
            "........",
            "........",
            "........",
            "........"]
bg[0x0B] = ["......EE",        # l'antenne : la balise...
            ".....EAE",
            "......EE",
            ".......1",
            ".......1",
            ".......2",
            ".......2",
            ".......2"]
bg[0x0C] = ["E.......",
            "E.......",
            "........",
            "1.......",
            "1.......",
            "2.......",
            "2.......",
            "2......."]
bg[0x0D] = [".......2",        # ...et le mat
            ".......2",
            ".......3",
            ".......3",
            "......23",
            ".....223",
            "....2233",
            "..222333"]
bg[0x0E] = ["2.......",
            "2.......",
            "3.......",
            "3.......",
            "32......",
            "322.....",
            "3322....",
            "333222.."]

NB_BG = 0x10
with open(OUT + "gfx_bg.bin", "wb") as f:
    for i in range(NB_BG):
        f.write(tuile_4bpp(bg.get(i, VIDE)))

# =============================================================================
#  BG3 2bpp : le bandeau (chiffres, icones, lettres du titre)
# =============================================================================
FONTE = {
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
    0x1B: [0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00],           # tiret
    0x20: [0x30,0x78,0xCC,0xCC,0xFC,0xCC,0xCC,0x00],           # A
    0x21: [0xFE,0x62,0x68,0x78,0x68,0x62,0xFE,0x00],           # E
    0x22: [0x78,0x30,0x30,0x30,0x30,0x30,0x78,0x00],           # I
    0x23: [0xC6,0xE6,0xF6,0xDE,0xCE,0xC6,0xC6,0x00],           # N
    0x24: [0x38,0x6C,0xC6,0xC6,0xC6,0x6C,0x38,0x00],           # O
    0x25: [0xFC,0x66,0x66,0x7C,0x60,0x60,0xF0,0x00],           # P
    0x26: [0xFC,0x66,0x66,0x7C,0x6C,0x66,0xE6,0x00],           # R
    0x27: [0x78,0xCC,0xE0,0x70,0x1C,0xCC,0x78,0x00],           # S
    0x28: [0xFC,0xB4,0x30,0x30,0x30,0x30,0x78,0x00],           # T
    0x29: [0xCC,0xCC,0xCC,0xCC,0xCC,0xCC,0x7C,0x00],           # U
}
def glyphe(bits):
    rows = []
    for y in range(8):
        row = ""
        for x in range(8):
            ici = (bits[y] >> (7 - x)) & 1
            ombre = (bits[y-1] >> (8-x)) & 1 if y > 0 and x > 0 else 0
            row += '1' if ici else ('3' if ombre else '.')
        rows.append(row)
    return rows

bg3 = {n: glyphe(b) for n, b in FONTE.items()}
bg3[0x01] = ["........",       # l'icone puce du bandeau (2bpp, or)
             "...11...",
             "..1221..",
             ".122221.",
             ".122221.",
             "..1221..",
             "...11...",
             "........"]
bg3[0x02] = ["...11...",       # la tete du robot, version pictogramme
             "..1111..",
             ".111111.",
             ".122221.",
             ".111111.",
             "..1111..",
             "..3..3..",
             "........"]
bg3[0x03] = ["........",       # le liseret du bandeau
             "11111111",
             "22222222",
             "33333333",
             "........",
             "........",
             "........",
             "........"]

NB_BG3 = 0x2A
with open(OUT + "gfx_bg3.bin", "wb") as f:
    for i in range(NB_BG3):
        f.write(tuile_2bpp(bg3.get(i, VIDE)))

# =============================================================================
#  Sprites 4bpp : le robot R-2026 et les drones, en 16 couleurs
# =============================================================================
obj = {}
obj[0x00] = ["...11...",       # la tete (antenne, visiere rouge qui brille)
             "...25...",
             ".122221.",
             "12222221",
             "16666661",
             "12222221",
             ".122221.",
             "..2..2.."]
obj[0x01] = [".122221.",       # le corps, pose 1 (jambes serrees)
             "12299221",
             "12222221",
             ".122221.",
             "..2..2..",
             "..3..3..",
             ".33..33.",
             "........"]
obj[0x02] = [".122221.",       # pose 2 : la course, jambes ecartees
             "12299221",
             "12222221",
             ".122221.",
             ".2....2.",
             ".3....3.",
             "33....33",
             "........"]
obj[0x03] = [".11..11.",       # le drone, rotors phase 1
             "12211221",
             ".122221.",
             ".125521.",
             ".122221.",
             "..1221..",
             "...77...",
             "........"]
obj[0x04] = ["1..11..1",       # phase 2
             "12211221",
             ".122221.",
             ".125521.",
             ".122221.",
             "..1221..",
             "...77...",
             "........"]

NB_OBJ = 0x05
with open(OUT + "gfx_obj.bin", "wb") as f:
    for i in range(NB_OBJ):
        f.write(tuile_4bpp(obj.get(i, VIDE)))

# =============================================================================
#  Le degrade HDMA : nuit urbaine, du noir bleute au violet de pollution
# =============================================================================
with open(OUT + "gradient.bin", "wb") as f:
    ETAPES = 28
    for i in range(ETAPES):
        t = i / (ETAPES - 1)
        r = int(4 + 44 * t * t)
        g = int(4 + 8 * t)
        b = int(24 + 56 * t)
        f.write(bytes([8, 0, 0]) + struct.pack("<H", couleur(r, g, b)))
    f.write(bytes([0]))

print("runner SNES: gfx_bg / gfx_bg3 / gfx_obj / palettes / gradient generes")
