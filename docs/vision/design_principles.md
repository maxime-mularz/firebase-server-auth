---
id: VISION_DESIGN
title: Principes de design
type: vision
status: draft
owner: creative
reviewers: [narrative, technical]
version: 0.1
last_updated: 2026-07-23
implementation_status: not_started
related_issues: []
related_files: []
---

# Principes de design

Comment on décide, au quotidien, quand narration, gameplay et technique
se contredisent.

## Principes proposés (à valider par le Creative Director)

1. **Le rythme d'interaction prime** : jamais plus de ~40 secondes sans
   que le joueur ait un contrôle réel (à calibrer en playtest).
2. **Piloté par les données** : le code ne connaît aucune scène — il les
   lit. Ajouter du contenu = ajouter des données, pas du code (héritage
   direct des vagues de NOVA et des niveaux du casse-brique).
3. **La contrainte est un pinceau** : nombre de couleurs, taille des
   fenêtres, 4 voix audio — les scènes s'écrivent AVEC ces limites
   (voir [technical/snes_constraints.md](../technical/snes_constraints.md)).
4. **Tout état visible du monde est sauvegardable** : si le joueur peut
   le changer, la SRAM doit pouvoir s'en souvenir.
5. **Le dépôt reste un cours** : le code continue d'expliquer ce qu'il
   fait — lisibilité pédagogique non négociable.

## À compléter
_Autres principes, hiérarchie en cas de conflit._
