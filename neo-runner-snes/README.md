# 🤖 NÉO-RUNNER 2026 SNES — le défilement en 16 bits (niveau 5)

Le runner NES ([../neo-runner-2026/](../neo-runner-2026/)) porté sur Super
Nintendo : 2 mondes, puces, drones, écran titre — et la ville qu'il
méritait : immeubles aux fenêtres allumées, néons cyan ou roses selon le
quartier, ciel nocturne en dégradé HDMA, robot 16 couleurs à visière
luisante.

```bash
make          # → neo-runner.sfc (cc65 requis)
```

## Les leçons SNES de ce portage

- **Le bandeau fixe ne coûte plus rien.** Sur NES, il fallait guetter le
  sprite 0 pour changer le défilement en pleine image. Sur SNES, le mode 1
  offre une **troisième couche de fond** (BG3, 4 couleurs) : le bandeau y
  vit, immobile et prioritaire (`BGMODE = $09`), pendant que le monde
  défile sur BG1. L'acrobatie est devenue une case à cocher — comparez les
  deux routines `nmi`, c'est tout le progrès matériel de 1990 en une image.
  Bonus : l'écran titre vit aussi sur cette couche fixe.
- **La tilemap 64×32** : les deux écrans côte à côte (miroir vertical NES)
  deviennent une simple taille de tilemap (`BG1SC` bit 0). Le streaming de
  colonnes ne change pas d'un iota — et `VMAIN = $81` écrit les colonnes
  verticalement tout seul, comme le bit 2 de PPUCTRL sur NES.
- **Les quartiers par palette, case par case** : cyan ou rose, le néon est
  choisi colonne par colonne par l'octet de palette de la tilemap — plus
  fin que les attributs par nametable de la NES. La puce ramassée est
  effacée avec l'attribut de SON quartier.
- **La physique n'a pas bougé d'un octet** : virgule fixe, sondes, caméra,
  drones — le code NES ligne à ligne, en `sep #$30`. La preuve par le test :
  notre bot de simulation suit une trajectoire *image pour image identique*
  sur les deux consoles.

Le son (SPC700) reste le chapitre à venir. Graphismes générés par
`tools/make_gfx.py` (pixel-art texte → 4bpp et 2bpp — notez le format
2bpp SNES : plans *entrelacés* ligne à ligne, la NES les rangeait l'un
après l'autre).

## Exercices

1. **Troisième quartier** — une palette 6 (violet ?) et un monde qui
   alterne trois couleurs (indice : le choix se fait dans
   `construire_colonne`).
2. **Parallaxe** — le mode 1 a un BG2 4bpp inutilisé : dessinez-y une
   skyline lointaine et faites-la défiler à demi-vitesse de la caméra
   (`BG2HOFS = camera >> 1`). LE truc que la NES ne savait pas faire.
3. **Fenêtres qui clignotent** — une seconde tuile d'immeuble aux fenêtres
   éteintes, échangée par... réfléchissez : re-uploader la tuile par DMA,
   ou changer la couleur 6 dans la CGRAM ? (La seconde est gratuite !)
4. **Le grand écran** — la SNES gère les sprites 16×16 : passez le robot
   en un seul sprite 16×16 (OBSEL, bit de taille dans la table haute).
