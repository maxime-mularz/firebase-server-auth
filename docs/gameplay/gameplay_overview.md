---
id: GP_OVERVIEW
title: Vue d'ensemble du gameplay
type: gameplay
status: draft
owner: technical
reviewers: [narrative, creative]
version: 0.1
last_updated: 2026-07-23
implementation_status: in_progress
related_issues: []
related_files: []
---

# Vue d'ensemble du gameplay

## Ce qui EXISTE aujourd'hui (fondation cristal-2026, phase 1)

- déplacement 4 directions au pixel, collisions par tuile ;
- interaction contextuelle (bouton A face à un objet) ;
- un objet à état persistant (coffre) ;
- compteurs 16 bits (or, pas) affichés en décimal ;
- sauvegarde/chargement SRAM avec somme de contrôle ;
- musique + bruitages SPC700 (module commun).

## Le plan de construction (phases validées avec Maxime)

| Phase | Contenu | Statut |
|---|---|---|
| 1 | cartouche 256 Ko, SRAM, 16 bits, salle jouable | **fait** (cristal-2026) |
| 2 | carte défilante 4 directions, PNJ, événements, portes | à venir |
| 3 | moteur de texte : fenêtres, police, script | à venir |
| 4 | combat au tour par tour, stats, inventaire, monstres en données | à venir |
| 5 | Mode 7, transparences, musique 8 voix | à venir |

## À définir (avec le Narrative Director)
_Le poids relatif exploration / dialogue / combat ; la structure d'une
session de jeu type._
