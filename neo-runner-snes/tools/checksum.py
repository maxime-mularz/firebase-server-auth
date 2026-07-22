#!/usr/bin/env python3
"""Recalcule les sommes de controle de l'en-tete de cartouche SNES."""
import sys
p = sys.argv[1]
d = bytearray(open(p, 'rb').read())
o = 0x7FDC                       # $FFDC dans une LoROM de 32 Ko
d[o:o+4] = b'\xFF\xFF\x00\x00'
s = sum(d) & 0xFFFF
d[o+2] = s & 0xFF
d[o+3] = s >> 8
d[o] = (s ^ 0xFFFF) & 0xFF
d[o+1] = (s ^ 0xFFFF) >> 8
open(p, 'wb').write(d)
print(f"checksum: {s:04X}")
