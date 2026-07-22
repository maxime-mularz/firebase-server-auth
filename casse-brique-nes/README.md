# 🧱 Casse-brique NES — l'assembleur pour les nuls

Un jeu de casse-brique **complet et jouable** pour la Nintendo NES (1985),
écrit en **assembleur 6502**, et pensé comme un cours : chaque ligne du code
source est commentée en français, des registres du processeur jusqu'au dessin
des tuiles pixel par pixel.

**Aucune connaissance préalable n'est nécessaire.** Si vous savez ce qu'est
une variable, vous pouvez suivre.

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
**Start** pour rejouer après une victoire ou une défaite.

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
| `charger_palettes`, `dessiner_decor` | écrire dans la mémoire vidéo, calculs d'adresses sur 16 bits avec un CPU 8 bits |
| `principale` | la boucle de jeu et la machine à états (attente / jeu / fini) |
| `lire_manette` | lire du matériel bit par bit (l'astuce LSR/ROL) |
| `deplacer_balle`, `collision_*` | divisions par 8 en décalant les bits, complément à deux, rebonds |
| `maj_musique`, `jouer_bip`... | l'APU : jouer une partition et des bruitages (section suivante) |
| `nmi` | le DMA des sprites, la pile, `RTI` |
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

---

## 5. Exercices

Du plus facile au plus costaud. Recompilez avec `make` après chaque essai.

1. **Les couleurs** — dans la table `palettes`, remplacez `$27` (orange des
   briques) par une autre valeur `$00-$3C`. La palette complète de la NES est
   sur [le wiki NESdev](https://www.nesdev.org/wiki/PPU_palettes).
2. **La raquette turbo** — dans `maj_raquette`, changez les `#2` en `#4`.
   Pourquoi faut-il aussi ajuster la valeur du blocage à droite ?
3. **Le pixel-art** — dans le segment `CHR`, redessinez la balle (tuile
   `$04`) en modifiant les `%00111100`... Chaque `1` est un pixel allumé.
4. **Score gourmand** — faites rapporter 10 points par brique au lieu de 1
   (indice : dans `incrementer_score`, il suffit de commencer par les
   dizaines).
5. **Une vie de plus** — 4 vies au départ. Un seul octet à changer !
6. **Des angles de rebond** — la raquette est coupée en 2 moitiés
   (`collision_raquette`). Coupez-la en 4 zones : les bords renvoient la
   balle avec `dx = ±3`, le centre avec `dx = ±1`. (Attention : avec dx=3,
   vérifiez vos bornes de rebond sur les murs !)
7. **Compositeur** — changez la table `melodie` (note, durée, note,
   durée..., `$FF` pour boucler). Ajoutez une note à la gamme : calculez sa
   période avec la formule du source, ajoutez-la aux tables
   `notes_bas`/`notes_haut` et sa constante `NOTE_...`. Essayez aussi de
   changer le *timbre* : les 2 bits du haut de `CARRE2_VOL` (le « duty »)
   transforment le son du tout au tout ([doc APU](https://www.nesdev.org/wiki/APU_basics)).
8. **Niveau 2** — quand `briques_restantes` tombe à 0, au lieu de figer le
   jeu, redessinez les briques et remontez la vitesse. Il faudra le faire
   écran éteint (`PPUMASK = 0`) ou par petits paquets pendant les VBlank...

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
