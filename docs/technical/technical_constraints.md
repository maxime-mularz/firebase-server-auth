---
id: TECH_CONTRAINTES
title: Contraintes techniques
type: technical
status: draft
owner: technical
reviewers: [narrative]
version: 0.1
last_updated: 2026-07-23
implementation_status: implemented
related_issues: []
related_files: []
---

# Contraintes techniques (budget courant)

Chiffres RÉELS de la fondation actuelle — à faire évoluer par ADR.

| Ressource | Budget | Utilisé (phase 1) | Marge |
|---|---|---|---|
| ROM | 256 Ko (8 banques) | 2 banques | 6 banques (~192 Ko) |
| RAM travail | 8 Ko exploités | ~1,5 Ko (ZP+OAM+piles) | large |
| SRAM | 8 Ko | 16 octets | 8176 octets |
| VRAM | 64 Ko | ~40 Ko (tuiles+cartes+sprites) | ~24 Ko |
| Voix audio | 8 (DSP) | 4 (pilote actuel) | 4 (pilote v2 à écrire) |
| Sprites | 128 (34/ligne) | 5 | large |
| VBlank | ~4,5 Ko de transferts/img | OAM (544 o) + files | confortable |

## Limites structurantes pour la narration
- texte : MAJUSCULES sans accents (voir localization.md) ;
- ~28 caractères × 3-4 lignes par fenêtre de dialogue ;
- une « scène » ne peut pas charger plus d'une carte + un jeu de
  sprites sans transition (écran noir ou fondu) ;
- extension possible de la cartouche jusqu'à 4 Mo si le périmètre
  l'exige (ADR requis).
