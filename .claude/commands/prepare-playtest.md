---
description: Générer une fiche de playtest prête à l'emploi
---

Tu es le Technical Director. Prépare une fiche de playtest pour :
$ARGUMENTS (chapitre, scènes ou build).

1. Pars du modèle `docs/templates/playtest-template.md` ; crée le
   fichier dans `docs/reviews/playtests/` (id `PLAYTEST_<n°>`).
2. Remplis avec des données RÉELLES du dépôt :
   - objectif du test : l'hypothèse la plus risquée du contenu ciblé
     (cherche les [EMOTION] et [QUESTION] des scènes couvertes) ;
   - durée cible : somme des `estimated_duration_seconds` + marge ;
   - profil des testeurs ;
   - scènes couvertes (IDs) et leur `implementation_status` réel ;
   - hypothèses testées, mesurables ;
   - questions ouvertes reprises de open_questions.md si pertinentes ;
   - métriques collectables sans télémétrie (observation, chrono) ;
   - bugs connus : état des batteries de tests + issues ouvertes ;
   - éléments à NE PAS révéler : depuis foreshadowing.md — liste les
     IDs SANS recopier les explications ;
   - questionnaire post-session (émotions ressenties AVANT questions
     factuelles, jamais de question orientée).
3. Vérifie que le build référencé compile (`make roms`) et note le
   commit exact dans le champ `build`.
