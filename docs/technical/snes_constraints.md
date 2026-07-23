---
id: TECH_SNES
title: Contraintes SNES pour la narration
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

# La SNES expliquée au Narrative Director

Ce que la console impose aux scènes — et ce qu'elle offre. À lire avant
d'écrire une mise en scène.

## Ce qui est bon marché (utilisez-en !)
- **Couleurs et lumière** : fondus, nuit tombante, salle qui rougit —
  la palette se change par ligne (HDMA) ou en bloc (CGRAM).
- **Musique et silence** : couper la musique est un effet PUISSANT
  (déjà utilisé aux game over du cours).
- **Tremblement d'écran, défilements** : registres de scroll, gratuits.
- **Apparitions/disparitions** de PNJ entre deux images.

## Ce qui coûte (à budgéter en review technique)
- Changer de décor complet = transition (fondu/noir) obligatoire.
- Plus de ~5-6 PNJ animés simultanés = risque de clignotement sprites.
- Texte : ~28 colonnes × 3-4 lignes, MAJUSCULES (pour l'instant).
- Pas de voix ; les sons sont courts (4 voix, timbres simples).

## Ce qui est impossible (aujourd'hui)
- vidéo, rotations de sprites, zooms libres de sprites ;
- alpha par pixel (la transparence SNES est par COUCHE : utilisable
  pour fantômes/brumes — phase 5) ;
- des centaines d'objets à l'écran.

Pilier n°9 : ces limites sont un style, pas une punition.
