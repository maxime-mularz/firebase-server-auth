---
id: TECH_SAUVE
title: Systeme de sauvegarde
type: technical
status: approved
owner: technical
reviewers: [narrative]
version: 0.1
last_updated: 2026-07-23
implementation_status: implemented
related_issues: []
related_files: []
---

# Système de sauvegarde (état réel + évolution)

## Format v1 (implémenté, cristal-2026)

SRAM $70:0000, 16 octets :

```text
0-3   "CR26"      signature
4     1           version
5-7   x, y, direction du héros
8-9   or (16 bits)   10-11  pas (16 bits)
12    drapeau coffre  13  réservé
14-15 somme de contrôle (octets 0-13)
```

Signature OU somme invalide ⇒ pas de CONTINUER (« données corrompues »).
Le test `tests/smoke_cristal.py` simule extinction/rallumage ET la
corruption d'un bit.

## Règles d'évolution

1. Tout ajout à l'état persistant = **nouvelle version** du bloc +
   migration lisible des versions antérieures (ou refus documenté).
2. Le bloc v2 (phase 2+) devra accueillir : position + carte courante,
   drapeaux de scénario (proposition : 32 octets = 256 drapeaux),
   inventaire, équipe. Budget SRAM : 8 Ko — très confortable, mais
   chaque champ doit être justifié.
3. Trois emplacements de sauvegarde (comme les FF) : à trancher
   [DECISION_REQUIRED] — coût nul en SRAM, coût réel en interface.
