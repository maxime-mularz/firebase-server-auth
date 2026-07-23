---
id: TERMINOLOGIE
title: Terminologie
type: lore
status: draft
owner: narrative
reviewers: [technical]
version: 0.1
last_updated: 2026-07-23
implementation_status: not_started
related_issues: []
related_files: []
---

# Terminologie

Le glossaire du monde : chaque terme inventé, sa définition, son usage.
Le validateur et le code utilisent les IDENTIFIANTS, jamais les noms
affichés — on peut donc renommer un terme sans casser le jeu
(convention : [technical/content_pipeline.md](../technical/content_pipeline.md)).

| Terme affiché | Identifiant | Définition | Premier usage |
|---|---|---|---|
| _(EXEMPLE)_ Éclat de mémoire | ITEM_MEMORY_SHARD_01 | _exemple de ligne, à remplacer_ | — |

## Règles

- Un terme = une seule graphie (le validateur ne l'impose pas, les
  relecteurs oui).
- **Contrainte technique actuelle** : la police du moteur couvre A-Z,
  0-9, le tiret et l'espace — PAS d'accents ni de minuscules pour
  l'instant. Voir [technical/localization.md](../technical/localization.md)
  et la [DECISION_REQUIRED] associée dans open_questions.md.
