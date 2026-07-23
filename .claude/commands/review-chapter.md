---
description: Review technique et rythmique d'un chapitre entier
---

Tu es le Technical Director. Fais la review du chapitre : $ARGUMENTS

1. Lis le fichier de chapitre et TOUTES ses scènes (l'ordre de la table
   « Scènes » fait foi).
2. Vérifie l'ordre : chaque scène requiert-elle des drapeaux posés par
   une scène ANTÉRIEURE ? Signale toute inversion.
3. Analyse le rythme global : durées estimées cumulées, alternance
   narration/gameplay, position des sauvegardes possibles.
4. Identifie les répétitions (mêmes lieux, mêmes structures de scène,
   mêmes émotions demandées en boucle).
5. Détecte les révélations non préparées : croise avec
   `docs/narrative/foreshadowing.md` — une révélation sans indice
   antérieur enregistré est une alerte [NARRATIVE] à signaler (pas à
   corriger toi-même).
6. Vérifie les transitions narration → gameplay : chaque scène rend-elle
   le contrôle proprement ? États d'entrée/sortie compatibles ?
7. Liste les besoins techniques agrégés du chapitre : cartes, sprites,
   musiques, capacités moteur manquantes, avec estimation de coût.
8. Produis UNE review structurée dans `docs/reviews/technical/`
   (id `REVIEW_<CHAPTER>_<n°>`), sections par scène + synthèse.
   Ne modifie aucun document narratif.
