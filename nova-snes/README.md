# 🚀 NOVA-2026 SNES — le défilement vertical... et LE SON (niveau 6)

Le shoot'em up NES ([../nova-2026/](../nova-2026/)) porté sur Super
Nintendo : mêmes 8 vagues, mêmes zigzags, mêmes i-frames — mais un ciel
d'étoiles **multicolores**, un HUD sur la couche fixe, et surtout le
chapitre que tout le cours attendait : **le SPC700 parle**.

```bash
make          # → nova.sfc (cc65 requis)
```

## Les leçons SNES de ce portage

- **Le défilement vertical, en une variable.** Sur NES, il fallait câbler
  la cartouche en miroir horizontal, décompter `defil_y` de 240 à 0 et
  basculer un bit de nametable à la couture. Sur SNES : la tilemap fait
  **32×64** (un bit dans `BG1SC`), le ciel fait 512 pixels, et UN nombre
  de 16 bits écrit dans `BG1VOFS` fait tout. Comparez `defiler_le_ciel`
  dans les deux versions — c'est le même progrès que le bandeau du runner.
- **Les étoiles multicolores.** Le LFSR (le même, au bit près) ne choisit
  plus seulement OÙ naissent les étoiles, mais leur COULEUR : bleutée,
  dorée ou blanche, par l'octet de palette de chaque case de la tilemap.
  La NES imposait une couleur par bloc de 16×16 via ses attributs.
- **Plus un seul sprite de texte.** Sur NES, score, vies et GAME OVER
  volaient en sprites pour échapper au défilement. Ici ils vivent sur BG3,
  la couche fixe et prioritaire : les sprites servent au jeu, l'affichage
  au PPU. La philosophie « le décor ne s'écrit jamais en jeu » demeure —
  BG1 n'est semé qu'une fois.

## 🔊 Le chapitre SPC700 (../snes-commun/son.s)

La SNES ne fait pas de son : elle héberge un **second ordinateur** (CPU
SPC700 + 64 Ko de RAM + synthèse S-DSP à 8 voix), joignable uniquement par
4 boîtes aux lettres (`$2140-$2143`). Le module commun aux trois jeux
raconte tout, mais voici l'intrigue :

1. **On écrit un programme pour lui.** ca65 ne parle pas le SPC700 : notre
   pilote de 115 octets est **assemblé à la main**, octet par octet,
   mnémoniques en commentaires. Il lit les boîtes, pilote le DSP, accuse
   réception.
2. **On le téléverse** par la poignée de main de sa ROM d'amorçage
   (`$AA/$BB`, `$CC`, un octet + son numéro d'ordre, echo à chaque pas) —
   `initialiser_son`, à appeler avant d'activer la NMI. Piège de console
   réelle : le SPC700 **survit au reset logiciel**, le pilote signe donc
   sa présence pour ne pas être téléversé deux fois.
3. **Les instruments sont des échantillons.** Une onde carrée de 16
   échantillons et un triangle de 32, en format BRR, bouclés à l'infini :
   le chiptune par échantillonnage. La voix 3 est configurée en BRUIT par
   le DSP — le canal percussions de la NES, retrouvé. Hauteur :
   `pitch = Hz × 2,048` (le la 440 vaut 901).
4. **Le moteur de musique n'a pas changé.** `maj_musique` est celui de la
   NES, note pour note ; seule la dernière ligne diffère : au lieu d'écrire
   des périodes dans les registres APU, on télégraphie un numéro de note
   au pilote. Les partitions sont identiques aux versions NES.

Et un piège d'assembleur vécu, conservé en commentaire dans `son.s` : les
tables `notes_pitch_lo`/`notes_pitch_hi` écrites en deux moitiés
entrelacées compilent très bien... et jouent n'importe quoi à partir de la
note 8. Une table se termine avant que la suivante ne commence !

## Exercices

1. **Le timbre** — notre carré BRR est un 50 % ; la mélodie NES de NOVA
   jouait en 25 %, plus fine. Dessinez l'échantillon (12 valeurs hautes,
   4 basses) et comparez à l'oreille.
2. **Une pluie de météores** — une 3e tuile de décor et le LFSR qui en
   sème quelques-unes : le ciel n'attend que ça.
3. **La parallaxe** — le mode 1 offre un BG2 4bpp inutilisé : un second
   champ d'étoiles qui défile à `defil >> 1`, et la profondeur apparaît.
4. **Le boss** — les sprites SNES vont jusqu'à 64×64 (OBSEL) : une vague 9
   avec un porte-drones géant, ça se tente.
