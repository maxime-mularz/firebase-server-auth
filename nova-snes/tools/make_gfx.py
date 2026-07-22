#!/usr/bin/env python3
"""L'atelier graphique de NOVA-2026 SNES.

Produit :
  gfx_bg.bin    tuiles du ciel (4bpp : etoiles — la COULEUR vient de la palette !)
  gfx_bg3.bin   la couche fixe (2bpp : chiffres, lettres, tiret)
  gfx_obj.bin   sprites (intercepteur, tir, drone 2 phases, explosion)
  palettes.bin  512 octets de CGRAM
  gradient.bin  table HDMA : la profondeur de l'espace

L'astuce de ce jeu : UNE seule tuile d'etoile, mais trois palettes (4, 5, 6).
Le semeur d'etoiles choisit la palette au hasard : un ciel bleute, dore et
blanc, sans depenser une tuile de plus. Sur NES, une etoile n'avait qu'une
couleur par quart d'ecran (les attributs) — ici, c'est CASE PAR CASE.
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
def ciel(coeur, halo, lueur):
    """Une palette d'etoile : le coeur brillant, son halo, sa lueur discrete."""
    p = [0] * 16
    p[1] = lueur
    p[2] = halo
    p[3] = coeur
    return p

pal256 = [0] * 256
# --- BG3 2bpp : le texte ---
pal256[4:8]   = [0, couleur(248, 248, 248), couleur(168, 176, 192), couleur(32, 40, 56)]    # blanc
pal256[8:12]  = [0, couleur(64, 232, 248), couleur(24, 136, 168), couleur(8, 48, 64)]       # cyan (titre)
# --- BG1 4bpp : trois familles d'etoiles ---
pal256[64:80]  = ciel(couleur(176, 208, 255), couleur(96, 128, 208), couleur(40, 56, 112))  # 4 : bleutees
pal256[80:96]  = ciel(couleur(255, 232, 160), couleur(216, 168, 72), couleur(104, 80, 32))  # 5 : dorees
pal256[96:112] = ciel(couleur(255, 255, 255), couleur(200, 208, 224), couleur(96, 104, 128))# 6 : blanches
# --- sprites ---
pal256[128:144] = [0,
    couleur(248, 252, 255), couleur(200, 212, 232), couleur(136, 152, 184),
    couleur(72, 84, 116),   couleur(64, 232, 248),  couleur(16, 144, 176),
    couleur(255, 96, 64),   couleur(255, 200, 64),  couleur(160, 24, 8),
    0, 0, 0, 0, 0, 0]                                         # 0 : l'intercepteur
pal256[144:160] = [0,
    couleur(255, 144, 216), couleur(216, 80, 160),  couleur(136, 32, 96),
    couleur(64, 8, 40),     couleur(255, 64, 64),   couleur(140, 8, 8),
    couleur(216, 224, 232), couleur(128, 136, 152), 0, 0, 0, 0, 0, 0, 0]   # 1 : drones
pal256[160:176] = [0,
    couleur(255, 248, 208), couleur(255, 216, 64),  couleur(255, 144, 32),
    couleur(232, 64, 24),   couleur(136, 24, 8),    couleur(255, 255, 255),
    0, 0, 0, 0, 0, 0, 0, 0, 0]                                # 2 : explosions

assert len(pal256) == 256, f"palette CGRAM : {len(pal256)} entrees (tranche mal comptee ?)"
with open(OUT + "palettes.bin", "wb") as f:
    for c in pal256:
        f.write(struct.pack("<H", c))

# =============================================================================
#  BG1 4bpp : le ciel (memes numeros de tuiles que la version NES)
# =============================================================================
bg = {}
bg[0x01] = ["........",        # la petite etoile : un point et son halo
            "........",
            "........",
            "...12...",
            "...21...",
            "........",
            "........",
            "........"]
bg[0x02] = ["...1....",        # l'etoile brillante : le scintillement en croix
            "...2....",
            "...3....",
            "1233321.",
            "...3....",
            "...2....",
            "...1....",
            "........"]

NB_BG = 0x04
with open(OUT + "gfx_bg.bin", "wb") as f:
    for i in range(NB_BG):
        f.write(tuile_4bpp(bg.get(i, VIDE)))

# =============================================================================
#  BG3 2bpp : chiffres et lettres (memes codes que la version NES !)
# =============================================================================
FONTE = {
    0x10: [0x7C,0xC6,0xCE,0xD6,0xE6,0xC6,0x7C,0x00],            # 0-9
    0x11: [0x30,0x70,0x30,0x30,0x30,0x30,0xFC,0x00],
    0x12: [0x78,0xCC,0x0C,0x38,0x60,0xCC,0xFC,0x00],
    0x13: [0x78,0xCC,0x0C,0x38,0x0C,0xCC,0x78,0x00],
    0x14: [0x1C,0x3C,0x6C,0xCC,0xFE,0x0C,0x1E,0x00],
    0x15: [0xFC,0xC0,0xF8,0x0C,0x0C,0xCC,0x78,0x00],
    0x16: [0x38,0x60,0xC0,0xF8,0xCC,0xCC,0x78,0x00],
    0x17: [0xFC,0xCC,0x0C,0x18,0x30,0x30,0x30,0x00],
    0x18: [0x78,0xCC,0xCC,0x78,0xCC,0xCC,0x78,0x00],
    0x19: [0x78,0xCC,0xCC,0x7C,0x0C,0x18,0x70,0x00],
    0x1B: [0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00],            # tiret
    0x20: [0x30,0x78,0xCC,0xCC,0xFC,0xCC,0xCC,0x00],            # A
    0x21: [0x3C,0x66,0xC0,0xC0,0xC0,0x66,0x3C,0x00],            # C
    0x22: [0xF8,0x6C,0x66,0x66,0x66,0x6C,0xF8,0x00],            # D
    0x23: [0xFE,0x62,0x68,0x78,0x68,0x62,0xFE,0x00],            # E
    0x24: [0x3C,0x66,0xC0,0xCE,0xC6,0x66,0x3E,0x00],            # G
    0x25: [0x78,0x30,0x30,0x30,0x30,0x30,0x78,0x00],            # I
    0x26: [0xC6,0xEE,0xFE,0xD6,0xC6,0xC6,0xC6,0x00],            # M
    0x27: [0xC6,0xE6,0xF6,0xDE,0xCE,0xC6,0xC6,0x00],            # N
    0x28: [0x38,0x6C,0xC6,0xC6,0xC6,0x6C,0x38,0x00],            # O
    0x29: [0xFC,0x66,0x66,0x7C,0x60,0x60,0xF0,0x00],            # P
    0x2A: [0xFC,0x66,0x66,0x7C,0x6C,0x66,0xE6,0x00],            # R
    0x2B: [0x78,0xCC,0xE0,0x70,0x1C,0xCC,0x78,0x00],            # S
    0x2C: [0xFC,0xB4,0x30,0x30,0x30,0x30,0x78,0x00],            # T
    0x2D: [0xCC,0xCC,0xCC,0xCC,0xCC,0xCC,0x7C,0x00],            # U
    0x2E: [0xCC,0xCC,0xCC,0xCC,0xCC,0x78,0x30,0x00],            # V
}
def glyphe(bits):
    """La lettre en couleur 1, son ombre portee en couleur 3 : du relief."""
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

NB_BG3 = 0x2F
with open(OUT + "gfx_bg3.bin", "wb") as f:
    for i in range(NB_BG3):
        f.write(tuile_2bpp(bg3.get(i, VIDE)))

# =============================================================================
#  Sprites 4bpp : l'intercepteur NOVA, soigne (verriere cyan, reacteurs)
# =============================================================================
obj = {}
obj[0x03] = [".......1",       # l'intercepteur, moitie gauche : le nez,
             "......12",       #  la verriere cyan (5/6), l'aile qui s'evase,
             ".....125",       #  le reacteur qui crache (7/8/9)
             "....1256",
             "..112223",
             ".1222334",
             "12223478",
             "1223.89."]
obj[0x04] = ["1.......",       # moitie droite : le miroir, dessine a la main
             "21......",       #  (exercice : le refaire avec le bit de
             "521.....",       #   retournement H des attributs OAM !)
             "6521....",
             "322211..",
             "4332221.",
             "87432221",
             ".98.3221"]
obj[0x05] = ["...88...",       # le tir : un trait d'energie doree
             "..8778..",
             "..8778..",
             "...88...",
             "...88...",
             "...78...",
             "........",
             "........"]
obj[0x06] = ["77....77",       # le drone fou : rotors gris, oeil rouge
             ".7....7.",
             "11111111",
             "12255221",
             "12222221",
             ".111111.",
             "..3..3..",
             "........"]
obj[0x07] = [".77..77.",       # phase 2 : les rotors ont tourne
             ".7....7.",
             "11111111",
             "12255221",
             "12222221",
             ".111111.",
             "..3..3..",
             "........"]
obj[0x08] = ["1..33..4",       # l'explosion : creme, or, orange, rouge, blanc
             ".432264.",
             ".322234.",
             "43261234",
             ".3122234",
             "43222634",
             "..4326.4",
             "4..33..1"]

NB_OBJ = 0x09
with open(OUT + "gfx_obj.bin", "wb") as f:
    for i in range(NB_OBJ):
        f.write(tuile_4bpp(obj.get(i, VIDE)))

# =============================================================================
#  Le degrade HDMA : l'espace profond, du noir absolu au bleu de l'orbite
# =============================================================================
with open(OUT + "gradient.bin", "wb") as f:
    ETAPES = 28
    for i in range(ETAPES):
        t = i / (ETAPES - 1)
        r = int(2 + 10 * t * t)
        g = int(2 + 14 * t * t)
        b = int(8 + 48 * t * t)
        f.write(bytes([8, 0, 0]) + struct.pack("<H", couleur(r, g, b)))
    f.write(bytes([0]))

print("nova SNES: gfx_bg / gfx_bg3 / gfx_obj / palettes / gradient generes")
