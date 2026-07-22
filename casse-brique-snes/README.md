# 🎮 Casse-brique SNES — le passage à la 16 bits (niveau 4)

Le casse-brique complet du cours ([version NES](../casse-brique-nes/) : 5
zones de rebond, capsules, multiball, briques solides et dorées, niveaux,
écran titre, record) porté sur **Super Nintendo** — avec les graphismes
qu'elle mérite : briques biseautées 16 couleurs, murs d'acier rivetés,
balle nacrée, raquette métallisée, police ombrée, et un **dégradé de ciel
par HDMA**, la signature visuelle de la console.

> Prérequis : les trois jeux NES du dépôt. Ici on n'explique que ce qui
> change en passant à la 16 bits. Le **son** est de la partie : le SPC700
> (un second processeur complet) reçoit son programme au démarrage — c'est
> le chapitre 6, raconté dans [../snes-commun/son.s](../snes-commun/son.s)
> et le [README de NOVA SNES](../nova-snes/).

## Compiler et jouer

```bash
sudo apt install cc65        # ca65 assemble aussi le 65816 !
make                         # → casse-brique.sfc
```

Émulateurs : [Mesen2](https://www.mesen.ca/) (débogueur exceptionnel,
comme pour la NES), Snes9x, bsnes. Manette : **B** = lancer la balle
(c'est notre bouton d'action), ← → , Start.

---

## Les cinq leçons de la SNES

### 1. Le 65816 : votre 6502 a grandi — et tout ce que vous savez sert encore

Le CPU de la SNES démarre en mode « émulation », 100 % compatible 6502.
Deux instructions (`clc` + `xce`) le basculent en mode natif, où `REP`/`SEP`
peuvent élargir A, X, Y à 16 bits. **Notre choix pédagogique : rester en
8 bits partout** (`sep #$30`) — la logique du jeu est LE MÊME code que sur
NES, copié presque ligne à ligne. Seuls changent les périphériques.
Piège rencontré : `S` n'est plus un nom de symbole valide, c'est le
registre de pile (`lda 3,s`) !

### 2. La vidéo : tuiles de 16 couleurs, palettes par case

Fini les 2 bits par pixel : en mode 1, chaque tuile a **16 couleurs**
(4 bits/pixel, 32 octets la tuile). Chaque case de la tilemap porte le
numéro de sa palette : la MÊME tuile de brique devient orange, acier ou or
selon l'octet haut de la case — ce que la NES faisait péniblement par
zones de 4×4 tuiles avec ses attributs. L'écriture VRAM passe par
`$2116/$2118/$2119`, le cousin enrichi de `PPUADDR`/`PPUDATA`.

À 16 couleurs, dessiner les tuiles en binaire dans le source serait
illisible : l'atelier **`tools/make_gfx.py`** transforme du pixel-art
texte (des grilles de chiffres hexadécimaux) en binaires 4bpp, incorporés
par `.incbin`. Ouvrez-le : les briques biseautées se dessinent comme un
tableau ASCII.

### 3. Le DMA : charger 64 Ko le temps d'un battement de cils

Plus de boucles de copie : on décrit un transfert (source, destination,
taille) dans les registres `$43x0-$43x6`, on écrit 1 bit dans `$420B`, et
le DMA copie tout, à 2,7 Mo/s. Le jeu s'en sert pour vider la VRAM (avec
une source FIGÉE sur un mot nul !), charger tuiles et palettes, et envoyer
les 544 octets de sprites à chaque VBlank.

### 4. Le HDMA : changer l'image PENDANT qu'elle se dessine

Le canal 1 est configuré en **HDMA** : à chaque ligne de l'écran, il
écrit tout seul une nouvelle couleur de fond dans la CGRAM. Résultat : le
dégradé bleu nuit → violet du ciel, **sans que le CPU ne fasse rien**.
La table (28 paliers de 8 lignes) est générée par `make_gfx.py`. C'est
l'équivalent industrialisé de l'astuce du sprite 0 de la NES : là où il
fallait guetter un drapeau au bon moment, la SNES a un canal dédié.

### 5. Les manettes se lisent toutes seules — et un cadeau du destin

L'auto-joypad (`$4200` bit 0) lit les manettes à chaque VBlank ; on
attend que `$4212` ait fini, puis on lit `$4219`. Et par un heureux hasard
d'ingénierie, **cet octet a exactement la même disposition de bits que
notre variable `boutons` sur NES** (B→A, Start, flèches...). La routine
`lire_manette` a fondu, le reste du jeu n'a pas bougé d'un octet.

Les sprites aussi ont déménagé : l'OAM se remplit par DMA depuis un
brouillon en RAM (comme sur NES), mais l'ordre des champs change
(X, Y, tuile, attributs) et une « table haute » porte le 9e bit de X.

## Exercices

1. **Peintre** — dans `make_gfx.py`, changez les teintes des matériaux
   (fonction `materiau`) et le dégradé du ciel. `make`, et admirez.
2. **La 5e palette** — ajoutez une brique « émeraude » : une palette de
   plus, un type de plus, et sa couleur dans `attr_brique`. Sur SNES,
   c'est TROIS lignes.
3. **Grand écran** — la raquette élargie mérite de vrais embouts : dessinez
   des tuiles dédiées au lieu de réutiliser le segment du milieu.
4. **Mode 7 ?** — renseignez-vous sur le mode 7 (la rotation de fond de
   F-Zero)... et réfléchissez à ce que donnerait un casse-brique qui
   penche. (Chapitre avancé !)
5. **Le SPC700, à votre tour** — le module [../snes-commun/son.s](../snes-commun/son.s)
   téléverse notre pilote de 115 octets dans le processeur audio et rejoue
   la partition NES sur des échantillons BRR. Lisez-le, puis : ajoutez une
   3e voix d'accompagnement, ou dessinez un échantillon BRR « carré 25 % »
   pour retrouver le timbre fin du canal 2 de la NES.

## Ressources

- [SNESdev Wiki](https://snes.nesdev.org/wiki/) — le pendant SNES de NESdev ;
- [fullsnes](https://problemkaputt.de/fullsnes.htm) — LA référence exhaustive
  des registres ;
- la [version NES](../casse-brique-nes/) pour comparer chaque routine :
  c'est le même jeu, et c'est tout l'intérêt.

NES → SNES : mêmes idées, plus de couleurs. La 16 bits vous appartient. 🕹️
