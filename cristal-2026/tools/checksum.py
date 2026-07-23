#!/usr/bin/env python3
"""Somme de contrôle de l'en-tête SNES — version multi-banques.

L'algorithme ne change pas avec la taille : champs neutralisés
(complément = $FFFF, somme = $0000), somme de TOUS les octets du fichier,
puis on écrit somme et complément à $7FDC-$7FDF (le haut de la banque 0).
"""
import sys

p = sys.argv[1]
data = bytearray(open(p, 'rb').read())
assert len(data) % 0x8000 == 0, "la ROM doit faire un multiple de 32 Ko"
data[0x7FDC:0x7FE0] = b'\xFF\xFF\x00\x00'
s = sum(data) & 0xFFFF
data[0x7FDC] = (s ^ 0xFFFF) & 0xFF
data[0x7FDD] = (s ^ 0xFFFF) >> 8
data[0x7FDE] = s & 0xFF
data[0x7FDF] = s >> 8
open(p, 'wb').write(data)
print(f"checksum: {s:04X} ({len(data)//1024} Ko)")
