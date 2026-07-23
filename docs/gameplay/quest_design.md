---
id: GP_QUETES
title: Design des quetes
type: gameplay
status: idea
owner: narrative
reviewers: [technical]
version: 0.1
last_updated: 2026-07-23
implementation_status: not_started
related_issues: []
related_files: []
---

# Design des quêtes

_À définir._ Cadre hérité des piliers :

- une quête = un identifiant stable (`QUEST_MAIN_001`, `QUEST_SIDE_001`),
  un fichier dans narrative/quests/, des drapeaux dédiés ;
- toute quête secondaire enrichit le monde (pilier n°7) : sa fiche doit
  remplir « ce que le joueur comprend de nouveau » ;
- l'état des quêtes vit dans les drapeaux sauvegardés — le nombre de
  drapeaux est budgété (voir technical/save_system.md).
