# 🧱 Casse-brique NES — l'assembleur pour les nuls

Un jeu de casse-brique **complet et jouable** pour la Nintendo NES (1985),
écrit en **assembleur 6502**, et pensé comme un cours : chaque ligne du code
source est commentée en français, des registres du processeur jusqu'au dessin
des tuiles pixel par pixel.

**Aucune connaissance préalable n'est nécessaire.** Si vous savez ce qu'est
une variable, vous pouvez suivre.

> **Version 2** — le jouet est devenu un jeu d'arcade : rebonds à 5 angles,
> capsules bonus, multiball, briques solides et dorées, niveaux à motifs,
> écran titre avec record. Les bases (sections 1 à 4) n'ont pas changé ;
> les nouvelles techniques ont leur section, la [4 ter](#4-ter--la-version-2--les-techniques-dun-jeu-darcade).

```
┌────────────────────────────────┐
│  005                        3  │   ← score            vies ↑
│████████████████████████████████│
│█ ▓▓▓▓▓▓ ▓▓▓▓▓▓ ▓▓▓▓▓▓ ▓▓▓▓▓▓ ██│
│█ ▓▓▓▓▓▓ ▓▓▓▓▓▓ ▓▓▓▓▓▓ ▓▓▓▓▓▓ ██│
│█ ▓▓▓▓▓▓ ▓▓▓▓▓▓        ▓▓▓▓▓▓ ██│   ← 6 rangées de 15 briques
│█                              ██│
│█             ●                ██│   ← la balle (1 sprite)
│█                              ██│
│█          ▬▬▬▬▬▬▬▬            ██│   ← la raquette (3 sprites)
└────────────────────────────────┘
```

**Commandes** : ← → pour bouger la raquette · **A** pour lancer la balle ·
**Start** pour commencer (et revenir au titre après un game over).

Frappez du bout de la raquette pour des angles rasants, au centre pour
remonter droit. Les briques grises encaissent deux coups, les dorées valent
5 points, et les capsules qui tombent donnent : raquette élargie, balle
lente, vie bonus... et le MULTIBALL.

---

## 1. Compiler et jouer

Il vous faut la suite [cc65](https://cc65.github.io/) (qui contient `ca65`,
l'assembleur, et `ld65`, l'éditeur de liens) :

```bash
# Debian / Ubuntu
sudo apt install cc65

# macOS
brew install cc65
```

Puis :

```bash
make            # produit casse-brique.nes (40 976 octets)
```

Ouvrez `casse-brique.nes` dans un émulateur NES :

- [Mesen](https://www.mesen.ca/) — le plus précis, avec un excellent
  **débogueur** (vous pouvez exécuter le jeu instruction par instruction et
  regarder les registres changer en direct — faites-le, c'est magique) ;
- [FCEUX](https://fceux.com/) — un grand classique.

---

## 2. C'est quoi, l'assembleur ?

Un processeur ne comprend que des nombres : des **codes machine**. Par
exemple, pour le 6502, la suite d'octets `A9 05 8D 00 03` signifie « mets 5
dans le registre A, puis range A à l'adresse $0300 ».

L'assembleur est simplement une **notation lisible** de ces codes, un nom par
instruction :

```asm
LDA #5          ; A9 05     "LoaD A" avec la valeur 5
STA $0300       ; 8D 00 03  "STore A" à l'adresse $0300
```

Il n'y a **pas** de `if`, pas de `for`, pas de fonctions, pas de types. Tout
ce que vous avez :

| Concept moderne | Équivalent en assembleur |
|---|---|
| variable | une adresse mémoire (un octet : 0 à 255) |
| `x = 5` | `LDA #5` puis `STA x` |
| `x = x + 2` | `LDA x`, `CLC`, `ADC #2`, `STA x` |
| `if (x == 8)` | `LDA x`, `CMP #8`, `BEQ la_bas` |
| `while` / `for` | une étiquette + un branchement vers l'arrière |
| fonction | `JSR routine` ... `RTS` |

### Les trois registres

Le 6502 n'a que **trois registres de travail** de 8 bits — trois « mains »
pour manipuler les données :

- **A** (accumulateur) : les calculs. Additions, comparaisons, tout passe par lui.
- **X** et **Y** (index) : surtout des compteurs de boucle et des index de
  tableau (`LDA grille, x` lit la case `grille + X`).

Tout le reste vit **en mémoire**. C'est comme cuisiner avec seulement trois
doigts : on passe son temps à poser et reprendre les ingrédients.

### Les drapeaux (flags)

Chaque opération met à jour de petits indicateurs, et les instructions de
branchement les testent :

- **Z** (zéro) : le dernier résultat vaut 0 → testé par `BEQ` / `BNE` ;
- **C** (retenue/carry) : débordement d'addition, ou résultat d'une
  comparaison → `BCS` (≥) / `BCC` (<) ;
- **N** (négatif) : le bit 7 du résultat → `BMI` / `BPL`.

`CMP #8` fait en réalité « A − 8 » sans garder le résultat : seuls les
drapeaux changent. `BCS` après un `CMP` veut donc dire « si A ≥ 8 ».

### Les pièges classiques (vous vous ferez avoir, c'est normal)

1. **`#` = valeur, sans `#` = adresse.** `LDA #$20` charge 32 ; `LDA $20`
   charge *ce qui se trouve* à l'adresse 32.
2. **`CLC` avant `ADC`, `SEC` avant `SBC`.** L'addition inclut toujours la
   retenue ; il faut la mettre dans le bon état soi-même.
3. **Les nombres négatifs n'existent pas** — on fait *comme si* : sur un
   octet, 254 se comporte comme −2 (254 + 2 = 256 = 0 sur 8 bits). C'est le
   **complément à deux**. Notre balle a une vitesse de `$FE` quand elle va
   vers la gauche.
4. **Un octet va de 0 à 255**, et il boucle silencieusement : 255 + 1 = 0.
   Le code du jeu exploite d'ailleurs ce bouclage plusieurs fois.

---

## 3. La NES en cinq minutes

La console contient deux puces qui travaillent en parallèle :

- le **CPU** (un 6502 à 1,79 MHz) exécute votre programme ;
- le **PPU** (Picture Processing Unit) dessine l'image, 60 fois par seconde,
  ligne par ligne, en même temps que la télé l'affiche.

Le CPU ne dessine **jamais** de pixels. Il prépare des données, et le PPU les
affiche. Trois notions suffisent pour lire notre code :

### a) Le fond : des tuiles

L'écran de fond est une grille de **32 × 30 tuiles** de 8×8 pixels. La
« nametable » (adresse vidéo `$2000`) contient simplement le numéro de tuile
de chaque case. Nos **murs et briques** sont des tuiles de fond : casser une
brique = écrire « tuile vide » dans deux cases de la nametable.

### b) Les sprites : des objets mobiles

64 petits objets de 8×8 pixels, positionnables au pixel près. Chacun est
décrit par 4 octets (Y, tuile, attributs, X). Notre **balle** est 1 sprite,
la **raquette** en fait 3 côte à côte. Le jeu prépare un « brouillon » des
64 sprites en RAM (`$0200-$02FF`) puis l'envoie d'un bloc au PPU (le *DMA*).

### c) Le VBlank et la NMI : le battement de cœur du jeu

Pendant qu'une image est dessinée, toucher à la mémoire vidéo produit des
parasites. Le seul moment sûr est le **VBlank** : la fraction de milliseconde
où le faisceau de la télé remonte en haut de l'écran, entre deux images.

Le PPU prévient le CPU du début de chaque VBlank en déclenchant une
interruption, la **NMI** : le CPU lâche ce qu'il faisait et exécute notre
routine `nmi`. Tout le jeu est cadencé par elle :

```
       ┌──────────── 1/60e de seconde ────────────┐
 NMI → │ envoyer sprites, effacer brique, score    │  (VBlank : ~2 ms)
       │ puis, pendant que le PPU dessine :        │
       │ lire manette → déplacer → collisions      │  (boucle principale)
       │ → préparer le brouillon de sprites        │
       │ → attendre la prochaine NMI               │
       └───────────────────────────────────────────┘
```

C'est la règle d'or du fichier source : **la boucle principale calcule, la
routine `nmi` affiche.** Quand la balle casse une brique, la boucle
principale ne peut pas l'effacer elle-même ; elle note l'adresse dans une
petite « file d'attente » (`effacer_actif`, `effacer_hi/lo`) que `nmi`
traitera au prochain VBlank.

---

## 4. Visite guidée du code

Tout est dans **[`src/casse-brique.s`](src/casse-brique.s)** (~700 lignes,
dont beaucoup de commentaires). Ordre de lecture conseillé :

| Section | Ce que vous y apprendrez |
|---|---|
| En-tête du fichier | les instructions 6502 essentielles |
| Constantes + variables | page zéro, registres du PPU |
| `reset` | le rituel d'initialisation de toute cartouche NES |
| `charger_palettes`, `dessiner_cadre` | écrire dans la mémoire vidéo, calculs d'adresses sur 16 bits avec un CPU 8 bits, la table d'attributs |
| `principale` | la boucle de jeu et la machine à 5 états |
| `lire_manette` | lire du matériel bit par bit, détecter un bouton « qui vient d'être pressé » |
| `deplacer_balle`, `collision_*` | virgule fixe 8.8, complément à deux, rebonds à 5 angles |
| `maj_balles`, `echanger_balles` | le multiball : deux balles pour un seul moteur physique |
| `charger_niveau`, `motif_*` | des niveaux pilotés par des données |
| `dessiner_ecran_titre`, `maj_record` | du texte, et un record qui survit aux parties |
| `maj_musique`, `jouer_bip`... | l'APU : jouer une partition et des bruitages (section suivante) |
| `nmi` | le DMA des sprites, les files d'attente d'écriture vidéo, `RTI` |
| Segment `CHR` | les graphismes dessinés octet par octet en binaire — chaque `1` est un pixel ! |

Trois fichiers d'infrastructure l'accompagnent :

- **`nes.cfg`** — dit à l'éditeur de liens où ranger chaque morceau
  (l'en-tête, le code à `$8000`, les vecteurs à `$FFFA`, les graphismes) ;
- **`Makefile`** — les deux commandes de compilation ;
- l'**en-tête iNES** (16 octets au début du `.nes`) décrit la cartouche à
  l'émulateur.

### Comment le jeu « pense » : la machine à états

```
                    A pressé              plus de briques OU plus de vies
  ┌─────────┐   ─────────────►  ┌─────┐   ─────────────────────────────►  ┌──────┐
  │ ATTENTE │                   │ JEU │                                   │ FINI │
  │ (collée)│  ◄─────────────   └─────┘                                   └──┬───┘
  └─────────┘   balle perdue,                     Start pressé (→ reset)     │
       ▲        mais vies > 0                                                │
       └─────────────────────────────────────────────────────────────────────┘
```

Une simple variable `etat` (0, 1 ou 2) et un aiguillage au début de la boucle
principale : c'est le patron de conception le plus utile du jeu vidéo, en
trois `CMP`/`BEQ`.

### La musique et les bruitages : l'APU

La NES a une troisième puce (logée dans le CPU) : l'**APU**, avec 5 voix.
Le jeu en utilise 4 : le **carré 2** joue la mélodie, le **triangle** la
basse, le **carré 1** les bips de rebond, et le canal de **bruit** les
catastrophes (vie perdue, game over). Comme le PPU, l'APU se pilote par des
registres (`$4000-$400F`) — et comme pour l'image, il ne « joue » rien tout
seul : il tient une note tant qu'on ne lui dit rien.

Trois idées à retenir en lisant le code :

- **La hauteur d'une note est une *période*, pas une fréquence** — et c'est
  inversé : grande période = note grave. La formule est dans le source :
  `période = 1 789 773 ÷ (16 × Hz) − 1`. Le la 440 Hz donne 253.
- **Une partition, c'est des octets** : la table `melodie` alterne note et
  durée en images (`NOTE_DO5, 12, ...`), `$FF` reboucle. À chaque image,
  `maj_musique` décompte, et envoie la note suivante quand c'est l'heure —
  le tempo est parfaitement stable puisqu'il est accroché aux 60 Hz du
  VBlank, comme l'image.
- **Un bruitage, c'est un canal réglé puis coupé** : `jouer_bip` règle le
  carré 1 (période + volume), note une durée, et `maj_bruitages` remet le
  volume à zéro quand elle est écoulée. Chaque événement du jeu a sa
  hauteur : mur (grave), raquette (médium), brique (aigu).

La mélodie tourne sur do / la mineur / fa / sol — le fameux enchaînement
« I-vi-IV-V » de la moitié des tubes de l'histoire. Changez-la !

### 4 ter — La version 2 : les techniques d'un jeu d'arcade

Six idées ont transformé le jouet en jeu. Chacune est une leçon :

- **La virgule fixe 8.8** (`balle_dx_lo`/`_hi`...). Une vitesse de
  « 1,5 pixel par image » ne tient pas dans des entiers : on compte donc en
  256e de pixel, sur deux octets. `$0180` = 1,5 ; `$FE80` = −1,5. C'est ce
  qui permet les **5 zones de la raquette** (`collision_raquette`) : du bord
  qui renvoie rasant au centre qui renvoie droit — et le jeu devient un jeu
  de visée. Chaque zone a même sa note de musique.
- **Le multiball, ou la magie de l'échange** (`maj_balles`,
  `echanger_balles`). Plutôt que de dupliquer le moteur physique pour la
  2e balle, on échange les 8 octets de la balle 2 avec ceux de la balle 1,
  on fait tourner le moteur (qui n'y voit que du feu), et on ré-échange.
  Possible uniquement parce que les deux blocs de variables sont déclarés
  dans le même ordre : **en assembleur, l'ordre de déclaration est une
  structure de données.**
- **Des entités typées dans la grille**. Une case ne dit plus « brique ou
  pas » mais porte un TYPE (normale, solide, dorée, fissurée) qui pilote
  tout : tuiles affichées, points, résistance. La brique solide touchée
  n'est pas effacée mais *redessinée fissurée* — la file d'attente de la
  nmi transporte désormais les tuiles à écrire, pas juste une adresse.
- **La table d'attributs** (`dessiner_cadre`). Les 64 derniers octets de la
  nametable choisissent la palette de chaque carré de 4×4 tuiles. Deux
  rangées d'attributs couvrent pile la zone des briques : on y active la
  palette 1, et les briques dorées deviennent... dorées, sans toucher au
  blanc des chiffres.
- **Des niveaux pilotés par les données** (`charger_niveau`, `motif_*`).
  Le code ne connaît aucun niveau : il copie un motif de 96 octets depuis
  la ROM et le dessine. Quatre motifs lisibles en toutes lettres (V, N, S,
  D) dans le source, qui bouclent de plus en plus vite. Ajouter un niveau
  = dessiner un tableau.
- **Le cycle de vie des données** (`reset` vs `demarrer_partie`). Le record
  doit survivre d'une partie à l'autre : le jeu ne repasse donc plus JAMAIS
  par le reset entre deux parties. Allumer la console et commencer une
  partie sont deux choses différentes — c'est ce qui rend possible l'écran
  titre, son RECORD, et le « GAME OVER » écrit à l'écran avec notre
  alphabet de 16 lettres dessiné dans la CHR-ROM.

---

## 5. Exercices

Du plus facile au plus costaud. Recompilez avec `make` après chaque essai.

1. **Les couleurs** — dans la table `palettes`, remplacez `$27` (orange des
   briques) par une autre valeur `$00-$3C`. La palette complète de la NES est
   sur [le wiki NESdev](https://www.nesdev.org/wiki/PPU_palettes).
2. **Le pixel-art** — dans le segment `CHR`, redessinez la balle (tuile
   `$04`) en modifiant les `%00111100`... Chaque `1` est un pixel allumé.
3. **Level designer** — ajoutez un 5e motif de niveau : un tableau de
   6×16 lettres (V, N, S, D), une entrée dans `motifs_lo`/`motifs_hi`, et
   le modulo dans `charger_niveau` à passer de `#%00000011` à... réfléchissez :
   pourquoi un simple AND ne suffit-il plus pour « modulo 5 » ?
4. **Vos angles à vous** — les tables `zones_dx_*`/`zones_dy_*` sont les
   réglages de jeu les plus sensibles du fichier. Essayez des bords plus
   rasants (dx = ±2,5), un centre parfaitement vertical (dx = 0 — mais que
   devient la partie si la balle monte tout droit pour toujours ?).
5. **La 5e capsule** — une capsule « malus » qui RÉTRÉCIT la raquette
   (2 segments au lieu de 3) ! Il faut : une constante, une tuile, une
   entrée dans `tuiles_capsules`, un cas dans `maj_capsule`, une minuterie,
   et adapter `maj_sprites` + la butée droite + la largeur d'attrape.
6. **Compositeur** — changez la table `melodie` (note, durée, ..., `$FF`
   pour boucler). Ajoutez une note : calculez sa période avec la formule du
   source, ajoutez-la aux tables `notes_bas`/`notes_haut`. Et changez le
   *timbre* : les 2 bits du haut de `CARRE2_VOL` (le « duty ») transforment
   le son du tout au tout ([doc APU](https://www.nesdev.org/wiki/APU_basics)).
7. **Triple ball** — le multiball ne gère que 2 balles... ajoutez la 3e.
   `echanger_balles` et `maj_balles` vous montrent le chemin ; la vraie
   question est : comment savoir quelle vie perdre quand *laquelle* tombe ?
8. **RECORD clignotant** — quand le score final BAT le record, faites
   clignoter la ligne RECORD de l'écran titre (indice : le compteur
   `image` et un bit bien choisi, comme pour la balle du game over).

---

## 6. Pour aller plus loin

- [NESdev Wiki](https://www.nesdev.org/wiki/) — LA référence (matériel,
  registres, tutoriels) ;
- [Famicom Party](https://famicom.party/book/) — un livre en ligne gratuit,
  progressif et moderne, qui utilise aussi ca65 ;
- [Easy 6502](https://skilldrick.github.io/easy6502/) — apprendre le 6502
  dans le navigateur, avec un simulateur interactif ;
- [Nerdy Nights (traduction française)](https://nesdev.org/wiki/Nerdy_Nights) —
  la série de tutoriels historique ;
- la documentation de [ca65/ld65](https://cc65.github.io/doc/ca65.html).

Bon voyage en 1985 ! 🕹️
