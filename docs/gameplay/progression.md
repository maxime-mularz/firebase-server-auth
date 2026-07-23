---
id: GP_PROGRESSION
title: Progression
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

# Progression

_À définir._ Points à trancher :

- niveaux classiques, ou progression par SOUVENIRS/sorts retrouvés
  (plus proche des thèmes) ? [DECISION_REQUIRED]
- courbe de puissance sur la durée cible ;
- ce qui est perdu/conservé entre chapitres.

## Contrainte technique posée d'avance
Les statistiques vivront en 16 bits (fondation prête). La sauvegarde
actuelle fait 16 octets — chaque ajout à l'état persistant passe par le
format de sauvegarde versionné (voir technical/save_system.md).
