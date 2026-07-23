# 💎 CRISTAL-2026 — la fondation du mini-RPG (niveau 7, phase 1)

Une salle, un héros, un coffre, un cristal. C'est le plus petit jeu du
dépôt — et son plus grand bond en avant : tout ce qui suit est
indispensable à un jeu « à la Final Fantasy », et aucun de nos cinq jeux
précédents n'en avait eu besoin.

```bash
make          # → cristal.sfc (256 Ko, SRAM 8 Ko à pile)
```

Commandes : flèches pour marcher, **A** (la touche B sur SNES) devant le
coffre pour l'ouvrir, devant le cristal pour **sauvegarder**. Éteignez la
console. Rallumez : « CONTINUER » vous attend.

## Leçon 1 — la cartouche grandit : 256 Ko, huit banques

Nos jeux tenaient en 32 Ko : une seule banque, tout à portée d'un `lda`
absolu. Un RPG transporte des cartes, des dialogues, des monstres — alors
la cartouche s'étage ([snes.cfg](snes.cfg)) : le **code en banque 0** (les
vecteurs d'interruption doivent y vivre), les **données en banque $81**,
et six banques encore vides qui attendent les phases suivantes.

Pour aller lire là-haut, trois outils du 65816 :
- `lda f:salle,x` — l'**adressage long** : 24 bits, la banque dans
  l'instruction ;
- `lda [salle_ptr],y` — le **pointeur long** : 3 octets de page directe,
  le troisième est la banque (c'est lui qui lit la carte sous les pieds
  du héros) ;
- le **DMA n'a jamais été prisonnier** de la banque 0 : son registre
  `A1B0` reçoit la banque de la source (`lda #^gfx_bg`), et les
  graphismes partent de la banque $81 vers la VRAM sans détour.

## Leçon 2 — le 65816 en 16 bits, pour de vrai

Depuis le début du cours SNES nous restions en `sep #$30` : du 6502
déguisé. Un RPG compte l'or et les pas jusqu'à 65535 : voici `rep #$20`.

```asm
        rep #$20        ; l'accumulateur s'élargit...
        lda pas_lo      ; ...et lit pas_lo ET pas_hi d'un coup
        inc a
        sta pas_lo
        sep #$20        ; retour en 8 bits
```

Et `rep #$10` élargit les index : la salle fait 896 cases, la boucle de
dessin la parcourt avec un X de 16 bits. Deux pièges de console réelle,
vécus et commentés dans le source :
- **le registre B** : l'octet haut de l'accumulateur ne disparaît pas en
  mode 8 bits, il se cache. `tay` en index 16 bits le copie AUSSI — videz
  B avant, ou Y part dans le décor (voir `dessiner_salle`) ;
- **la NMI peut interrompre du code 16 bits** : son prologue sauve les
  registres en `rep #$30` avant de travailler en 8 bits (voir `nmi`).

## Leçon 3 — la division matérielle

Le 6502 ne savait ni multiplier ni diviser. La SNES a les deux, câblés :
dividende dans `$4204-$4205`, diviseur dans `$4206`, seize cycles de
patience (huit `nop`), et quotient + reste vous attendent. La routine
`decimal` convertit ainsi nos compteurs binaires en chiffres : divisez
par 10, le reste EST le chiffre des unités, recommencez avec le quotient.
Cinq tours, cinq chiffres — `PAS 00256` à l'écran.

## Leçon 4 — la sauvegarde (et pourquoi « données corrompues »)

La SRAM vit en `$70:0000`, déclarée dans l'en-tête de cartouche (type
`$02` : ROM + SRAM + **pile**). C'est de la RAM ordinaire qu'une pile
maintient en vie : le contenu survit à l'extinction... tant que la pile
tient. D'où le format de notre bloc de 16 octets :

```
"CR26"  version  x y direction  or(16b)  pas(16b)  coffre  (réservé)  somme(16b)
```

La **signature** distingue une vraie sauvegarde du bruit d'une SRAM
vierge ; la **somme de contrôle** détecte l'octet menteur d'une pile
fatiguée. Au démarrage, `verifier_sauvegarde` exige les deux — sinon,
pas de « CONTINUER ». Le test de la suite le prouve : un seul bit
inversé, et le menu redevient muet. Vous savez désormais qui parlait
quand une cartouche affichait « données corrompues ».

## Et aussi, au passage

- **`.charmap`** : l'assembleur traduit `"NOUVELLE PARTIE"` directement
  vers nos numéros de tuiles — fini les listes de constantes. (Avec un
  piège savoureux documenté dans le source : remapper `'A'` par une
  littérale `'A'`... se remappe soi-même.)
- **le héros 16×16** : quatre sprites, et la direction gauche n'est PAS
  dessinée — c'est le profil droit retourné par le bit de miroir OAM,
  colonnes échangées (voir `maj_sprites`).
- **`.repeat`** génère la table d'adresses des rangées de la salle, et
  `.assert` vérifie que le plan fait bien 896 cases : une virgule oubliée
  ne passe pas la compilation.

## Exercices

1. **Le marchand muet** — un second coffre : ajoutez ses tuiles au plan,
   son drapeau en page zéro... et dans la sauvegarde. Que se passe-t-il
   pour les VIEILLES sauvegardes ? (C'est à ça que sert l'octet version !)
2. **L'inflation** — le coffre donne 25 × votre nombre de pas : la
   **multiplication matérielle** (`$4202-$4203`) n'attend que vous.
3. **La porte** — une tuile de porte au sud, et franchir = recharger une
   AUTRE salle (une seconde carte en banque $81 : il y a la place).
   C'est le premier pas de la phase 2.
4. **Le vandale** — dans le simulateur, corrompez l'octet 14 (la somme
   elle-même) au lieu de l'octet 8. Que se passe-t-il ? Pourquoi ?

**Suite du chantier** : phase 2, la carte qui défile dans les quatre
directions, les PNJ et les événements. Puis le texte, puis le combat.
