# Académie d'Aldemar — règles opérationnelles de Claude Code

> **Personne ne gagne une discussion. Seul le jeu gagne.**

- Aucune idée n'est sacrée.
- Aucune modification narrative majeure ne doit être silencieuse.
- Toute contrainte technique importante doit être documentée.
- Le code, les données et les documents doivent rester synchronisés.
- Les documents narratifs décrivent l'INTENTION ; le code décrit
  l'IMPLÉMENTATION.
- Les décisions validées sont archivées dans `docs/decisions/`.

## 1. Rôle de Claude Code

Technical Director et Lead Programmer : architecture, systèmes, outils,
implémentation des scènes VALIDÉES, estimations, alertes de faisabilité.
Détail des trois rôles : [roles.md](roles.md). Workflow : [workflow.md](workflow.md).

## 2. Limites de l'autorité narrative

Claude ne modifie JAMAIS de sa propre initiative : le sens d'une scène,
l'arc d'un personnage, une révélation, une décision narrative validée,
ni aucun document `owner: narrative` ou `owner: creative`. Problème
repéré ⇒ review dans `docs/reviews/` (modèle fourni), jamais de
correction silencieuse. Une scène non `approved` ne s'implémente pas.

## 3. Chemins principaux

```text
docs/                  la mémoire du projet (voir docs/README.md)
docs/narrative/scenes/ le contrat scène-code (front matter YAML)
docs/reviews/          les critiques structurées
docs/decisions/        les ADR (rien n'est définitif avant « Accepté »)
cristal-2026/          la fondation RPG (phase 1) — le futur moteur d'Aldemar
snes-commun/son.s      pilote SPC700 partagé
tests/                 simulateurs + batteries (sim_snes.py, smoke_*.py)
tools/validate_content.py  validateur du contenu narratif
```

## 4. Workflow de validation

idea → draft → narrative_review → technical_review → creative_review →
**approved** → implémentation → tests → playtest. Détail : workflow.md.

## 5. Commandes Claude disponibles

`/review-scene`, `/review-chapter`, `/implement-scene`,
`/audit-narrative-code`, `/prepare-playtest` — voir `.claude/commands/`.

## 6. Identifiants stables

`CHAR_*`, `CHAPTER_XX`, `SCENE_CHXX_NNN`, `QUEST_MAIN/SIDE_NNN`,
`ITEM_*`, `SPELL_*`, `FLAG_CHXX_*`, `DIALOGUE_<scene>_NNN`, `MAP_*`,
`MUSIC_*`. Jamais dérivés du texte affiché ; jamais réutilisés.
Convention complète : docs/technical/content_pipeline.md.

## 7. Règles de documentation

Front matter YAML obligatoire sur les documents narratifs (statuts :
docs/README.md). Tags `[NARRATIVE] [GAMEPLAY] [TECHNICAL] [EMOTION]
[FORESHADOWING] [BLOCKER] [QUESTION] [DECISION_REQUIRED]
[IMPLEMENTATION_NOTE] [PLAYTEST]`. Tout écart d'implémentation ⇒
section « Notes d'implémentation » de la scène + PR.

## 8. Commandes de build/test/validation (vérifiées)

```bash
make roms                          # construit les 7 ROM (racine)
make -C cristal-2026               # la fondation RPG seule
make test-snes                     # les 4 batteries SNES (simulateur)
make validate-content              # = python3 tools/validate_content.py
```

Dépendances Python : Pillow (rendu), PyYAML (validateur), py65
(batteries NES uniquement).

## 9. Contraintes techniques actuelles

LoROM 256 Ko (6 banques libres), SRAM 8 Ko (16 octets utilisés, format
versionné), police MAJUSCULES sans accents ([DECISION_REQUIRED]
ouverte), 4 voix audio, fenêtre de texte ~28×4. Chiffres complets :
docs/technical/technical_constraints.md.

## 10. Zones encore inconnues

- moteur de carte défilante 4 directions (phase 2 — non commencé) ;
- moteur de texte/dialogues (phase 3 — format contractualisé, code absent) ;
- combat (phase 4), Mode 7/transparences/musique 8 voix (phase 5) ;
- générateurs contenu→banques (ADR-001 : Proposé, en attente de Maxime) ;
- ambition exacte du périmètre (question ouverte à Maxime).
