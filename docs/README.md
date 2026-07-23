# 📚 Académie d'Aldemar — le centre de documentation

Ce dossier est la **mémoire centrale** du projet et l'espace de
communication entre les trois rôles. Le code décrit l'implémentation ;
ces documents décrivent l'intention. Les deux doivent rester synchronisés.

> **Personne ne gagne une discussion. Seul le jeu gagne.**

## Les rôles

| Rôle | Tenu par | Possède |
|---|---|---|
| Creative Director | **Maxime** | la vision, les arbitrages, le périmètre final |
| Narrative Director | **ChatGPT** | la bible narrative, le scénario, les personnages, les quêtes, les dialogues |
| Technical Director | **Claude Code** | l'architecture, le code, les outils, les estimations de faisabilité |

Le détail des responsabilités : [.claude/roles.md](../.claude/roles.md).
Le workflow de validation : [.claude/workflow.md](../.claude/workflow.md).

## L'arborescence

```text
docs/
├── vision/       la vision créative et les piliers (validés par Maxime)
├── narrative/    la bible, les chapitres, scènes, personnages, quêtes, dialogues
├── gameplay/     les systèmes de jeu et le contrat narration-gameplay
├── technical/    l'architecture, les contraintes SNES, le pipeline de contenu
├── reviews/      les critiques structurées (personne ne modifie le document d'un autre)
├── decisions/    les ADR — les décisions validées, archivées
└── templates/    les modèles de documents
```

## Les statuts documentaires

Chaque document narratif important commence par un en-tête YAML :

```yaml
---
id: CHAPTER_01
title: Le premier jour
type: chapter
status: draft
owner: narrative
reviewers: [technical, creative]
version: 0.1
last_updated: 2026-07-23
implementation_status: not_started
related_issues: []
related_files: []
---
```

Valeurs de `status` : `idea`, `draft`, `narrative_review`,
`technical_review`, `creative_review`, `approved`, `deprecated`.

Valeurs de `implementation_status` : `not_started`, `planned`,
`in_progress`, `implemented`, `tested`, `blocked`.

Règle d'or : **rien ne s'implémente avant `status: approved`** — et une
décision n'est définitive que marquée `Accepté` dans `docs/decisions/`.

## Les tags de collaboration

À utiliser dans les documents, reviews et issues :

| Tag | Usage |
|---|---|
| `[NARRATIVE]` | remarque sur le sens, l'histoire, un personnage |
| `[GAMEPLAY]` | remarque sur les systèmes, le rythme d'interaction |
| `[TECHNICAL]` | contrainte ou opportunité technique |
| `[EMOTION]` | l'effet recherché sur le joueur |
| `[FORESHADOWING]` | indice planté pour plus tard — ne pas expliquer avant l'heure |
| `[BLOCKER]` | rien ne peut avancer tant que ce point n'est pas résolu |
| `[QUESTION]` | question ouverte, sans urgence |
| `[DECISION_REQUIRED]` | le Creative Director doit trancher |
| `[IMPLEMENTATION_NOTE]` | écart ou précision d'implémentation |
| `[PLAYTEST]` | observation issue d'une session de test |

Exemples :

```markdown
[EMOTION]
Le joueur doit ressentir un malaise progressif, pas une peur immédiate.

[FORESHADOWING]
Le portrait sans visage prépare une révélation du chapitre 8.
Ne pas expliquer cet élément avant cette révélation.

[TECHNICAL]
La scène demande un changement de palette progressif (faisable par HDMA
ou par fondu CGRAM — voir docs/technical/snes_constraints.md).

[DECISION_REQUIRED]
Le joueur peut-il quitter la salle avant la fin du dialogue ?
```

## Valider le contenu

```bash
python3 tools/validate_content.py     # ou : make validate-content
```

Le validateur contrôle identifiants, champs obligatoires, références
croisées (personnages, chapitres, drapeaux, objets) et statuts. Il doit
être VERT avant tout commit touchant `docs/narrative/`.
