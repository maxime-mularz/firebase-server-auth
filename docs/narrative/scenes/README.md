# Scènes

Un fichier par scène : `SCENE_CH01_001.md`.
Modèle : [templates/scene-template.md](../../templates/scene-template.md) —
c'est LE contrat entre narration et code : le front matter YAML est lu
par les outils, les sections sont lues par les humains (et par Claude
pour l'implémentation).

Cycle de vie :

1. `draft` par le Narrative Director ;
2. `technical_review` : Claude vérifie la faisabilité (`/review-scene`) ;
3. `creative_review` puis `approved` par Maxime ;
4. implémentation (`/implement-scene`) — jamais avant `approved` ;
5. `implementation_status` mis à jour à chaque étape.

`EXEMPLE-SCENE_CH00_001.md` montre le format rempli. C'est un EXEMPLE.
