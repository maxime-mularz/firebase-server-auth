; =============================================================================
;  CASSE-BRIQUE NES — l'assembleur 6502 pour les nuls
; =============================================================================
;
;  Un jeu de casse-brique complet pour la Nintendo NES, écrit en assembleur
;  6502, et commenté ligne par ligne dans un but pédagogique.
;
;  COMMENT LIRE CE FICHIER ?
;  -------------------------
;  L'assembleur, c'est le langage "brut" du processeur. Chaque ligne est UNE
;  instruction que le CPU exécute telle quelle. Il n'y a ni variables typées,
;  ni fonctions au sens moderne : seulement des registres, de la mémoire, et
;  des sauts.
;
;  Le 6502 (le CPU de la NES) possède 3 registres principaux :
;    A  : l'accumulateur. C'est la "main" du processeur : presque tous les
;         calculs passent par lui (additions, comparaisons...).
;    X  : un registre d'index, souvent utilisé comme compteur de boucle.
;    Y  : un second registre d'index, identique à X.
;
;  Les instructions que vous verrez le plus souvent :
;    LDA #10        charge la VALEUR 10 dans A          (LoaD A)
;    LDA $0300      charge le CONTENU de l'adresse $0300 dans A
;    STA $0300      range A à l'adresse $0300           (STore A)
;    ADC #2         additionne 2 à A                    (ADd with Carry)
;    SBC #2         soustrait 2 de A                    (SuBtract with Carry)
;    CMP #8         compare A avec 8 (positionne des "drapeaux")
;    BEQ la_bas     saute à l'étiquette si égal         (Branch if EQual)
;    BNE la_bas     saute si différent                  (Branch if Not Equal)
;    BCC / BCS      saute si inférieur / supérieur-ou-égal (comparaison non signée)
;    JMP la_bas     saut inconditionnel (un "goto")
;    JSR routine    appelle un sous-programme           (Jump to SubRoutine)
;    RTS            revient du sous-programme           (ReTurn from Subroutine)
;    INC / DEC      incrémente / décrémente une case mémoire
;    INX/DEX/INY/DEY pareil, mais pour X et Y
;
;  Le symbole # signifie "la valeur littérale". Sans #, c'est une adresse !
;    LDA #$20  → A = 0x20 (32)
;    LDA $20   → A = ce qui est stocké à l'adresse 0x20
;  C'est LE piège classique du débutant. :-)
;
;  Le préfixe $ signifie "en hexadécimal", % signifie "en binaire".
;    10 = $0A = %00001010
;
;  Les étiquettes qui commencent par @ sont des étiquettes "locales" à la
;  routine en cours : on peut réutiliser le même nom ailleurs sans conflit.
;
; =============================================================================
;  L'ARCHITECTURE DE LA NES EN BREF
; =============================================================================
;
;  La NES contient DEUX puces qui travaillent en parallèle :
;    - le CPU (6502) : exécute ce fichier ;
;    - le PPU (Picture Processing Unit) : dessine l'image, 60 fois/seconde.
;
;  Le CPU ne peut PAS écrire directement des pixels. Il parle au PPU à
;  travers quelques "registres" projetés en mémoire (adresses $2000-$2007).
;  Et il ne peut le faire sans casser l'image QUE pendant le "VBlank" :
;  le court instant où le canon à électrons de la télé remonte en haut de
;  l'écran. Le PPU nous prévient du VBlank en déclenchant une interruption
;  appelée NMI — notre routine `nmi` tout en bas est alors exécutée.
;
;  L'image est composée de :
;    - un FOND (background) : une grille de 32×30 tuiles de 8×8 pixels,
;      décrite dans la "nametable" (adresse PPU $2000). Nos BRIQUES et nos
;      MURS sont des tuiles de fond.
;    - des SPRITES : 64 petits objets de 8×8 pixels librement positionnables.
;      Notre BALLE (1 sprite) et notre RAQUETTE (3 sprites) en font partie.
;
; =============================================================================


; -----------------------------------------------------------------------------
;  CONSTANTES : les registres matériels de la NES
; -----------------------------------------------------------------------------
;  Une constante n'occupe aucune mémoire : l'assembleur remplace simplement
;  le nom par sa valeur. C'est juste pour rendre le code lisible.

PPUCTRL   = $2000   ; configuration du PPU (active la NMI, etc.)
PPUMASK   = $2001   ; active/désactive l'affichage du fond et des sprites
PPUSTATUS = $2002   ; état du PPU (le bit 7 passe à 1 pendant le VBlank)
OAMADDR   = $2003   ; adresse de départ dans la mémoire des sprites
PPUSCROLL = $2005   ; position de défilement de l'écran (x puis y)
PPUADDR   = $2006   ; adresse dans la mémoire vidéo (2 écritures : haut, bas)
PPUDATA   = $2007   ; lecture/écriture de la mémoire vidéo à cette adresse
OAMDMA    = $4014   ; copie express de 256 octets vers la mémoire des sprites
APUSTATUS = $4015   ; interrupteur général des canaux sonores
JOYPAD1   = $4016   ; lecture de la manette 1
APUFRAME  = $4017   ; horloge de l'APU

; --- Les registres du son : l'APU (Audio Processing Unit) --------------------
;  La NES possède une troisième puce (en fait logée dans le CPU) : l'APU,
;  avec 5 voix. Nous en utilisons 4 :
;    - CARRE 1 : une onde carrée → nos BRUITAGES (bips de rebond) ;
;    - CARRE 2 : une autre onde carrée → la MÉLODIE de la musique ;
;    - TRIANGLE : une onde douce, plus grave → la BASSE de la musique ;
;    - BRUIT : un souffle aléatoire → percussions et explosions.
;  Comme pour le PPU, on pilote tout par des registres. Pour chaque canal :
;  un registre de volume/timbre, et la "période" sur 2 registres (bas+haut).
;  ATTENTION, c'est contre-intuitif : la période est l'INVERSE de la
;  hauteur. Grande période = note grave, petite période = note aiguë.
CARRE1_VOL  = $4000 ; timbre + volume du carré 1
CARRE1_BAL  = $4001 ; "balayage" automatique de fréquence (on le neutralise)
CARRE1_BAS  = $4002 ; période, octet bas
CARRE1_HAUT = $4003 ; période, 3 bits hauts (+ compteur de durée matériel)
CARRE2_VOL  = $4004
CARRE2_BAL  = $4005
CARRE2_BAS  = $4006
CARRE2_HAUT = $4007
TRI_LIN     = $4008 ; compteur linéaire du triangle (sa "pédale" marche/arrêt)
TRI_BAS     = $400A
TRI_HAUT    = $400B
BRUIT_VOL   = $400C
BRUIT_PER   = $400E ; période du bruit : 0 = "tsss" aigu ... 15 = grondement
BRUIT_LON   = $400F

; --- Les boutons de la manette, tels qu'on les reçoit dans `boutons` ---------
BTN_A      = %10000000
BTN_B      = %01000000
BTN_SELECT = %00100000
BTN_START  = %00010000
BTN_HAUT   = %00001000
BTN_BAS    = %00000100
BTN_GAUCHE = %00000010
BTN_DROITE = %00000001

; --- Les numéros de nos tuiles (dessinées tout en bas, section CHR) ----------
TUILE_VIDE      = $00
TUILE_BRIQUE_G  = $01   ; moitié gauche d'une brique
TUILE_BRIQUE_D  = $02   ; moitié droite d'une brique
TUILE_MUR       = $03
TUILE_BALLE     = $04
TUILE_RAQ_G     = $05   ; bout gauche de la raquette
TUILE_RAQ_M     = $06   ; milieu de la raquette
TUILE_RAQ_D     = $07   ; bout droit de la raquette
TUILE_CHIFFRE_0 = $10   ; les chiffres 0-9 occupent les tuiles $10 à $19

; --- Les états du jeu ---------------------------------------------------------
ETAT_ATTENTE = 0    ; la balle est collée à la raquette, on attend A
ETAT_JEU     = 1    ; la balle est en mouvement
ETAT_FINI    = 2    ; victoire ou défaite, on attend Start

; --- Les notes de musique ------------------------------------------------------
;  Chaque note est un simple numéro, qui servira d'index dans les tables
;  notes_bas / notes_haut (près du moteur de musique, plus bas). Ces tables
;  contiennent la PÉRIODE de chaque note : période = 1 789 773 ÷ (16 × Hz) − 1
;  (1 789 773 Hz étant la cadence du CPU). Le la du diapason (440 Hz) donne
;  ainsi 253. Oui : votre console fait de la physique des ondes.
NOTE_SILENCE = 0
NOTE_FA2  = 1
NOTE_SOL2 = 2
NOTE_LA2  = 3
NOTE_DO3  = 4
NOTE_FA4  = 5
NOTE_SOL4 = 6
NOTE_LA4  = 7
NOTE_SI4  = 8
NOTE_DO5  = 9
NOTE_RE5  = 10
NOTE_MI5  = 11
NOTE_FA5  = 12
NOTE_SOL5 = 13
NOTE_LA5  = 14

; --- Géométrie du terrain (en pixels) -----------------------------------------
;  L'écran fait 256×240 pixels. Le mur du haut occupe la rangée de tuiles 3
;  (pixels 24-31), les murs latéraux les colonnes 0 et 31.
RAQUETTE_Y   = 208  ; ligne verticale (fixe) de la raquette
BALLE_X_MIN  = 8    ; contre le mur de gauche
BALLE_X_MAX  = 240  ; contre le mur de droite (la balle fait 8 px de large)
BALLE_Y_MIN  = 32   ; contre le mur du haut
BALLE_Y_PERDU = 232 ; en dessous, la balle est perdue !


; -----------------------------------------------------------------------------
;  VARIABLES en "page zéro"
; -----------------------------------------------------------------------------
;  La page zéro, ce sont les adresses $0000-$00FF : les 256 premiers octets
;  de la RAM. Le 6502 y accède plus vite qu'au reste de la mémoire, on y met
;  donc les variables utilisées tout le temps.
;  `.res 1` veut dire : "réserve 1 octet ici". Un octet = un nombre de 0 à 255.

.zeropage

boutons:           .res 1   ; état des 8 boutons de la manette (1 bit chacun)
image:             .res 1   ; compteur d'images, +1 à chaque VBlank (60/s)
etat:              .res 1   ; ETAT_ATTENTE, ETAT_JEU ou ETAT_FINI

balle_x:           .res 1   ; position de la balle (coin haut-gauche)
balle_y:           .res 1
balle_dx:          .res 1   ; vitesse horizontale : +2 ou -2 ($FE)
balle_dy:          .res 1   ; vitesse verticale   : +2 ou -2 ($FE)
                            ; NB : -2 s'écrit $FE car sur un octet, les
                            ; nombres négatifs "bouclent" (256-2 = 254 = $FE).
                            ; C'est le "complément à deux".

raquette_x:        .res 1   ; bord gauche de la raquette (24 px de large)

vies:              .res 1
score_u:           .res 1   ; score, chiffre des unités  (0-9)
score_d:           .res 1   ; ... des dizaines
score_c:           .res 1   ; ... des centaines
briques_restantes: .res 1   ; quand il atteint 0 → gagné !

; File d'attente pour effacer une brique à l'écran : le jeu (hors VBlank) ne
; peut pas toucher à la mémoire vidéo, alors il note ici l'adresse de la
; brique cassée, et la routine `nmi` fera l'effacement au prochain VBlank.
effacer_actif:     .res 1   ; 1 = il y a une brique à effacer
effacer_hi:        .res 1   ; adresse vidéo de la brique (octet haut)
effacer_lo:        .res 1   ; ... (octet bas)

; Petites variables de travail pour les calculs de collision
col_tuile:         .res 1   ; colonne de tuile (0-31) où se trouve la balle
lig_tuile:         .res 1   ; rangée de tuile (0-29)
col_brique:        .res 1   ; colonne dans la grille de briques (0-14)
lig_brique:        .res 1   ; rangée dans la grille de briques (0-5)

; Adresses de travail pour dessiner le décor
adr_lo:            .res 1
adr_hi:            .res 1
tmp_lo:            .res 1
tmp_hi:            .res 1

; Le moteur de musique : où en est-on dans la partition ?
mus_active:        .res 1   ; 1 = la musique joue
mel_pos:           .res 1   ; position dans la table `melodie`
mel_cpt:           .res 1   ; images restantes avant la prochaine note
bas_pos:           .res 1   ; position dans la table `basse`
bas_cpt:           .res 1
; Les bruitages : combien d'images avant de couper le son ?
bip_cpt:           .res 1   ; pour le canal carré 1
bruit_cpt:         .res 1   ; pour le canal de bruit


; -----------------------------------------------------------------------------
;  VARIABLES en RAM ordinaire
; -----------------------------------------------------------------------------
;  La grille logique des briques : 6 rangées de 15 briques. On réserve 16
;  cases par rangée (au lieu de 15) car multiplier par 16 est très facile en
;  assembleur (4 décalages à gauche), alors que multiplier par 15 est pénible.
;  1 = brique présente, 0 = brique cassée.
;
;  NB : la mémoire $0200-$02FF est réservée à notre "brouillon" de sprites
;  (voir maj_sprites), c'est pourquoi cette grille est placée à partir de $0300
;  (voir le fichier nes.cfg).

.bss

grille: .res 96   ; 6 rangées × 16 colonnes


; =============================================================================
;  L'EN-TÊTE iNES
; =============================================================================
;  Les 16 premiers octets du fichier .nes ne sont pas lus par la console :
;  ils décrivent la cartouche à l'émulateur (taille de la ROM, etc.).

.segment "HEADER"
        .byte 'N', 'E', 'S', $1A   ; signature obligatoire
        .byte 2                    ; 2 blocs de 16 Ko de code (PRG-ROM)
        .byte 1                    ; 1 bloc de 8 Ko de graphismes (CHR-ROM)
        .byte $01                  ; miroir vertical (sans importance ici)
        .byte $00
        .byte 0,0,0,0,0,0,0,0      ; le reste est inutilisé


; =============================================================================
;  LE CODE
; =============================================================================
.segment "CODE"

; -----------------------------------------------------------------------------
;  RESET : le point de départ
; -----------------------------------------------------------------------------
;  À l'allumage (ou au redémarrage), la console saute ici (grâce au "vecteur"
;  déclaré tout en bas du fichier). On doit d'abord initialiser le matériel :
;  c'est un rituel quasi identique dans tous les jeux NES.

reset:
        sei                     ; ignore les interruptions pendant l'init
        cld                     ; désactive le mode décimal (inexistant sur NES)
        ldx #$40
        stx APUFRAME            ; coupe les interruptions de l'horloge son
        ldx #$FF
        txs                     ; initialise le pointeur de pile à $01FF
        inx                     ; X passe de $FF à $00 (il "boucle")
        stx PPUCTRL             ; NMI désactivée pour l'instant
        stx PPUMASK             ; affichage coupé
        stx $4010               ; canal sonore DMC coupé

        ; Le PPU met ~2 images à démarrer. On attend deux VBlank complets.
        ; BIT lit PPUSTATUS : le bit 7 (le signe) indique le VBlank.
        ; BPL = "Branch if PLus" = saute tant que le bit 7 vaut 0.
        bit PPUSTATUS           ; première lecture pour partir d'un état connu
@attente_vblank_1:
        bit PPUSTATUS
        bpl @attente_vblank_1

        ; Pendant l'attente du 2e VBlank, on met toute la RAM à zéro.
        ; La zone $0200-$02FF (le brouillon des sprites) est remplie de $FF :
        ; un sprite dont le Y vaut $FF est hors écran, donc invisible.
        lda #0
@vider_ram:
        sta $0000, x            ; "adresse + X" : X sert d'index, de 0 à 255
        sta $0100, x
        sta $0300, x
        sta $0400, x
        sta $0500, x
        sta $0600, x
        sta $0700, x
        lda #$FF
        sta $0200, x            ; sprites hors écran
        lda #0
        inx
        bne @vider_ram          ; X reboucle à 0 après 255 → fin de la boucle

@attente_vblank_2:
        bit PPUSTATUS
        bpl @attente_vblank_2

        ; Le PPU est prêt. L'affichage est encore coupé : on peut remplir
        ; tranquillement la mémoire vidéo.
        jsr charger_palettes
        jsr dessiner_decor
        jsr preparer_partie

        ; On ouvre les 4 robinets du son (1 bit par canal)...
        lda #%00001111          ; bruit + triangle + carré 2 + carré 1
        sta APUSTATUS
        jsr demarrer_musique    ; ...et en musique !

        ; Remet le défilement de l'écran à (0,0) — écrire dans PPUADDR l'a
        ; déréglé — puis allume tout.
        bit PPUSTATUS           ; réarme la bascule interne du PPU
        lda #0
        sta PPUSCROLL           ; défilement horizontal = 0
        sta PPUSCROLL           ; défilement vertical = 0
        lda #%10000000          ; bit 7 : déclenche la NMI à chaque VBlank
        sta PPUCTRL
        lda #%00011110          ; montre le fond + les sprites, partout
        sta PPUMASK
        jmp principale


; -----------------------------------------------------------------------------
;  preparer_partie : valeurs de départ d'une nouvelle partie
; -----------------------------------------------------------------------------
preparer_partie:
        lda #3
        sta vies
        lda #0
        sta score_u
        sta score_d
        sta score_c
        sta effacer_actif
        sta image
        lda #ETAT_ATTENTE
        sta etat
        lda #116                ; raquette au centre : (256-24)/2 ≈ 116
        sta raquette_x
        lda #90                 ; 6 rangées × 15 briques
        sta briques_restantes

        ; Remplit la grille logique : d'abord tout à 1...
        ldx #95
        lda #1
@remplir:
        sta grille, x
        dex
        bpl @remplir            ; BPL : boucle tant que X ≥ 0

        ; ...puis on remet à 0 la 16e colonne de chaque rangée (les cases
        ; 15, 31, 47... qui n'existent que pour faciliter les calculs).
        ldx #15
@vider_colonne_fantome:
        lda #0                  ; attention : recharger 0 à CHAQUE tour, car
        sta grille, x           ; le TXA ci-dessous écrase A !
        txa                     ; transfère X dans A pour pouvoir additionner
        clc                     ; toujours mettre la retenue à 0 avant ADC !
        adc #16
        tax                     ; et on remet le résultat dans X
        cpx #96
        bcc @vider_colonne_fantome
        rts


; -----------------------------------------------------------------------------
;  charger_palettes : les couleurs
; -----------------------------------------------------------------------------
;  La NES ne connaît que 64 couleurs prédéfinies (numérotées $00-$3F).
;  On en choisit quelques-unes et on les range dans la mémoire des palettes
;  du PPU, à l'adresse vidéo $3F00.
;
;  Pour écrire en mémoire vidéo : on donne l'adresse en 2 fois dans PPUADDR
;  (octet haut puis octet bas), puis chaque écriture dans PPUDATA écrit un
;  octet ET avance automatiquement à l'adresse suivante.

charger_palettes:
        bit PPUSTATUS           ; réarme la bascule haut/bas de PPUADDR
        lda #$3F
        sta PPUADDR
        lda #$00
        sta PPUADDR             ; adresse vidéo = $3F00
        ldx #0
@copier:
        lda palettes, x         ; lit la table `palettes` (plus bas) + X
        sta PPUDATA
        inx
        cpx #32                 ; 32 octets : 4 palettes de fond + 4 de sprites
        bne @copier
        rts

palettes:
        ; --- 4 palettes de FOND (chacune : fond, couleur 1, 2, 3) ---
        .byte $0F, $27, $10, $30   ; noir, orange (briques), gris (murs), blanc (chiffres)
        .byte $0F, $0F, $0F, $0F   ; inutilisée
        .byte $0F, $0F, $0F, $0F   ; inutilisée
        .byte $0F, $0F, $0F, $0F   ; inutilisée
        ; --- 4 palettes de SPRITES ---
        .byte $0F, $30, $00, $0F   ; palette 0 : balle blanche
        .byte $0F, $00, $21, $0F   ; palette 1 : raquette bleue
        .byte $0F, $0F, $0F, $0F   ; inutilisée
        .byte $0F, $0F, $0F, $0F   ; inutilisée


; -----------------------------------------------------------------------------
;  dessiner_decor : remplit la nametable (murs + briques)
; -----------------------------------------------------------------------------
;  La nametable ($2000-$23BF en mémoire vidéo) est la grille de 32×30 numéros
;  de tuiles qui compose le fond. L'adresse d'une tuile se calcule ainsi :
;      adresse = $2000 + rangée × 32 + colonne

dessiner_decor:
        ; --- 1) Tout vider : 960 tuiles + 64 octets d'attributs = 1024 octets
        bit PPUSTATUS
        lda #$20
        sta PPUADDR
        lda #$00
        sta PPUADDR             ; adresse vidéo = $2000
        ldx #4                  ; 4 paquets...
        ldy #0                  ; ...de 256 octets = 1024
        lda #TUILE_VIDE
@vider:
        sta PPUDATA
        iny
        bne @vider              ; boucle intérieure : 256 tours
        dex
        bne @vider              ; boucle extérieure : 4 tours
        ; (les 64 derniers octets sont la "table d'attributs" : des zéros
        ;  signifient "tout le fond utilise la palette 0" — parfait pour nous)

        ; --- 2) Le mur du haut : 32 tuiles sur la rangée 3 ($2060) ---
        bit PPUSTATUS
        lda #$20
        sta PPUADDR
        lda #$60
        sta PPUADDR
        ldx #32
        lda #TUILE_MUR
@mur_haut:
        sta PPUDATA
        dex
        bne @mur_haut

        ; --- 3) Les murs latéraux : colonnes 0 et 31, rangées 4 à 29 ---
        ;  Les adresses dépassent 255, il faut donc calculer sur 16 bits...
        ;  avec un processeur 8 bits ! Recette : on traite l'octet bas puis
        ;  l'octet haut, en propageant la retenue (le carry) entre les deux.
        lda #$20
        sta adr_hi
        lda #$80                ; $2080 = rangée 4, colonne 0
        sta adr_lo
        ldx #26                 ; 26 rangées (de la 4 à la 29)
@murs_lateraux:
        bit PPUSTATUS
        lda adr_hi
        sta PPUADDR
        lda adr_lo
        sta PPUADDR
        lda #TUILE_MUR
        sta PPUDATA             ; tuile de la colonne 0

        lda adr_lo              ; adresse de la colonne 31 = adresse + 31
        clc
        adc #31
        sta tmp_lo
        lda adr_hi
        adc #0                  ; ajoute juste la retenue éventuelle
        sta tmp_hi
        lda tmp_hi
        sta PPUADDR
        lda tmp_lo
        sta PPUADDR
        lda #TUILE_MUR
        sta PPUDATA             ; tuile de la colonne 31

        lda adr_lo              ; rangée suivante : adresse += 32
        clc
        adc #32
        sta adr_lo
        lda adr_hi
        adc #0
        sta adr_hi
        dex
        bne @murs_lateraux

        ; --- 4) Les briques : 6 rangées de 15 briques de 2 tuiles ---
        ldy #0                  ; Y = numéro de rangée de briques (0-5)
@rangee_briques:
        bit PPUSTATUS
        lda lignes_briques_hi, y
        sta PPUADDR
        lda lignes_briques_lo, y
        clc
        adc #1                  ; +1 : on commence à la colonne 1 (après le mur)
        sta PPUADDR
        ldx #15                 ; 15 briques par rangée
@une_brique:
        lda #TUILE_BRIQUE_G
        sta PPUDATA
        lda #TUILE_BRIQUE_D
        sta PPUDATA
        dex
        bne @une_brique
        iny
        cpy #6
        bne @rangee_briques
        rts

; Adresses vidéo du début (colonne 0) des 6 rangées de briques.
; Rangée de tuiles 5 → $2000 + 5×32 = $20A0, etc.
; Deux tables séparées (octets bas / octets hauts) car le 6502 ne sait lire
; qu'un octet à la fois.
lignes_briques_lo:  .byte $A0, $C0, $E0, $00, $20, $40
lignes_briques_hi:  .byte $20, $20, $20, $21, $21, $21


; =============================================================================
;  LA BOUCLE PRINCIPALE
; =============================================================================
;  Le cœur du jeu. À chaque image (1/60e de seconde) :
;    1. attendre le signal du VBlank (donné par la routine nmi) ;
;    2. lire la manette ;
;    3. faire la logique du jeu (déplacer, tester les collisions...) ;
;    4. mettre à jour le brouillon des sprites.
;  Puis on recommence, pour toujours. Un jeu, c'est une boucle infinie !

principale:
        jsr attendre_nmi
        jsr maj_musique         ; le son se met à jour à CHAQUE image, comme
        jsr maj_bruitages       ; l'image elle-même : c'est ce qui donne un
        jsr lire_manette        ; tempo parfaitement stable (60 Hz)
        jsr maj_raquette

        lda etat
        cmp #ETAT_JEU
        beq @en_jeu
        cmp #ETAT_ATTENTE
        beq @en_attente

        ; --- État FINI (gagné ou perdu) : on attend le bouton Start --------
        lda boutons
        and #BTN_START          ; AND isole le bit du bouton Start :
        beq @dessiner           ; résultat nul = bouton relâché
        jmp reset               ; on relance toute la console. Radical !

@en_attente:
        ; --- La balle est collée au centre de la raquette ------------------
        lda raquette_x
        clc
        adc #8                  ; raquette 24 px, balle 8 px → décalage de 8
        sta balle_x
        lda #RAQUETTE_Y - 8     ; juste au-dessus de la raquette
        sta balle_y

        lda boutons
        and #BTN_A
        beq @dessiner           ; A pas pressé → on reste collé
        ; A pressé : on lance la balle !
        lda #ETAT_JEU
        sta etat
        jsr bip_raquette        ; petit "top" de départ
        lda #$FE                ; vers le haut (-2)
        sta balle_dy
        lda #2                  ; vers la droite (+2)...
        sta balle_dx
        lda image               ; ...sauf une image sur deux : le bit 0 du
        and #1                  ; compteur d'images sert de pile-ou-face
        beq @dessiner
        lda #$FE                ; vers la gauche (-2)
        sta balle_dx
        jmp @dessiner

@en_jeu:
        jsr deplacer_balle

@dessiner:
        jsr maj_sprites
        jmp principale          ; et on recommence, à jamais


; -----------------------------------------------------------------------------
;  attendre_nmi : se synchroniser sur le VBlank
; -----------------------------------------------------------------------------
;  La routine nmi (en bas) incrémente `image` à chaque VBlank. On mémorise sa
;  valeur, puis on tourne en rond tant qu'elle n'a pas changé. Cela garantit
;  que la boucle principale tourne exactement 60 fois par seconde.

attendre_nmi:
        lda image
@patienter:
        cmp image
        beq @patienter          ; tant que image n'a pas bougé, on attend
        rts


; -----------------------------------------------------------------------------
;  lire_manette : récupère l'état des 8 boutons
; -----------------------------------------------------------------------------
;  La manette NES est un "registre à décalage" : après un signal de verrouillage
;  (écrire 1 puis 0 dans $4016), chaque lecture de $4016 donne UN bouton dans
;  le bit 0, dans l'ordre : A, B, Select, Start, Haut, Bas, Gauche, Droite.
;
;  L'astuce LSR/ROL : LSR pousse le bit 0 (le bouton lu) dans la retenue,
;  puis ROL fait entrer cette retenue par la droite de `boutons`. Après 8
;  tours, les 8 boutons sont rangés dans l'octet, le bouton A en tête.

lire_manette:
        lda #1
        sta JOYPAD1             ; verrouille l'état des boutons...
        lda #0
        sta JOYPAD1             ; ...et passe en mode lecture
        ldx #8
@bouton_suivant:
        lda JOYPAD1
        lsr a                   ; bit 0 → retenue
        rol boutons             ; retenue → bit 0 de `boutons` (tout glisse à gauche)
        dex
        bne @bouton_suivant
        rts


; -----------------------------------------------------------------------------
;  maj_raquette : déplace la raquette selon la croix directionnelle
; -----------------------------------------------------------------------------
maj_raquette:
        lda boutons
        and #BTN_GAUCHE
        beq @pas_a_gauche
        lda raquette_x
        sec                     ; toujours mettre la retenue à 1 avant SBC !
        sbc #2                  ; (SEC est à SBC ce que CLC est à ADC)
        sta raquette_x
        cmp #8                  ; a-t-on dépassé le mur de gauche ?
        bcs @pas_a_gauche
        lda #8
        sta raquette_x          ; oui → on colle au mur
@pas_a_gauche:
        lda boutons
        and #BTN_DROITE
        beq @pas_a_droite
        lda raquette_x
        clc
        adc #2
        sta raquette_x
        cmp #225                ; 224 est le maximum (224 + 24 px = mur droit)
        bcc @pas_a_droite
        lda #224
        sta raquette_x
@pas_a_droite:
        rts


; -----------------------------------------------------------------------------
;  deplacer_balle : mouvement + rebonds sur les murs
; -----------------------------------------------------------------------------
deplacer_balle:
        ; --- Axe horizontal -------------------------------------------------
        lda balle_x
        clc
        adc balle_dx            ; additionner $FE revient à soustraire 2 :
        sta balle_x             ; la magie du complément à deux !
        cmp #BALLE_X_MIN
        bcs @pas_mur_gauche     ; BCS : "supérieur ou égal" → pas touché
        lda #BALLE_X_MIN
        sta balle_x
        lda #2                  ; rebond : on repart vers la droite
        sta balle_dx
        jsr bip_mur
@pas_mur_gauche:
        lda balle_x
        cmp #BALLE_X_MAX + 1
        bcc @pas_mur_droit      ; BCC : "strictement inférieur" → pas touché
        lda #BALLE_X_MAX
        sta balle_x
        lda #$FE                ; rebond : on repart vers la gauche
        sta balle_dx
        jsr bip_mur
@pas_mur_droit:

        ; --- Axe vertical ---------------------------------------------------
        lda balle_y
        clc
        adc balle_dy
        sta balle_y
        cmp #BALLE_Y_MIN
        bcs @pas_mur_haut
        lda #BALLE_Y_MIN
        sta balle_y
        lda #2                  ; rebond : on repart vers le bas
        sta balle_dy
        jsr bip_mur
@pas_mur_haut:
        lda balle_y
        cmp #BALLE_Y_PERDU
        bcc @pas_perdue
        jmp perdre_vie          ; la balle est tombée ! (le RTS de perdre_vie
                                ; nous fera revenir directement à l'appelant)
@pas_perdue:
        jsr collision_briques
        jsr collision_raquette
        rts


; -----------------------------------------------------------------------------
;  collision_briques : la balle touche-t-elle une brique ?
; -----------------------------------------------------------------------------
;  Principe : on convertit la position de la balle (en pixels) en coordonnées
;  de tuile (division par 8), puis en coordonnées dans notre grille logique.
;  Si la case de la grille contient un 1 : boum, on casse la brique.
;
;  Diviser par 8, c'est décaler 3 fois vers la droite (LSR), car chaque
;  décalage divise par 2. De même, multiplier par 16 = 4 décalages à gauche.
;  Les puissances de 2 sont les meilleures amies de l'assembleur.

collision_briques:
        lda balle_x
        clc
        adc #4                  ; +4 : on teste le CENTRE de la balle
        lsr a
        lsr a
        lsr a                   ; ÷8 → numéro de colonne de tuile (0-31)
        sta col_tuile
        lda balle_y
        clc
        adc #4
        lsr a
        lsr a
        lsr a
        sta lig_tuile

        ; La balle est-elle dans la zone des briques (rangées de tuiles 5-10) ?
        lda lig_tuile
        sec
        sbc #5
        cmp #6
        bcs @rien               ; hors zone (l'astuce : si lig_tuile < 5, la
        sta lig_brique          ; soustraction "boucle" vers 250+, donc ≥ 6)

        ; ... et entre les murs (colonnes de tuiles 1-30) ?
        lda col_tuile
        beq @rien               ; colonne 0 = mur gauche
        cmp #31
        bcs @rien               ; colonne 31 = mur droit
        sec
        sbc #1
        lsr a                   ; ÷2 : chaque brique fait 2 tuiles de large
        sta col_brique

        ; Position dans la grille : index = rangée × 16 + colonne
        lda lig_brique
        asl a
        asl a
        asl a
        asl a                   ; ×16
        clc
        adc col_brique
        tax
        lda grille, x
        beq @rien               ; 0 = pas de brique ici → rien à faire

        ; --- BOUM ! On casse la brique --------------------------------------
        lda #0
        sta grille, x           ; retirée de la grille logique

        lda balle_dy            ; rebond : on inverse la vitesse verticale.
        eor #$FF                ; inverser tous les bits puis ajouter 1 :
        clc                     ; c'est comme ça qu'on calcule "moins A"
        adc #1                  ; en complément à deux (-2 ↔ +2)
        sta balle_dy

        jsr incrementer_score
        jsr bip_brique          ; "cling !"

        dec briques_restantes
        bne @pas_gagne
        lda #ETAT_FINI          ; plus une seule brique : GAGNÉ !
        sta etat
        jsr arreter_musique
        jsr bip_victoire
@pas_gagne:

        ; On note l'adresse vidéo de la brique pour que la routine nmi
        ; l'efface de l'écran au prochain VBlank.
        lda col_brique
        asl a                   ; ×2 : colonne de tuile relative
        clc
        adc #1                  ; +1 : décalage du mur de gauche
        ldy lig_brique
        clc
        adc lignes_briques_lo, y
        sta effacer_lo          ; (pas de retenue possible : chaque rangée
        lda lignes_briques_hi, y ; commence à un multiple de 32 et on ajoute
        sta effacer_hi          ; au plus 29)
        lda #1
        sta effacer_actif
@rien:
        rts


; -----------------------------------------------------------------------------
;  collision_raquette : la balle rebondit-elle sur la raquette ?
; -----------------------------------------------------------------------------
collision_raquette:
        lda balle_dy
        bmi @rate               ; BMI : si dy est négatif (balle qui monte),
                                ; inutile de tester — on ne rebondit qu'en
                                ; descendant, sinon la balle resterait collée

        lda balle_y             ; la balle est-elle à hauteur de raquette ?
        cmp #RAQUETTE_Y - 8     ; (bas de la balle = balle_y + 8)
        bcc @rate               ; trop haut
        cmp #RAQUETTE_Y
        bcs @rate               ; trop bas, déjà passée

        ; Test de chevauchement horizontal, version astucieuse : on calcule
        ; (balle_x - raquette_x + 7). Si le résultat est entre 0 et 30, les
        ; deux se touchent. Un seul CMP au lieu de deux comparaisons !
        lda balle_x
        sec
        sbc raquette_x
        clc
        adc #7
        cmp #31
        bcs @rate

        ; --- Touché ! La moitié de raquette frappée décide de la direction --
        cmp #15                 ; A contient toujours la position d'impact
        bcc @vers_la_gauche
        lda #2                  ; moitié droite → la balle part à droite
        sta balle_dx
        jmp @rebondir
@vers_la_gauche:
        lda #$FE                ; moitié gauche → la balle part à gauche
        sta balle_dx
@rebondir:
        lda #$FE                ; et dans tous les cas, on remonte !
        sta balle_dy
        jsr bip_raquette
@rate:
        rts


; -----------------------------------------------------------------------------
;  perdre_vie
; -----------------------------------------------------------------------------
perdre_vie:
        dec vies
        beq @plus_de_vies
        lda #ETAT_ATTENTE       ; il reste des vies : la balle revient se
        sta etat                ; coller à la raquette
        jmp bruit_vie           ; "pshh" de dépit (son rts nous fera revenir)
@plus_de_vies:
        lda #ETAT_FINI
        sta etat
        lda #$F0                ; cache la balle sous le bas de l'écran
        sta balle_y
        jsr arreter_musique     ; silence, défaite...
        jmp bruit_fin           ; ...et long grondement (son rts conclura)


; -----------------------------------------------------------------------------
;  incrementer_score : +1 en "décimal", chiffre par chiffre
; -----------------------------------------------------------------------------
;  On stocke chaque chiffre séparément (unités, dizaines, centaines) : c'est
;  plus simple à afficher, et l'addition avec retenue se fait à la main,
;  comme à l'école primaire !

incrementer_score:
        inc score_u
        lda score_u
        cmp #10
        bne @fini
        lda #0
        sta score_u
        inc score_d             ; 9 → 0, et on retient 1...
        lda score_d
        cmp #10
        bne @fini
        lda #0
        sta score_d
        inc score_c
@fini:
        rts


; =============================================================================
;  LE SON — un juke-box en 6502
; =============================================================================
;  Le principe est le même que pour l'image : l'APU ne "joue" pas une
;  chanson tout seul, il tient une note tant qu'on ne lui dit rien. C'est
;  donc NOUS qui, à chaque image (60 fois/seconde), décomptons la durée de
;  la note en cours et envoyons la suivante quand c'est l'heure. Une
;  partition n'est qu'une suite d'octets : note, durée, note, durée...
;
;  Notre orchestre :  carré 2 = la mélodie,  triangle = la basse,
;                     carré 1 = les bips,    bruit = les percussions/chocs.

; -----------------------------------------------------------------------------
;  demarrer_musique / arreter_musique
; -----------------------------------------------------------------------------
demarrer_musique:
        lda #1
        sta mus_active
        sta mel_cpt             ; "1 image restante" : la première note
        sta bas_cpt             ; partira dès la prochaine mise à jour
        lda #0
        sta mel_pos
        sta bas_pos
        rts

arreter_musique:
        lda #0
        sta mus_active
        lda #%00110000          ; volume 0 sur la mélodie...
        sta CARRE2_VOL
        lda #%10000000          ; ...et compteur linéaire à 0 : le triangle
        sta TRI_LIN             ; se taira tout seul
        rts

; -----------------------------------------------------------------------------
;  maj_musique — appelée à chaque image : fait avancer la partition
; -----------------------------------------------------------------------------
maj_musique:
        lda mus_active
        bne @active
        rts
@active:
        ; ---------- la MÉLODIE, sur le canal carré 2 ----------
        dec mel_cpt
        bne @basse              ; la note en cours n'est pas finie
        ldx mel_pos
        lda melodie, x
        cmp #$FF                ; $FF = fin de la partition...
        bne @note_lue
        ldx #0                  ; ...alors on reprend au début : la boucle !
        lda melodie, x
@note_lue:
        beq @soupir             ; note 0 = un silence
        tay                     ; Y = numéro de la note
        lda #%10110110          ; timbre : onde carrée 50 %, volume 6
        sta CARRE2_VOL          ;   (les 2 bits du haut = le "duty" : la
        lda #$08                ;    forme de l'onde, donc le timbre !)
        sta CARRE2_BAL          ; balayage neutralisé (sinon il coupe les graves)
        lda notes_bas, y        ; la période de la note, octet bas...
        sta CARRE2_BAS
        lda notes_haut, y       ; ...et octet haut
        ora #%11111000
        sta CARRE2_HAUT
        jmp @duree
@soupir:
        lda #%00110000          ; volume 0 = chut
        sta CARRE2_VOL
@duree:
        inx
        lda melodie, x          ; l'octet suivant est la durée en images
        sta mel_cpt
        inx
        stx mel_pos

@basse:
        ; ---------- la BASSE, sur le canal triangle ----------
        dec bas_cpt
        bne @fin
        ldx bas_pos
        lda basse, x
        cmp #$FF
        bne @basse_lue
        ldx #0
        lda basse, x
@basse_lue:
        tay
        lda #%11111111          ; compteur linéaire au maximum : joue !
        sta TRI_LIN             ; (le triangle n'a pas de volume : il est
        lda notes_bas, y        ;  toujours à fond, doux et rond)
        sta TRI_BAS
        lda notes_haut, y
        ora #%11111000
        sta TRI_HAUT
        inx
        lda basse, x
        sta bas_cpt
        inx
        stx bas_pos
@fin:
        rts

; -----------------------------------------------------------------------------
;  LA PARTITION — modifiez-la, c'est fait pour !
; -----------------------------------------------------------------------------
;  Format : note, durée (en images ; 12 images ≈ une croche allègre), ...
;  et $FF pour boucler. Quatre mesures sur l'enchaînement do / la mineur /
;  fa / sol : le "I-vi-IV-V", l'accord secret de la moitié des tubes.

melodie:
        .byte NOTE_DO5,  12, NOTE_MI5, 12, NOTE_SOL5, 12, NOTE_MI5, 12
        .byte NOTE_LA4,  12, NOTE_DO5, 12, NOTE_MI5,  12, NOTE_DO5, 12
        .byte NOTE_FA4,  12, NOTE_LA4, 12, NOTE_DO5,  12, NOTE_LA4, 12
        .byte NOTE_SOL4, 12, NOTE_SI4, 12, NOTE_RE5,  12, NOTE_SI4, 12
        .byte $FF

basse:
        .byte NOTE_DO3, 48, NOTE_LA2, 48, NOTE_FA2, 48, NOTE_SOL2, 48
        .byte $FF

; Les périodes des notes (voir la formule près des constantes NOTE_*).
; L'index 0 est le silence : jamais lu, mais il cale les tables.
;                 sil  fa2  sol2 la2  do3  fa4  sol4 la4  si4  do5  ré5  mi5  fa5  sol5 la5
notes_bas:  .byte $00, $00, $74, $F8, $56, $3F, $1C, $FD, $E1, $D5, $BD, $A9, $9F, $8E, $7E
notes_haut: .byte $00, $05, $04, $03, $03, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00

; -----------------------------------------------------------------------------
;  LES BRUITAGES
; -----------------------------------------------------------------------------
;  Un bruitage, c'est : régler un canal, noter une durée, et maj_bruitages
;  coupera le son quand elle sera écoulée. Le canal carré 1 fait les bips
;  (chaque événement a sa hauteur : plus c'est important, plus c'est aigu),
;  le canal de bruit fait les catastrophes.

; A = période octet bas, X = période octet haut, Y = durée en images
jouer_bip:
        sta CARRE1_BAS
        txa
        ora #%11111000
        sta CARRE1_HAUT
        lda #%10111010          ; onde carrée 50 %, volume 10
        sta CARRE1_VOL
        lda #$08
        sta CARRE1_BAL
        sty bip_cpt
        rts

; A = période du bruit (0 = aigu ... 15 = grave), Y = durée en images
jouer_bruit:
        sta BRUIT_PER
        lda #%00111010          ; volume 10
        sta BRUIT_VOL
        lda #%11111000
        sta BRUIT_LON           ; déclenche le canal
        sty bruit_cpt
        rts

maj_bruitages:
        lda bip_cpt
        beq @bruit              ; pas de bip en cours
        dec bip_cpt
        bne @bruit              ; toujours en cours
        lda #%00110000          ; fini : volume 0
        sta CARRE1_VOL
@bruit:
        lda bruit_cpt
        beq @fin
        dec bruit_cpt
        bne @fin
        lda #%00110000
        sta BRUIT_VOL
@fin:
        rts

; Le "catalogue" : un petit réglage par événement du jeu.
bip_mur:                        ; toc discret, médium
        lda #$1C
        ldx #$01                ; période $011C = sol4
        ldy #3
        jmp jouer_bip
bip_raquette:                   ; ponk plus haut
        lda #$FD
        ldx #$00                ; période $00FD = la4
        ldy #4
        jmp jouer_bip
bip_brique:                     ; cling ! aigu
        lda #$6A
        ldx #$00                ; période $006A ≈ do6
        ldy #4
        jmp jouer_bip
bip_victoire:                   ; une grande note claire
        lda #$7E
        ldx #$00                ; période $007E = la5
        ldy #40
        jmp jouer_bip
bruit_vie:                      ; "pshh" : une vie s'envole
        lda #$0A
        ldy #20
        jmp jouer_bruit
bruit_fin:                      ; long grondement de game over
        lda #$0C
        ldy #45
        jmp jouer_bruit


; -----------------------------------------------------------------------------
;  maj_sprites : remplit le "brouillon" des sprites en RAM ($0200-$02FF)
; -----------------------------------------------------------------------------
;  Chaque sprite occupe 4 octets : Y, numéro de tuile, attributs, X.
;  (Attributs : les 2 bits du bas choisissent la palette de sprite.)
;  On écrit dans la RAM ordinaire, et la routine nmi enverra le tout au PPU
;  d'un seul coup grâce au DMA. Petit détail matériel : le PPU affiche les
;  sprites une ligne plus bas que leur Y — à notre échelle, on l'ignore.

maj_sprites:
        ; --- Sprite 0 : la balle -----------------------------------------
        lda balle_y
        sta $0200               ; Y
        lda #TUILE_BALLE
        sta $0201               ; tuile
        lda #0
        sta $0202               ; attributs : palette de sprite 0
        lda balle_x
        sta $0203               ; X

        ; --- Sprites 1 à 3 : la raquette (3 morceaux de 8 px) -------------
        lda #RAQUETTE_Y
        sta $0204
        sta $0208
        sta $020C
        lda #TUILE_RAQ_G
        sta $0205
        lda #TUILE_RAQ_M
        sta $0209
        lda #TUILE_RAQ_D
        sta $020D
        lda #1                  ; attributs : palette de sprite 1 (bleu)
        sta $0206
        sta $020A
        sta $020E
        lda raquette_x
        sta $0207
        clc
        adc #8
        sta $020B
        clc
        adc #8
        sta $020F
        rts


; =============================================================================
;  NMI : exécutée automatiquement à CHAQUE VBlank (60 fois par seconde)
; =============================================================================
;  C'est le SEUL moment où l'on peut toucher à la mémoire vidéo sans abîmer
;  l'image. On fait donc ici, et seulement ici :
;    - l'envoi du brouillon de sprites au PPU (DMA) ;
;    - l'effacement d'une brique cassée ;
;    - l'affichage du score et des vies ;
;    - la remise à zéro du défilement (le PPU l'exige après nos écritures).

nmi:
        pha                     ; la NMI peut interrompre le code N'IMPORTE OÙ:
        txa                     ; on sauvegarde A, X et Y sur la pile pour
        pha                     ; les rendre intacts en partant. La pile est
        tya                     ; une pile d'assiettes : dernier posé,
        pha                     ; premier repris !

        ; --- 1) Envoi des 64 sprites : le DMA copie d'un bloc les 256 octets
        ;        de la page $0200 vers la mémoire des sprites du PPU.
        lda #$00
        sta OAMADDR
        lda #$02                ; $02 = page mémoire $0200
        sta OAMDMA

        ; --- 2) Une brique à effacer ? -------------------------------------
        lda effacer_actif
        beq @pas_de_brique
        bit PPUSTATUS
        lda effacer_hi
        sta PPUADDR
        lda effacer_lo
        sta PPUADDR
        lda #TUILE_VIDE
        sta PPUDATA             ; efface la moitié gauche...
        sta PPUDATA             ; ...et la droite (l'adresse avance seule)
        lda #0
        sta effacer_actif
@pas_de_brique:

        ; --- 3) Le score (3 chiffres, rangée 2, colonnes 4-6) ---------------
        ;  Le chiffre 0 est la tuile $10, donc tuile = chiffre + $10.
        bit PPUSTATUS
        lda #$20
        sta PPUADDR
        lda #$44                ; $2044 = rangée 2, colonne 4
        sta PPUADDR
        lda score_c
        clc
        adc #TUILE_CHIFFRE_0
        sta PPUDATA
        lda score_d
        clc
        adc #TUILE_CHIFFRE_0
        sta PPUDATA
        lda score_u
        clc
        adc #TUILE_CHIFFRE_0
        sta PPUDATA

        ; --- 4) Les vies (rangée 2, colonne 27) ------------------------------
        lda #$20
        sta PPUADDR
        lda #$5B                ; $205B = rangée 2, colonne 27
        sta PPUADDR
        lda vies
        clc
        adc #TUILE_CHIFFRE_0
        sta PPUDATA

        ; --- 5) Remise à zéro du défilement ----------------------------------
        ;  Nos écritures via PPUADDR ont déplacé le "viseur" du PPU : sans
        ;  cette remise à zéro, l'écran partirait dans tous les sens.
        bit PPUSTATUS
        lda #0
        sta PPUSCROLL
        sta PPUSCROLL
        lda #%10000000
        sta PPUCTRL

        inc image               ; le top d'horloge qu'attend la boucle principale

        pla                     ; on restaure Y, X et A (ordre inverse de
        tay                     ; l'empilement : dernier entré, premier sorti)
        pla
        tax
        pla
        rti                     ; ReTurn from Interrupt : reprend le programme
                                ; interrompu exactement où il en était


; -----------------------------------------------------------------------------
;  IRQ : autre type d'interruption, inutilisée ici
; -----------------------------------------------------------------------------
irq:
        rti


; =============================================================================
;  LES VECTEURS
; =============================================================================
;  Les 6 derniers octets de la ROM. Le CPU y lit, câblé en dur :
;    $FFFA-$FFFB : où aller lors d'une NMI
;    $FFFC-$FFFD : où aller à l'allumage (reset)
;    $FFFE-$FFFF : où aller lors d'une IRQ
;  `.word` écrit une adresse sur 2 octets (octet bas d'abord : le 6502 est
;  "petit-boutiste" / little-endian).

.segment "VECTORS"
        .word nmi, reset, irq


; =============================================================================
;  LES GRAPHISMES (CHR-ROM) : nos tuiles, dessinées octet par octet !
; =============================================================================
;  Chaque tuile de 8×8 pixels occupe 16 octets, organisés en DEUX "plans" :
;    - octets 0-7  : le plan 0 (bit faible de la couleur de chaque pixel)
;    - octets 8-15 : le plan 1 (bit fort)
;  La couleur d'un pixel (0 à 3) combine les deux bits :
;    plan1=0, plan0=0 → couleur 0 (transparent/fond)
;    plan1=0, plan0=1 → couleur 1
;    plan1=1, plan0=0 → couleur 2
;    plan1=1, plan0=1 → couleur 3
;  En écrivant les octets en binaire (%...), on "voit" littéralement le
;  dessin : chaque 1 est un pixel allumé !

; Petit macro pour les chiffres : il écrit les 8 lignes dans les DEUX plans,
; ce qui donne la couleur 3 (blanc dans notre palette).
.macro TUILE_BLANCHE l0, l1, l2, l3, l4, l5, l6, l7
        .byte l0, l1, l2, l3, l4, l5, l6, l7   ; plan 0
        .byte l0, l1, l2, l3, l4, l5, l6, l7   ; plan 1
.endmacro

.segment "CHR"

; --- Tuile $00 : vide (16 octets à zéro) --------------------------------------
        .res 16

; --- Tuile $01 : brique, moitié gauche (couleur 1 → plan 0 seulement) ---------
        .byte %00000000
        .byte %01111111
        .byte %01111111
        .byte %01111111
        .byte %01111111
        .byte %01111111
        .byte %01111111
        .byte %00000000
        .res 8                  ; plan 1 vide

; --- Tuile $02 : brique, moitié droite ----------------------------------------
        .byte %00000000
        .byte %11111110
        .byte %11111110
        .byte %11111110
        .byte %11111110
        .byte %11111110
        .byte %11111110
        .byte %00000000
        .res 8

; --- Tuile $03 : mur (couleur 2 → plan 1 seulement) ---------------------------
        .res 8                  ; plan 0 vide
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111

; --- Tuile $04 : la balle (couleur 1) -----------------------------------------
        .byte %00111100
        .byte %01111110
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %01111110
        .byte %00111100
        .res 8

; --- Tuile $05 : raquette, bout gauche arrondi (couleur 2) --------------------
        .res 8
        .byte %00000000
        .byte %00000000
        .byte %00111111
        .byte %01111111
        .byte %01111111
        .byte %00111111
        .byte %00000000
        .byte %00000000

; --- Tuile $06 : raquette, milieu ---------------------------------------------
        .res 8
        .byte %00000000
        .byte %00000000
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %00000000
        .byte %00000000

; --- Tuile $07 : raquette, bout droit -----------------------------------------
        .res 8
        .byte %00000000
        .byte %00000000
        .byte %11111100
        .byte %11111110
        .byte %11111110
        .byte %11111100
        .byte %00000000
        .byte %00000000

; --- On saute jusqu'à la tuile $10, où commencent les chiffres ----------------
;  8 tuiles écrites × 16 octets = $80 ; la tuile $10 commence à l'octet $100.
        .res $100 - $80

; --- Tuiles $10 à $19 : les chiffres 0 à 9 -------------------------------------
        TUILE_BLANCHE %01111100, %11000110, %11001110, %11010110, %11100110, %11000110, %01111100, %00000000  ; 0
        TUILE_BLANCHE %00110000, %01110000, %00110000, %00110000, %00110000, %00110000, %11111100, %00000000  ; 1
        TUILE_BLANCHE %01111000, %11001100, %00001100, %00111000, %01100000, %11001100, %11111100, %00000000  ; 2
        TUILE_BLANCHE %01111000, %11001100, %00001100, %00111000, %00001100, %11001100, %01111000, %00000000  ; 3
        TUILE_BLANCHE %00011100, %00111100, %01101100, %11001100, %11111110, %00001100, %00011110, %00000000  ; 4
        TUILE_BLANCHE %11111100, %11000000, %11111000, %00001100, %00001100, %11001100, %01111000, %00000000  ; 5
        TUILE_BLANCHE %00111000, %01100000, %11000000, %11111000, %11001100, %11001100, %01111000, %00000000  ; 6
        TUILE_BLANCHE %11111100, %11001100, %00001100, %00011000, %00110000, %00110000, %00110000, %00000000  ; 7
        TUILE_BLANCHE %01111000, %11001100, %11001100, %01111000, %11001100, %11001100, %01111000, %00000000  ; 8
        TUILE_BLANCHE %01111000, %11001100, %11001100, %01111100, %00001100, %00011000, %01110000, %00000000  ; 9

; Le reste des 8 Ko de CHR-ROM est rempli de zéros par l'éditeur de liens
; (voir nes.cfg). Fin du fichier — bravo d'être arrivé jusqu'ici !
