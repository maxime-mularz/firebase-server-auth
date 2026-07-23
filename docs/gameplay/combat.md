---
id: GP_COMBAT
title: Combat
type: gameplay
status: idea
owner: narrative
reviewers: [technical, creative]
version: 0.1
last_updated: 2026-07-23
implementation_status: not_started
related_issues: []
related_files: []
---

# Combat

_Système à concevoir (phase 4). Ce document cadre les questions, pas les
réponses._

## À décider
- tour par tour strict ou ATB (jauges temps réel) ? [DECISION_REQUIRED]
- taille du groupe (technique : 3-4 personnages tiennent à l'écran en
  sprites 16×24 sans clignotement) ;
- place du combat dans un jeu sur la mémoire — les piliers interdisent
  le « méchant sans motivation » : qui affronte-t-on, et pourquoi ?

## Contraintes techniques connues (réelles)
- écran de combat = changement complet de tilemaps + palettes :
  transition à budgéter (fondu CGRAM, déjà maîtrisé) ;
- 128 sprites, ~34 par ligne de balayage : les gros monstres seront des
  FONDS (BG) comme dans les vrais FF, pas des sprites ;
- les formules de dégâts utiliseront la multiplication/division
  matérielles (démontrées dans cristal-2026).
