---
id: TECH_LOCALISATION
title: Localisation
type: technical
status: draft
owner: technical
reviewers: [narrative]
version: 0.1
last_updated: 2026-07-23
implementation_status: planned
related_issues: []
related_files: []
---

# Localisation et jeu de caractères

## État réel
- Langue unique : **français**.
- Police 2bpp : MAJUSCULES A-Z, chiffres, tiret, espace. Ni accents, ni
  minuscules, ni ponctuation riche. Conversion par `.charmap` à
  l'assemblage (voir cristal-2026, avec son piège documenté).

## Décision en attente ([DECISION_REQUIRED] — open_questions.md)
Ajouter accents + minuscules (~90 tuiles 2bpp, place disponible en VRAM
et en banque) AVANT l'écriture de masse des dialogues, ou assumer le
style plein-écran MAJUSCULES d'époque. Le coût de conversion tardive des
textes est le vrai risque : trancher tôt.

## Principe pour la suite
Les textes vivent dans les documents/donnees, JAMAIS dans le code : une
traduction future = nouvelles banques de textes, zéro code modifié.
