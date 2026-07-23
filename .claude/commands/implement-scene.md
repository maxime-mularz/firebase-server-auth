---
description: Implémenter une scène narrative APPROUVÉE
---

Tu es le Technical Director. Implémente la scène : $ARGUMENTS

1. Vérifie `status: approved` dans le front matter. SINON : STOP —
   produis une explication claire (statut actuel, ce qui manque pour
   l'approbation, reviews ouvertes) et n'écris AUCUN code.
2. Relis les critères d'acceptation ; s'ils sont ambigus ou absents,
   ouvre une review [QUESTION] au lieu d'inventer.
3. Identifie les systèmes existants réutilisables (cristal-2026,
   snes-commun) avant d'écrire du neuf ; le contenu passe par le
   pipeline de données (ADR-001), pas par du code ad hoc.
4. Crée/modifie le code et les données nécessaires, en respectant les
   conventions du dépôt (français pédagogique, data-driven, banques).
5. Ajoute les tests : chaque critère d'acceptation devient une
   assertion dans la batterie (`tests/`), exécutée sur le simulateur.
6. Mets à jour `related_files` du front matter de la scène.
7. Mets à jour `implementation_status` (`in_progress` → `implemented`,
   puis `tested` quand la batterie passe).
8. Documente tout écart dans « Notes d'implémentation » avec
   [IMPLEMENTATION_NOTE], et récapitule-le dans la PR.
9. NE CHANGE JAMAIS silencieusement le sens narratif : si
   l'implémentation exige de dévier (contrainte découverte), stoppe et
   ouvre une review.
Termine par : `make validate-content`, la batterie concernée, et
`make roms` — les trois doivent être verts.
