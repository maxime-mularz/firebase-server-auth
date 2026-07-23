---
description: Audit de synchronisation entre documents narratifs, données et code
---

Tu es le Technical Director. Audite la synchronisation documents ↔
données ↔ code. Périmètre : $ARGUMENTS (défaut : tout).

Compare : documents narratifs (docs/narrative/**), données de dialogues,
scripts de scènes, drapeaux, objets, personnages, quêtes, cartes,
fichiers audio référencés — contre le code et les données compilées
(cristal-2026/, banques, tests/).

Détecte et rapporte :
- références cassées (ID cités nulle part définis) ;
- scènes documentées `approved` mais non implémentées (écart planning) ;
- scènes implémentées mais absentes de la documentation ;
- drapeaux incohérents (requis jamais posés, posés jamais lus,
  divergences doc/code) ;
- dialogues orphelins (fichier dialogue sans scène, ou l'inverse) ;
- noms divergents (même entité, IDs différents) ;
- contenus `deprecated` encore référencés.

Méthode :
1. lance `python3 tools/validate_content.py` (la base statique) ;
2. complète par grep croisé des ID (`FLAG_`, `CHAR_`, `SCENE_`,
   `ITEM_`, `MAP_`, `MUSIC_`) dans docs/, cristal-2026/src/, tests/ ;
3. classe chaque trouvaille : [BLOCKER] / incohérence / dette ;
4. produis un rapport daté dans `docs/reviews/technical/`
   (id `REVIEW_AUDIT_<AAAAMMJJ>`), avec pour chaque point : preuve,
   impact, proposition. Ne corrige rien silencieusement — les
   corrections se font en PR référencées par le rapport.
