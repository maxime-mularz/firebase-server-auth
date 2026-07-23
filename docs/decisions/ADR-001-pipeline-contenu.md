# ADR-001 — Contenu narratif en Markdown+YAML compilé par générateurs Python

## Statut

Proposé

## Contexte

Le dépôt transforme déjà du texte en binaires par des outils Python
versionnés (ateliers make_gfx.py : pixel-art texte → 4bpp/2bpp .incbin).
Le RPG doit transporter scènes, dialogues, quêtes vers les banques ROM.

## Problème

Choisir UN format source pour le contenu narratif, lisible par le
Narrative Director, validable automatiquement, compilable vers ca65.

## Options étudiées

1. Markdown + front matter YAML, compilé par Python (choisi) ;
2. JSON pur (précis mais illisible pour l'écriture) ;
3. CSV (adapté aux tables, pas aux scènes) ;
4. scripts .s écrits à la main (celui qu'on refuse : contenu = données).

## Décision

Option 1 : documents dans docs/narrative/ (humains), extraction YAML à
l'approbation, générateurs Python → tables ca65 dans les banques $82+.

## Raisons

Prolonge le pattern existant du dépôt ; zéro dépendance nouvelle
(PyYAML présent) ; diff Git lisibles ; le validateur travaille sur la
même source que les humains.

## Conséquences

Écrire les générateurs en phases 2-3 ; le validateur (déjà livré) est le
gardien du format.

## Impact narratif

Le Narrative Director écrit en Markdown, sans toucher à l'assembleur.

## Impact gameplay

Les drapeaux/objets déclarés dans les scènes deviennent la source de
vérité du moteur.

## Impact technique

Un outil par type de contenu ; symboles ca65 générés depuis les ID.

## Date

2026-07-23

## Validé par

_En attente : Maxime._
