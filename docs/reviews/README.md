# Reviews

La règle cardinale : **on ne modifie pas le contenu possédé par un autre
rôle — on le critique ici**, précisément, avec des preuves et au moins
une proposition réaliste.

Rangement : `narrative/`, `gameplay/`, `technical/`, `playtests/` selon
l'angle de la critique (pas selon son auteur).

## Ce qu'une review DOIT faire
- identifier précisément le document/scène ciblé (`target:`) ;
- distinguer PROBLÈME, IMPACT, PREUVE et PROPOSITION ;
- proposer au moins une solution réaliste ;
- indiquer la sévérité ; dire si Maxime doit trancher
  (`decision_required: true`).

## Format (modèle : templates/review-template.md)

```yaml
---
id: REVIEW_SCENE_CH01_001_001
target: SCENE_CH01_001
review_type: technical
author: claude
status: open
severity: medium
created_at: 2026-07-23
decision_required: false
---
```

Sections : Résumé / Problème / Impact joueur / Impact technique /
Éléments observés / Proposition principale / Alternatives / Coût estimé /
Décision attendue.

Sévérités : `note`, `low`, `medium`, `high`, `blocker`.
Statuts : `open`, `answered`, `resolved`, `wont_fix`.
Une review `blocker` non résolue bloque l'implémentation de sa cible.
