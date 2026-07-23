#!/usr/bin/env python3
"""L'atelier graphique de CRISTAL-2026 (phase 1 du mini-RPG).

Produit :
  gfx_bg.bin    tuiles de la salle (4bpp : pierre, tapis, cristal, coffre)
  gfx_bg3.bin   la couche fixe (2bpp : police COMPLETE A-Z + chiffres)
  gfx_obj.bin   sprites (le heros 16x16, 3 directions x 2 poses, le curseur)
  palettes.bin  512 octets de CGRAM
  gradient.bin  table HDMA : la penombre de la salle du cristal

Nouveaute : les objets 16x16 (cristal, coffre, heros) se dessinent en UNE
grille de 16x16, que `grille16` decoupe en 4 tuiles de 8x8 (haut-gauche,
haut-droit, bas-gauche, bas-droit) — l'ordre attendu par le jeu.
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

def grille16(rows16):
    """Une grille 16x16 -> les 4 tuiles 8x8 (HG, HD, BG, BD)."""
    assert len(rows16) == 16 and all(len(r) == 16 for r in rows16), \
        "grille16 : il faut 16 lignes de 16 caracteres"
    return [[r[:8] for r in rows16[:8]],  [r[8:] for r in rows16[:8]],
            [r[:8] for r in rows16[8:]],  [r[8:] for r in rows16[8:]]]

VIDE = ["........"] * 8

# =============================================================================
#  PALETTES
# =============================================================================
pal256 = [0] * 256
# --- BG3 2bpp : le texte ---
pal256[4:8]   = [0, couleur(248, 248, 248), couleur(168, 176, 192), couleur(32, 40, 56)]   # blanc
pal256[8:12]  = [0, couleur(120, 240, 255), couleur(40, 150, 190), couleur(8, 50, 70)]     # cyan (titre)
# --- BG1 4bpp : palette 4 = la salle, 5 = le cristal, 6 = le coffre ---
pal256[64:80] = [0,
    couleur(208, 216, 232),   # 1  arete eclairee
    couleur(140, 150, 178),   # 2  pierre claire
    couleur(92, 100, 130),    # 3  pierre
    couleur(52, 58, 84),      # 4  pierre sombre
    couleur(18, 20, 36),      # 5  nuit / joints
    couleur(232, 96, 88),     # 6  tapis clair
    couleur(168, 44, 52),     # 7  tapis
    couleur(100, 22, 30),     # 8  tapis sombre
    0, 0, 0, 0, 0, 0, 0]
pal256[80:96] = [0,
    couleur(255, 255, 255),   # 1  le coeur du cristal
    couleur(168, 255, 255),   # 2  cyan clair
    couleur(72, 216, 240),    # 3  cyan
    couleur(24, 132, 176),    # 4  cyan sombre
    couleur(128, 136, 160),   # 5  le socle
    couleur(64, 70, 92),      # 6  socle sombre
    0, 0, 0, 0, 0, 0, 0, 0, 0]
pal256[96:112] = [0,
    couleur(255, 232, 128),   # 1  or clair
    couleur(232, 180, 48),    # 2  or
    couleur(160, 112, 16),    # 3  or sombre
    couleur(136, 84, 40),     # 4  bois
    couleur(76, 44, 20),      # 5  bois sombre
    couleur(28, 18, 10),      # 6  l'interieur du coffre
    0, 0, 0, 0, 0, 0, 0, 0, 0]
# --- sprites : palette 0 = le heros, 1 = le curseur d'or ---
pal256[128:144] = [0,
    couleur(30, 26, 44),      # 1  contour
    couleur(255, 208, 168),   # 2  peau
    couleur(100, 64, 40),     # 3  cheveux
    couleur(112, 168, 255),   # 4  tunique claire
    couleur(52, 100, 216),    # 5  tunique
    couleur(24, 52, 128),     # 6  tunique sombre
    couleur(126, 76, 34),     # 7  bottes
    couleur(255, 255, 255),   # 8  blanc
    0, 0, 0, 0, 0, 0, 0]
pal256[144:160] = [0,
    couleur(255, 228, 104),   # 1  or clair
    couleur(208, 148, 32),    # 2  or
    couleur(120, 80, 12),     # 3  or sombre
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

assert len(pal256) == 256, f"palette CGRAM : {len(pal256)} entrees"
with open(OUT + "palettes.bin", "wb") as f:
    for c in pal256:
        f.write(struct.pack("<H", c))

# =============================================================================
#  BG1 4bpp : la salle
# =============================================================================
bg = {}
bg[0x01] = ["55555555",        # le sol : dalles de nuit, discretes
            "54555555",
            "55555555",
            "55555554",
            "55555555",
            "55455555",
            "55555555",
            "55555555"]
bg[0x02] = ["12222222",        # le mur : deux rangs de pierres decalees
            "23333334",
            "23333334",
            "55555555",
            "22212222",
            "33323333",
            "33323333",
            "55555555"]
bg[0x03] = ["77777777",        # le tapis rouge : une surface UNIE — les
            "77777777",        # tuiles se repetent bord a bord, toute
            "77877777",        # bordure par tuile se verrait en grille !
            "77777777",
            "77777787",
            "77777777",
            "78777777",
            "77777777"]
for i, t in enumerate(grille16([   # $04-$07 : LE CRISTAL sur son socle
            "................",
            ".......12.......",
            "......1122......",
            "......1223......",
            ".....112233.....",
            ".....122233.....",
            "....11222333....",
            "....12223333....",
            "....22233334....",
            ".....223334.....",
            ".....223344.....",
            "......2344......",
            ".......24.......",
            "....555555 5....".replace(" ", "5"),
            "...5566665555...",
            "..55666666665..."])):
    bg[0x04 + i] = t
for i, t in enumerate(grille16([   # $08-$0B : le coffre FERME
            "................",
            "................",
            "................",
            "..111111111111..",
            ".14444444444441.",
            ".14444444444441.",
            ".11111111111111.",
            ".14444211244441.",
            ".14444222244441.",
            ".14444211244441.",
            ".14444444444441.",
            ".15555555555551.",
            ".11111111111111.",
            "................",
            "................",
            "................"])):
    bg[0x08 + i] = t
for i, t in enumerate(grille16([   # $0C-$0F : le coffre OUVERT (vide !)
            "..111111111111..",
            ".14444444444441.",
            ".11111111111111.",
            ".16666666666661.",
            ".16666666666661.",
            ".11111111111111.",
            ".14444444444441.",
            ".14444444444441.",
            ".14444444444441.",
            ".14444444444441.",
            ".14444444444441.",
            ".15555555555551.",
            ".11111111111111.",
            "................",
            "................",
            "................"])):
    bg[0x0C + i] = t
bg[0x10] = [".122221.",        # la colonne, haut...
            ".123321.",
            ".123321.",
            ".123321.",
            ".123321.",
            ".123321.",
            ".123321.",
            ".123321."]
bg[0x11] = [".123321.",        # ...et bas
            ".123321.",
            ".123321.",
            ".123321.",
            "12233221",
            "12333321",
            "11111111",
            "55555555"]

NB_BG = 0x12
with open(OUT + "gfx_bg.bin", "wb") as f:
    for i in range(NB_BG):
        f.write(tuile_4bpp(bg.get(i, VIDE)))

# =============================================================================
#  BG3 2bpp : la police COMPLETE — un RPG parle ! A-Z = $20-$39
# =============================================================================
CHIFFRES = [
    [0x7C,0xC6,0xCE,0xD6,0xE6,0xC6,0x7C,0x00], [0x30,0x70,0x30,0x30,0x30,0x30,0xFC,0x00],
    [0x78,0xCC,0x0C,0x38,0x60,0xCC,0xFC,0x00], [0x78,0xCC,0x0C,0x38,0x0C,0xCC,0x78,0x00],
    [0x1C,0x3C,0x6C,0xCC,0xFE,0x0C,0x1E,0x00], [0xFC,0xC0,0xF8,0x0C,0x0C,0xCC,0x78,0x00],
    [0x38,0x60,0xC0,0xF8,0xCC,0xCC,0x78,0x00], [0xFC,0xCC,0x0C,0x18,0x30,0x30,0x30,0x00],
    [0x78,0xCC,0xCC,0x78,0xCC,0xCC,0x78,0x00], [0x78,0xCC,0xCC,0x7C,0x0C,0x18,0x70,0x00],
]
ALPHABET = {
    'A': [0x30,0x78,0xCC,0xCC,0xFC,0xCC,0xCC,0x00],
    'B': [0xFC,0x66,0x66,0x7C,0x66,0x66,0xFC,0x00],
    'C': [0x3C,0x66,0xC0,0xC0,0xC0,0x66,0x3C,0x00],
    'D': [0xF8,0x6C,0x66,0x66,0x66,0x6C,0xF8,0x00],
    'E': [0xFE,0x62,0x68,0x78,0x68,0x62,0xFE,0x00],
    'F': [0xFE,0x62,0x68,0x78,0x68,0x60,0xF0,0x00],
    'G': [0x3C,0x66,0xC0,0xCE,0xC6,0x66,0x3E,0x00],
    'H': [0xCC,0xCC,0xCC,0xFC,0xCC,0xCC,0xCC,0x00],
    'I': [0x78,0x30,0x30,0x30,0x30,0x30,0x78,0x00],
    'J': [0x3C,0x18,0x18,0x18,0xD8,0xD8,0x70,0x00],
    'K': [0xE6,0x66,0x6C,0x78,0x6C,0x66,0xE6,0x00],
    'L': [0xF0,0x60,0x60,0x60,0x62,0x66,0xFE,0x00],
    'M': [0xC6,0xEE,0xFE,0xD6,0xC6,0xC6,0xC6,0x00],
    'N': [0xC6,0xE6,0xF6,0xDE,0xCE,0xC6,0xC6,0x00],
    'O': [0x38,0x6C,0xC6,0xC6,0xC6,0x6C,0x38,0x00],
    'P': [0xFC,0x66,0x66,0x7C,0x60,0x60,0xF0,0x00],
    'Q': [0x78,0xCC,0xCC,0xCC,0xDC,0x78,0x1C,0x00],
    'R': [0xFC,0x66,0x66,0x7C,0x6C,0x66,0xE6,0x00],
    'S': [0x78,0xCC,0xE0,0x70,0x1C,0xCC,0x78,0x00],
    'T': [0xFC,0xB4,0x30,0x30,0x30,0x30,0x78,0x00],
    'U': [0xCC,0xCC,0xCC,0xCC,0xCC,0xCC,0x7C,0x00],
    'V': [0xCC,0xCC,0xCC,0xCC,0xCC,0x78,0x30,0x00],
    'W': [0xC6,0xC6,0xC6,0xD6,0xFE,0xEE,0xC6,0x00],
    'X': [0xC6,0x6C,0x38,0x38,0x6C,0xC6,0xC6,0x00],
    'Y': [0xCC,0xCC,0xCC,0x78,0x30,0x30,0x78,0x00],
    'Z': [0xFE,0xC6,0x8C,0x18,0x32,0x66,0xFE,0x00],
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

bg3 = {0x10 + i: glyphe(b) for i, b in enumerate(CHIFFRES)}
bg3[0x1B] = glyphe([0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00])          # tiret
for i, lettre in enumerate("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):
    bg3[0x20 + i] = glyphe(ALPHABET[lettre])

NB_BG3 = 0x3A
with open(OUT + "gfx_bg3.bin", "wb") as f:
    for i in range(NB_BG3):
        f.write(tuile_2bpp(bg3.get(i, VIDE)))

# =============================================================================
#  Sprites 4bpp : le heros, 16x16, 3 directions x 2 poses (+ le curseur)
# =============================================================================
#  La direction GAUCHE n'est pas dessinee : c'est le profil DROITE retourne
#  par le bit de miroir des attributs OAM — la lecon du retournement !
obj = {}
def heros(nom, base, rows16):
    for i, t in enumerate(grille16(rows16)):
        obj[base + i] = t

heros("bas1", 0x00, [            # face, jambes jointes
    "....33333333....",
    "...3333333333...",
    "...3322222233...",
    "....22122122....",
    "....22222222....",
    ".....222222.....",
    "....44444444....",
    "...2455555542...",
    "...2455555542...",
    "...2455555542...",
    "....45566554....",
    "....55555555....",
    "....66....66....",
    "....77....77....",
    "...777....777...",
    "................"])
heros("bas2", 0x04, [            # face, la marche
    "....33333333....",
    "...3333333333...",
    "...3322222233...",
    "....22122122....",
    "....22222222....",
    ".....222222.....",
    "....44444444....",
    "...2455555542...",
    "...2455555542...",
    "...2455555542...",
    "....45566554....",
    "....55555555....",
    "...66......66...",
    "...77......77...",
    "..777......777..",
    "................"])
heros("haut1", 0x08, [           # dos : que des cheveux !
    "....33333333....",
    "...3333333333...",
    "...3333333333...",
    "....33333333....",
    "....22222222....",
    ".....222222.....",
    "....44444444....",
    "...2455555542...",
    "...2455665542...",
    "...2455665542...",
    "....45555554....",
    "....55555555....",
    "....66....66....",
    "....77....77....",
    "...777....777...",
    "................"])
heros("haut2", 0x0C, [
    "....33333333....",
    "...3333333333...",
    "...3333333333...",
    "....33333333....",
    "....22222222....",
    ".....222222.....",
    "....44444444....",
    "...2455555542...",
    "...2455665542...",
    "...2455665542...",
    "....45555554....",
    "....55555555....",
    "...66......66...",
    "...77......77...",
    "..777......777..",
    "................"])
heros("cote1", 0x10, [           # profil DROITE (gauche = miroir OAM)
    "....33333333....",
    "...3333333333...",
    "...3333222233...",
    "....332212 2....".replace(" ", "3"),
    "....33222222....",
    ".....222222.....",
    "....44444444....",
    "....455555542...",
    "....455555542...",
    "....4555555 4...".replace(" ", "2"),
    "....45566554....",
    "....55555555....",
    ".....66..66.....",
    ".....77..77.....",
    ".....77..777....",
    "................"])
heros("cote2", 0x14, [
    "....33333333....",
    "...3333333333...",
    "...3333222233...",
    "....332212 2....".replace(" ", "3"),
    "....33222222....",
    ".....222222.....",
    "....44444444....",
    "....455555542...",
    "....4555555 4...".replace(" ", "2"),
    "....45555554....",
    "....45566554....",
    "....55555555....",
    "....66....66....",
    "...77......77...",
    "...77......777..",
    "................"])
obj[0x18] = ["12......",         # le curseur du menu : un chevron d'or
             "1122....",
             "111122..",
             "11111122",
             "111122..",
             "1122....",
             "12......",
             "........"]

NB_OBJ = 0x19
with open(OUT + "gfx_obj.bin", "wb") as f:
    for i in range(NB_OBJ):
        f.write(tuile_4bpp(obj.get(i, VIDE)))

# =============================================================================
#  Le degrade HDMA : la penombre de la salle, du noir au bleu-violet
# =============================================================================
with open(OUT + "gradient.bin", "wb") as f:
    ETAPES = 28
    for i in range(ETAPES):
        t = i / (ETAPES - 1)
        r = int(6 + 14 * t * t)
        g = int(4 + 8 * t * t)
        b = int(14 + 34 * t * t)
        f.write(bytes([8, 0, 0]) + struct.pack("<H", couleur(r, g, b)))
    f.write(bytes([0]))

print("cristal: gfx_bg / gfx_bg3 / gfx_obj / palettes / gradient generes")
