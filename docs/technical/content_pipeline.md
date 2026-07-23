---
id: TECH_PIPELINE
title: Pipeline de contenu
type: technical
status: draft
owner: technical
reviewers: [narrative, creative]
version: 0.1
last_updated: 2026-07-23
implementation_status: planned
related_issues: []
related_files: []
---

# Le pipeline de contenu

## Le trajet d'un contenu

```text
Document narratif (docs/narrative/, Markdown + YAML)
→ validation narrative (Narrative Director)
→ review technique (/review-scene → docs/reviews/technical/)
→ validation créative (Maxime : status approved)
→ données structurées (YAML extrait : scenes/, dialogues/)
→ compilation (tools/*.py → .s/.bin dans les banques $82+)
→ implémentation (/implement-scene)
→ tests (tests/smoke_*.py)
→ playtest (docs/reviews/playtests/)
→ review → réécriture éventuelle
```

## Le format retenu : Markdown + YAML → générateurs Python

**Pourquoi** : le dépôt transforme DÉJÀ du texte en binaires par des
outils Python (`tools/make_gfx.py` de chaque jeu : pixel-art texte →
4bpp). On prolonge ce geste : les documents restent lisibles par les
humains (Markdown), les champs machine vivent dans le front matter YAML,
et des générateurs Python (à écrire en phases 2-3) compilent vers des
tables ca65 (`.byte`/`.incbin`) placées dans les banques de données.
On ne crée PAS de second système : c'est le même pattern généralisé.

## Convention d'identifiants stables

Les identifiants ne dépendent JAMAIS du texte affiché au joueur.

```text
CHAR_ALDEMAR_HERO      CHAR_PROF_ORION          — personnages
CHAPTER_01             SCENE_CH01_001            — chapitres et scènes
QUEST_MAIN_001         QUEST_SIDE_001            — quêtes
ITEM_MEMORY_SHARD_01   SPELL_ECHO_01             — objets et sorts
FLAG_CH01_LIBRARY_OPEN                           — drapeaux (préfixe chapitre)
DIALOGUE_SCENE_CH01_001_001                      — répliques
MAP_ACADEMY_HALL       MUSIC_ALDEMAR_THEME       — cartes et musiques
```

Règles :
- MAJUSCULES_SOUS_TIRETS, ASCII pur (les symboles ca65 en dérivent
  directement) ;
- un identifiant n'est jamais réutilisé — un contenu supprimé passe en
  `deprecated`, son ID est retiré de la circulation ;
- côté assembleur, l'ID devient le symbole (les drapeaux deviendront des
  index de bits générés : `FLAG_CH01_LIBRARY_OPEN = n`).

## Validation automatique

`python3 tools/validate_content.py` (ou `make validate-content`) contrôle :
identifiants dupliqués, champs obligatoires, statuts valides, scènes sans
chapitre / chapitres sans scènes, personnages référencés mais non
déclarés, drapeaux requis jamais posés, objets requis jamais accordés,
`related_files` inexistants. Sortie non vide + code retour ≠ 0 = CI rouge.
