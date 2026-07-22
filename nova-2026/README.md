# 🚀 NOVA-2026 — un shoot'em up en assembleur, pour les nuls (niveau 3)

**2026, orbite basse.** Les drones de livraison devenus fous foncent sur le
relais orbital. Vous pilotez l'intercepteur NOVA : 8 vagues d'ennemis aux
formations différentes, puis tout recommence — plus vite. Tenez !

Un drone abattu vaut 10 points ; un drone qui vous percute coûte une vie
(avec quelques secondes d'invincibilité clignotante pour souffler). Le
record de la session vous attend à l'écran titre.

**Commandes** : ←/→ piloter · **A** tirer (maintenez : tir automatique) ·
**Start** commencer / rejouer.

> Ce projet est le **niveau 3** du cours. Les bases sont dans le
> [casse-brique](../casse-brique-nes/), le défilement horizontal dans
> [NÉO-RUNNER](../neo-runner-2026/). Ici, on n'explique que le neuf.

## Compiler et jouer

```bash
sudo apt install cc65    # ou : brew install cc65
make                     # → nova.nes, à ouvrir dans Mesen ou FCEUX
```

---

## Les cinq leçons de ce jeu

### 1. Le défilement vertical — un octet dans l'en-tête change la console

Le champ d'étoiles descend : sensation de vol. La clé n'est pas dans le
code mais dans **l'octet 6 de l'en-tête iNES**, passé à `$00` : le « miroir
horizontal » **empile** les deux écrans internes au lieu de les mettre côte
à côte (comme dans NÉO-RUNNER). Décrémenter `defil_y`, basculer d'écran
quand il repasse sous zéro : 480 pixels de ciel qui bouclent sans couture,
pour deux octets par VBlank.

Et surtout : une fois les étoiles semées, **ce jeu n'écrit plus jamais dans
le décor**. Tout ce qui bouge est sprite. Comparez la `nmi` des trois jeux —
celle-ci est quasi vide. Le choix d'architecture EST l'optimisation.

### 2. Le hasard, fabriqué maison : le LFSR

Le 6502 n'a pas de `random()`. On le fabrique en 4 instructions
(`aleatoire`) : un registre à décalage rebouclé — on décale la graine, et si
un bit « tombe », on en retourne d'autres (le `EOR #$1D`, positions choisies
par les mathématiciens). La séquence met 255 tours à se répéter. Piège
appris à nos dépens : nourri de zéro, un LFSR ne produit... que des zéros.

### 3. Les réservoirs d'objets (object pools)

3 tirs, 8 ennemis : des **tableaux parallèles** (`enn_x`, `enn_y`,
`enn_etat`...) parcourus avec X et Y. Un objet meurt en remettant son état
à 0, naît en trouvant une case libre. Aucune allocation, jamais : sur
console, la mémoire se découpe une fois pour toutes. La double boucle de
`collisions_tirs` (chaque tir contre chaque drone, X et Y en parallèle) est
LE motif à retenir.

Chaque ennemi est une petite machine à états : ATTENTE (son délai d'entrée
décompte) → VOL (descente + zigzag) → EXPLOSE (l'étincelle s'affiche
quelques images) → MORT.

### 4. Des vagues pilotées par les données

Une vague = 24 octets : 8 × (type, colonne, délai). Le code ne connaît
aucune vague, il les lit (`charger_vague`). Regardez les tables `vague_1` à
`vague_8` : la file bien élevée, le grand V, « par les flancs »... Composez
les vôtres — et comme les ennemis sont des sprites, on change de vague en
plein vol, sans toucher à l'écran.

### 5. Les i-frames — l'invincibilité temporaire

Après un choc : `nav_inv = 90`, et pendant 90 images le vaisseau est
intouchable et **clignote** (un bit du compteur d'images le cache une image
sur huit). Tous les jeux d'action du monde font exactement ça. Le
« GAME OVER », lui, est écrit **en sprites** : le décor défile, pas lui.

## Exercices

1. **Chorégraphe** — composez une 9e vague (24 octets + une entrée dans
   `vagues_lo`/`hi`... et le `AND #%00000111` de `charger_vague` à revoir).
2. **Plus vite, plus haut** — un deuxième type de tir : maintenir B pour
   des tirs 2× plus rapides mais un canon 2× plus lent à recharger.
3. **Le boss** — un drone géant de 4 sprites (2×2) qui encaisse 10 tirs,
   entre en scène toutes les 4 vagues. Son état de santé tient dans un
   octet de plus.
4. **Étoiles filantes** — dans `semer_les_etoiles`, jouez avec les
   probabilités (`AND #%00011111`) et ajoutez une 3e sorte d'étoile.
5. **La pluie de bonus** — importez les capsules du casse-brique : un drone
   abattu lâche parfois une capsule (bouclier ? double canon ?).

## Ressources

- [NESdev — Mirroring](https://www.nesdev.org/wiki/Mirroring) : pourquoi
  l'octet 6 change la géométrie des écrans ;
- [NESdev — Random number generator](https://www.nesdev.org/wiki/Random_number_generator) :
  des LFSR plus costauds que le nôtre ;
- les deux autres jeux de ce dépôt, pour tout le reste.

Trois jeux, trois architectures. À vous d'inventer le quatrième. 🕹️
