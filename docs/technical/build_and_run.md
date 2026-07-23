---
id: TECH_BUILD
title: Compiler et lancer
type: technical
status: approved
owner: technical
reviewers: []
version: 0.1
last_updated: 2026-07-23
implementation_status: implemented
related_issues: []
related_files: []
---

# Compiler, lancer, tester (commandes vérifiées)

## Prérequis
- `cc65` (fournit ca65/ld65) — sur Mac : `brew install cc65`
- Python 3 avec Pillow (tests/captures), py65 (tests NES), PyYAML (validateur)
- Émulateur : Mesen2 (recommandé), Snes9x ou bsnes

## Construire

```bash
make -C cristal-2026          # → cristal-2026/cristal.sfc
make roms                     # depuis la racine : les 6 jeux + le RPG
```

## Tester

```bash
make test-snes                # les 4 batteries SNES (simulateur maison)
python3 tests/smoke_cristal.py   # la fondation RPG seule
```

## Valider le contenu narratif

```bash
make validate-content         # = python3 tools/validate_content.py
```

## Jouer
Ouvrir le `.sfc` dans Mesen2. La sauvegarde SRAM devient un fichier
`.srm` à côté de la ROM (l'émulateur joue le rôle de la pile).
