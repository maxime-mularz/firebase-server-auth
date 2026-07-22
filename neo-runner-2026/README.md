# 🤖 NÉO-RUNNER 2026 — un « Mario » en assembleur, pour les nuls (niveau 2)

Nous sommes en **2026**. Vous êtes **R-2026**, un petit robot livreur qui
court sur les toits d'une ville couverte de néons. Ramassez les **puces de
données** (10 points), sautez sur les **drones de livraison** concurrents
pour les détruire (les toucher de côté coûte une vie), franchissez les
vides entre les immeubles, et rejoignez l'**antenne-relais** au bout des
1024 pixels du niveau.

Un vrai jeu de plateforme **à défilement horizontal**, comme Super Mario
Bros., écrit en assembleur 6502 et commenté ligne par ligne en français.

```
   010                              3
   ██████ ▓▓                        │
   ██████ ▓▓   ✦        ▓▓▓▓▓▓     │ ← plateformes néon
          ▓▓        ✦               │
    🤖         ✈        ▓▓▓▓▓▓  📡  │→ le niveau continue
  ══════════╗ ╔═══╗ ╔══════════════ │→ vers la droite...
  ██████████║ ║███║ ║███████████████│
```

**Commandes** : ← → courir · **A** sauter · **Start** commencer / rejouer.

> **Prérequis** : ce projet est la suite du
> [casse-brique](../casse-brique-nes/), qui explique toutes les bases
> (registres, drapeaux, `#valeur` vs adresse, PPU, tuiles, sprites, NMI).
> Commencez par lui ! Ici, on n'explique que ce qui est **nouveau**.

> **Version 2** — le jeu est complet : écran titre, DEUX mondes, bandeau
> de score fixe (sprite 0 !), quartiers colorés (attributs), animations,
> musique et jingles. Voir la section
> « [Version 2](#la-version-2--du-prototype-au-jeu-fini) ».

## Compiler et jouer

```bash
sudo apt install cc65     # ou : brew install cc65
make                      # → neo-runner.nes
```

Puis ouvrez `neo-runner.nes` dans [Mesen](https://www.mesen.ca/) ou
[FCEUX](https://fceux.com/). Dans Mesen, ouvrez aussi *Debug → Tilemap
Viewer* pendant que vous jouez : vous **verrez** les colonnes de décor
s'écrire dans la nametable cachée, juste avant d'entrer à l'écran. Toute la
magie du défilement, à l'œil nu.

---

## Les quatre grandes idées de ce jeu

### 1. Le défilement — l'écran est une fenêtre, pas le monde

Le niveau fait 1024 pixels de large ; l'écran n'en montre que 256. La NES
possède **deux écrans internes** (les nametables A et B) placés côte à côte
grâce au « miroir vertical » de la cartouche. Deux registres font tout :
`PPUSCROLL` décale l'image de 0 à 255 pixels, et le bit 0 de `PPUCTRL`
choisit l'écran de départ. Ensemble : une fenêtre de 512 pixels.

Mais le niveau en fait 1024 ! L'astuce, la même que Super Mario Bros. : les
deux écrans forment un **tapis roulant**. Pendant que vous regardez la
fenêtre, le jeu réécrit les colonnes qui viennent de sortir à gauche avec le
décor qui va entrer à droite (`maj_defilement` fabrique la colonne,
la `nmi` l'écrit pendant le VBlank). Et comme dans Mario : **la caméra ne
recule jamais** — c'est précisément ce qui rend cette astuce possible, le
décor derrière vous ayant déjà été recyclé.

Au passage, `ecrire_colonne` utilise un bijou du PPU : le bit 2 de
`PPUCTRL` fait avancer les écritures de **32 cases** au lieu d'une — donc
d'une ligne vers le bas. Écrire une colonne verticale devient une simple
boucle.

### 2. Les nombres de 16 bits — fabriquer grand avec petit

Un octet s'arrête à 255. Les positions dans le niveau vont jusqu'à 1023.
La recette, partout dans le code (`joueur_x_lo`/`joueur_x_hi`,
`camera_lo`/`camera_hi`, les drones...) :

```asm
lda joueur_x_lo    ; x += 2 : d'abord l'octet bas...
clc
adc #2
sta joueur_x_lo
lda joueur_x_hi    ; ...puis l'octet haut, qui n'ajoute QUE la retenue
adc #0
sta joueur_x_hi
```

Le 6502 est une calculatrice 8 bits ; les grands nombres, c'est le
programmeur qui les assemble, retenue par retenue. Les comparaisons se font
pareil : octets hauts d'abord, octets bas si égalité.

### 3. La virgule fixe — des sauts fluides sans nombres à virgule

Une gravité d'« un quart de pixel par image » ne tient pas dans des
entiers. Alors on compte en **256e de pixel** : la vitesse verticale occupe
deux octets, `vy_hi` (pixels entiers) et `vy_lo` (256e).

| valeur 16 bits | signification |
|---|---|
| `$0040` | +0,25 pixel/image — la gravité |
| `$0400` | +4 — la vitesse de chute maximale |
| `$FA80` | −5,5 — l'impulsion du saut (complément à deux !) |

Chaque image : `y += vy` puis `vy += gravité`. C'est tout. Il en sort une
parabole parfaite — sans multiplication, sans sinus, sans virgule
flottante. Toute la physique des jeux 8 bits tient dans cette idée.

### 4. Les métatuiles — le niveau est un dessin dans le code

Le niveau n'est pas stocké tuile par tuile, mais en blocs de 16×16 pixels :
vide, béton, plateforme néon, puce, antenne. Cherchez « LE NIVEAU » dans le
source : 64 lignes de 15 lettres, **une ligne = une colonne du monde**,
écrite du ciel au sol. Penchez la tête à gauche : vous voyez le niveau.
Changez un `V` en `B` : vous êtes level designer.

La copie en RAM est rangée pour que l'adresse d'une case se **déduise** des
coordonnées sans multiplication (`type_carte` : 4 opérations logiques).
Les collisions deviennent des « sondes » : après chaque mouvement, on
interroge la carte sous les pieds, au-dessus de la tête, sur les flancs —
et on repousse le joueur au bord du bloc touché. En assembleur, bien
*ranger* ses données vaut mieux que bien *calculer*.

---

## Visite guidée

| Routine | Ce qu'on y apprend |
|---|---|
| `charger_niveau` | copie ROM→RAM avec pointeurs `(ptr),y`, redessin des 2 écrans |
| `construire_colonne` / `ecrire_colonne` | métatuiles → tuiles, écriture verticale (+32) |
| `maj_joueur` | course 16 bits, gravité 8.8, saut, sondes de collision |
| `type_carte` / `est_solide` | l'adresse déduite des coordonnées |
| `ramasser_puce` | modifier la carte ET l'écran (file d'attente pour la nmi) |
| `maj_camera` / `maj_defilement` | la caméra qui suit, le décor qui se recycle |
| `maj_drones` | tableaux indexés par X, patrouilles, écrasement vs contact fatal |
| `lire_manette` | détecter un bouton « qui vient d'être pressé » (le saut !) |
| `nmi` | sprites + colonne en attente + puce à effacer + **le défilement** |

La machine à états s'est enrichie : TITRE → JEU → (PERDU | GAGNÉ) → reset.
Et le tableau de bord est fait de **sprites** (le fond défile, pas eux !).

## La version 2 : du prototype au jeu fini

Cinq chantiers ont terminé le jeu — chacun est commenté dans le source :

- **Le bandeau fixe, par l'astuce du SPRITE 0** (`nmi`, `dessiner_hud`).
  Le score et les vies sont des tuiles de décor... qui ne défilent pas :
  l'image commence sans défilement (le bandeau se dessine droit), un
  sprite invisible posé sur sa dernière ligne lève un drapeau quand le PPU
  le peint, et à cet instant — en PLEINE image — on bascule le défilement
  vers la caméra. C'est la technique exacte de Super Mario Bros. Dans
  Mesen, l'Event Viewer montre la bascule à la ligne 24.
- **Les tables d'attributs** : le bandeau a sa palette, et chaque écran du
  niveau est un « quartier » au néon différent — cyan, rose — configuré une
  fois, sans coût pendant le jeu.
- **L'animation** (`maj_sprites`) : deux poses de jambes alternées toutes
  les 8 images pour la course, rotors de drones à 15 Hz. Une animation, ce
  n'est QUE changer un numéro de tuile au bon rythme.
- **La musique et les JINGLES** (`maj_musique`, `maj_jingle`) : le moteur
  du casse-brique, plus des mini-partitions sur le canal des bips — la
  fanfare du monde suivant monte, celle du game over descend.
- **L'écran titre et les DEUX MONDES** (`dessiner_titre_texte`,
  `charger_niveau`) : un alphabet de 10 lettres dans la CHR, et des cartes
  choisies par pointeur — la première antenne mène au monde 2 (trous plus
  larges, tours plus hautes), la seconde à la victoire. Ajouter un monde
  = ajouter une table. Au passage, un piège vécu : `charger_niveau` laisse
  le PPU en mode « +32 » (colonnes)... et le premier titre s'est écrit
  À LA VERTICALE. Le mode d'incrément fait partie de l'état du PPU !

## Exercices

1. **Turbo** — passez la course de 2 à 3 pixels/image (`maj_joueur`). Que
   faut-il vérifier pour que les collisions tiennent toujours ?
2. **Lune** — divisez `GRAVITE` par deux. Puis compensez en réduisant
   l'impulsion `SAUT_HI`/`SAUT_LO`. Vous venez de « game-designer ».
3. **Monde 3** — une troisième carte `niveau_3`, trois drones de plus dans
   les tables, et... qu'est-ce qui doit changer dans `maj_joueur` pour que
   la 2e antenne ne soit plus la dernière ?
4. **Drones nerveux** — faites-les patrouiller 2 pixels par image au
   monde 2 seulement (indice : les tables des drones savent déjà faire des
   différences par monde).
5. **Saut modulable** — dans `maj_joueur`, si A est relâché pendant la
   montée, divisez la vitesse verticale par deux : petit saut / grand saut,
   comme dans Mario.
6. **Compositeur de jingles** — un troisième jingle « puce ramassée » de
   deux notes très courtes (attention : il partage le canal des bips).
7. **Chronomètre** — affichez au bandeau le temps écoulé (le compteur
   `image` déborde 4 fois par seconde... il vous faut des secondes).

## Ressources

- [NESdev Wiki — PPU scrolling](https://www.nesdev.org/wiki/PPU_scrolling) :
  la référence exacte de ce que fait notre `nmi` ;
- [Famicom Party](https://famicom.party/book/) — le livre en ligne gratuit ;
- le [casse-brique](../casse-brique-nes/) de ce dépôt pour toutes les bases.

Bonne livraison. 🤖📦
