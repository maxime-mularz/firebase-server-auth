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

## Exercices

1. **Turbo** — passez la course de 2 à 3 pixels/image (`maj_joueur`). Que
   faut-il vérifier pour que les collisions tiennent toujours ?
2. **Lune** — divisez `GRAVITE` par deux. Puis compensez en réduisant
   l'impulsion `SAUT_HI`/`SAUT_LO`. Vous venez de « game-designer ».
3. **Level design** — ajoutez une plateforme et deux puces dans la table
   `niveau`. Une ligne = une colonne, 15 lettres, du ciel au sol.
4. **Drones nerveux** — faites-les patrouiller 2 pixels par image (attention
   aux bornes !), ou ajoutez un 4e drone (tables + `.res 3` → `.res 4`... et
   quoi d'autre ?).
5. **Saut modulable** — dans `maj_joueur`, si A est relâché pendant la
   montée, divisez la vitesse verticale par deux : petit saut / grand saut,
   comme dans Mario.
6. **Deux mondes** — après l'antenne, rechargez un second niveau (une
   seconde table `niveau2` et un pointeur au lieu de l'adresse en dur).
7. **Le son** — un « bip » à chaque puce via l'APU (`$4000-$4003`,
   [doc](https://www.nesdev.org/wiki/APU_basics)).

## Ressources

- [NESdev Wiki — PPU scrolling](https://www.nesdev.org/wiki/PPU_scrolling) :
  la référence exacte de ce que fait notre `nmi` ;
- [Famicom Party](https://famicom.party/book/) — le livre en ligne gratuit ;
- le [casse-brique](../casse-brique-nes/) de ce dépôt pour toutes les bases.

Bonne livraison. 🤖📦
