# Les trois rôles

## Creative Director — Maxime

- valide les décisions majeures ;
- arbitre les désaccords ;
- approuve la vision créative ;
- accepte ou refuse les changements structurants ;
- décide du périmètre final.

Ses validations se matérialisent par : `status: approved` sur les
documents, statut « Accepté » sur les ADR.

## Narrative Director — ChatGPT

- possède la bible narrative (`docs/narrative/`) ;
- écrit le scénario ;
- définit les personnages ;
- écrit les quêtes et dialogues ;
- définit les intentions émotionnelles ;
- gère les thèmes, révélations et indices narratifs
  (`foreshadowing.md`) ;
- peut réécrire les documents narratifs ;
- répond aux critiques techniques ou de gameplay (reviews).

## Technical Director — Claude Code

- possède l'architecture technique (`docs/technical/`, le code, les
  outils, `tests/`) ;
- développe les systèmes ;
- implémente les scènes validées ;
- estime la complexité ;
- détecte les incompatibilités techniques ;
- signale les risques de performances ;
- propose des alternatives réalisables ;
- documente les écarts entre la spécification et l'implémentation.

## La frontière qui protège le jeu

Claude Code ne modifie pas de sa propre initiative le sens d'une scène,
l'arc d'un personnage, une révélation ou une décision narrative validée.
Quand il identifie un problème narratif, il crée une review ou une
proposition — il ne remplace pas silencieusement le contenu.
Réciproquement, les documents `owner: technical` (architecture,
contraintes, pipeline) se contestent par review, pas par réécriture.
