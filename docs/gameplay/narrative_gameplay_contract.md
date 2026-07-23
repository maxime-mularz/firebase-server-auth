---
id: GP_CONTRAT
title: Contrat narration-gameplay
type: contract
status: draft
owner: technical
reviewers: [narrative, creative]
version: 0.1
last_updated: 2026-07-23
implementation_status: not_started
related_issues: []
related_files: []
---

# Le contrat narration ↔ gameplay ↔ code

Ce document définit ce que chaque rôle peut attendre des autres.

## Ce que la narration peut demander au moteur (état phase 1, engagement phase 2-3)

| Capacité | Disponible | Notes |
|---|---|---|
| drapeaux persistants (required_flags / sets_flags) | OUI (format à étendre) | sauvegardés en SRAM |
| objets donnés/requis | OUI (coffre) | inventaire réel : phase 4 |
| dialogues fenêtrés | phase 3 | contraintes : dialogue_style.md |
| PNJ, déplacements scriptés | phase 2 | |
| musique par scène / jingles | OUI | 4 voix, module commun |
| changements de palette (nuit, malaise...) | OUI | CGRAM/HDMA |
| combats déclenchés par scène | phase 4 | |
| cinématiques sans contrôle | possible | LIMITE DE RYTHME ci-dessous |

## Règles de rythme (applicables en review)

- pas plus de ~40 s sans contrôle joueur (calibrer en playtest) ;
- `skippable: true` par défaut pour toute scène rejouable ;
- une scène qui pose `sets_flags` doit être atteignable — le validateur
  vérifie que tout `required_flags` est posé quelque part.

## Écarts d'implémentation

Tout écart entre une scène `approved` et son implémentation est consigné
dans la section « Notes d'implémentation » de la scène avec le tag
`[IMPLEMENTATION_NOTE]`, et signalé dans la PR.
