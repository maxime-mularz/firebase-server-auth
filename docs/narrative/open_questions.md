---
id: QUESTIONS_OUVERTES
title: Questions ouvertes
type: registry
status: draft
owner: narrative
reviewers: [creative, technical]
version: 0.1
last_updated: 2026-07-23
implementation_status: not_started
related_issues: []
related_files: []
---

# Questions ouvertes

Les questions sans réponse, datées et signées. Quand une question est
tranchée : ADR dans `docs/decisions/` et suppression ici.

## En attente de décision (Maxime)

[DECISION_REQUIRED] — **Accents et minuscules.** La police actuelle est
en majuscules non accentuées (héritée du cours). Un JRPG français
respire mieux avec accents et minuscules ; coût estimé : ~90 tuiles 2bpp
supplémentaires (place disponible) + table .charmap étendue. Trancher
avant l'écriture massive de dialogues. _Posée par : technique, 2026-07-23._

[DECISION_REQUIRED] — **Périmètre.** Durée de jeu cible et nombre de
chapitres — nécessaire pour dimensionner les banques (6 banques de
32 Ko libres aujourd'hui, extension possible à 4 Mo). _Posée par :
technique, 2026-07-23._

## En attente du Narrative Director

[QUESTION] — Le héros a-t-il un nom fixe ou choisi par le joueur ?
(Impact technique : saisie de nom = clavier à l'écran + 8 octets de
SRAM ; faisable, à planifier.) _Posée par : technique, 2026-07-23._

[QUESTION] — CRISTAL-2026 (la fondation technique) met en scène un
cristal qui SAUVEGARDE. Les points de sauvegarde ont-ils une existence
diégétique dans l'univers d'Aldemar (liés à la mémoire ?) ou
restent-ils un mécanisme abstrait ? _Posée par : technique, 2026-07-23._
