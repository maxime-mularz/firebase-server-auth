---
id: STYLE_DIALOGUES
title: Style des dialogues
type: style
status: idea
owner: narrative
reviewers: [creative, technical]
version: 0.1
last_updated: 2026-07-23
implementation_status: not_started
related_issues: []
related_files: []
---

# Style des dialogues

**Propriété du Narrative Director** pour le ton ; les contraintes de
forme, elles, viennent du matériel.

## Le ton (à définir par le Narrative Director)
_À écrire : niveau de langue, tutoiement/vouvoiement, longueur type des
répliques, place de l'humour (pilier n°8), tics de langage par
personnage._

## Les contraintes de forme (réelles, mesurées sur le moteur actuel)

- L'écran fait **32 colonnes** de tuiles ; une fenêtre de dialogue
  praticable offre **~28 caractères par ligne** et 3 à 4 lignes.
- La police actuelle : MAJUSCULES A-Z, chiffres, tiret, espace.
  Pas encore d'accents, de minuscules ni de ponctuation riche
  ([DECISION_REQUIRED] — voir open_questions.md).
- Pas de voix, pas d'italique : l'émotion passe par le rythme, les
  pauses (défilement lettre à lettre, phase 3) et la mise en scène.
- Le moteur de texte est le chantier de la **phase 3** — les dialogues
  écrits avant doivent respecter ces limites pour éviter les réécritures.

## Format d'écriture

Les dialogues se rédigent dans les fichiers de scènes (section
« Dialogues ») puis, une fois la scène `approved`, sont extraits vers le
format structuré du pipeline (voir
[technical/content_pipeline.md](../technical/content_pipeline.md)).
