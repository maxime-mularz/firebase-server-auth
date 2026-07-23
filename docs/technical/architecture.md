---
id: TECH_ARCHI
title: Architecture technique
type: technical
status: draft
owner: technical
reviewers: [creative]
version: 0.1
last_updated: 2026-07-23
implementation_status: implemented
related_issues: []
related_files: []
---

# Architecture technique (état réel)

## Le dépôt

```text
casse-brique-nes/  neo-runner-2026/  nova-2026/    — le cours NES (6502)
casse-brique-snes/ neo-runner-snes/  nova-snes/    — les portages SNES (65816)
snes-commun/son.s                                  — pilote SPC700 partagé
cristal-2026/                                      — LA FONDATION DU RPG (phase 1)
tests/                                             — simulateurs + batteries de tests
tools/validate_content.py                          — validateur de contenu narratif
docs/                                              — la mémoire du projet
```

## La fondation RPG (cristal-2026)

- **CPU** : 65816, mode natif ; logique 8 bits + sections 16 bits
  (`rep #$20`/`rep #$10`) pour compteurs et parcours de données.
- **Cartouche** : LoROM 256 Ko, 8 banques. Code en banque 0 ;
  données en banque $81 ; **banques $82-$87 libres** (~192 Ko) réservées
  au contenu narratif compilé.
- **SRAM** : 8 Ko à pile, bloc de sauvegarde versionné avec signature et
  somme de contrôle (technical/save_system.md).
- **Vidéo** : Mode 1 — BG1 = monde, BG3 prioritaire = texte/HUD,
  sprites 4bpp ; HDMA pour les ambiances.
- **Audio** : SPC700, pilote de 115 octets téléversé au boot
  (snes-commun/son.s) : 4 voix (mélodie, basse, effets, bruit).
- **Outillage** : ca65/ld65 (cc65), ateliers graphiques Python
  (pixel-art texte → binaires .incbin), somme de contrôle d'en-tête.

## La chaîne de vérification

Simulateur 65816+PPU+APU maison (`tests/sim_snes.py`) : exécute les ROM,
rend des captures, co-simule le SPC700 (le blob téléversé est réellement
interprété), simule les cycles d'alimentation pour la SRAM. Chaque jeu a
sa batterie (`tests/smoke_*.py`).

## Principes

1. Le code ne connaît pas le contenu : il lit des tables (vagues de
   NOVA, plans de salles) — le RPG généralise ce principe.
2. Une capacité moteur = une leçon documentée dans le code (le dépôt
   reste un cours).
3. Tout ce qui entre dans une banque de contenu est GÉNÉRÉ par un outil
   versionné, jamais écrit à la main en hexadécimal.
