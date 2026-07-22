; =============================================================================
;  CASSE-BRIQUE NES v2 — l'assembleur 6502 pour les nuls
; =============================================================================
;
;  Un jeu de casse-brique complet pour la Nintendo NES, écrit en assembleur
;  6502, et commenté ligne par ligne dans un but pédagogique.
;
;  NOUVEAUTÉS DE LA VERSION 2 :
;   - des rebonds à 5 angles selon la zone de la raquette touchée, grâce à
;     des vitesses en VIRGULE FIXE 8.8 (fini les diagonales à 45° !) ;
;   - des CAPSULES BONUS qui tombent des briques : raquette élargie,
;     balle ralentie, vie supplémentaire ;
;   - trois familles de BRIQUES : normales, solides (2 coups, elles se
;     fissurent), dorées (5 points) — colorées par la table d'attributs ;
;   - des NIVEAUX successifs à motifs dessinés dans la ROM, avec une
;     balle de plus en plus rapide ;
;   - un ÉCRAN TITRE avec du texte (un alphabet dans la CHR-ROM !) et le
;     RECORD de la session, qui survit d'une partie à l'autre.
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
;    BCC / BCS      saute si inférieur / supérieur-ou-égal (non signé)
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
;  L'ARCHITECTURE DE LA NES EN BREF
;  --------------------------------
;  Deux puces travaillent en parallèle : le CPU (6502) exécute ce fichier,
;  le PPU dessine l'image 60 fois par seconde. Le CPU ne touche à la mémoire
;  vidéo QUE pendant le VBlank, signalé par l'interruption NMI. Le fond est
;  une grille de 32×30 tuiles (nos murs et nos briques), les sprites sont
;  des objets mobiles de 8×8 (balle, raquette, capsules). La règle d'or :
;  la boucle principale CALCULE, la routine nmi AFFICHE.
; =============================================================================


; -----------------------------------------------------------------------------
;  CONSTANTES : les registres matériels de la NES
; -----------------------------------------------------------------------------
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
;  4 voix : carré 1 = bruitages, carré 2 = mélodie, triangle = basse,
;  bruit = chocs. Rappel contre-intuitif : la hauteur d'une note se règle
;  par sa PÉRIODE — grande période = note grave.
CARRE1_VOL  = $4000
CARRE1_BAL  = $4001
CARRE1_BAS  = $4002
CARRE1_HAUT = $4003
CARRE2_VOL  = $4004
CARRE2_BAL  = $4005
CARRE2_BAS  = $4006
CARRE2_HAUT = $4007
TRI_LIN     = $4008
TRI_BAS     = $400A
TRI_HAUT    = $400B
BRUIT_VOL   = $400C
BRUIT_PER   = $400E
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
TUILE_VIDE       = $00
TUILE_NORMALE_G  = $01   ; brique orange, 1 coup
TUILE_NORMALE_D  = $02
TUILE_MUR        = $03
TUILE_BALLE      = $04
TUILE_RAQ_G      = $05
TUILE_RAQ_M      = $06
TUILE_RAQ_D      = $07
TUILE_SOLIDE_G   = $08   ; brique grise, 2 coups
TUILE_SOLIDE_D   = $09
TUILE_FISSURE_G  = $0A   ; brique solide déjà touchée une fois
TUILE_FISSURE_D  = $0B
TUILE_DOREE_G    = $0C   ; brique dorée, 5 points
TUILE_DOREE_D    = $0D
TUILE_CAPS_LARGE = $0E   ; capsule "raquette élargie"
TUILE_CAPS_LENTE = $0F   ; capsule "balle lente"
TUILE_CHIFFRE_0  = $10   ; chiffres 0-9 : tuiles $10-$19
TUILE_CAPS_VIE   = $1A   ; capsule "vie bonus" (le petit cœur)
TIRET            = $1B
; L'alphabet (partiel : uniquement les lettres de nos textes), tuiles $20+ :
L_A = $20
L_B = $21
L_C = $22
L_D = $23
L_E = $24
L_I = $25
L_O = $26
L_P = $27
L_Q = $28
L_R = $29
L_S = $2A
L_T = $2B
L_U = $2C
ESPACE = $00

; --- Les types de briques dans la grille ---------------------------------------
;  0 = pas de brique, et sinon :
TYPE_NORMALE  = 1   ; orange, 1 coup, 1 point
TYPE_SOLIDE   = 2   ; grise, 1er coup → devient FISSUREE
TYPE_DOREE    = 3   ; dorée, 1 coup, 5 points
TYPE_FISSUREE = 4   ; le 2e coup la détruit, 2 points

; --- Les capsules bonus ---------------------------------------------------------
CAPS_LARGE = 1      ; raquette de 32 pixels pendant ~10 secondes
CAPS_LENTE = 2      ; la balle avance une image sur deux pendant ~10 s
CAPS_VIE   = 3      ; +1 vie (9 maximum)

; --- Les états du jeu ------------------------------------------------------------
ETAT_ATTENTE = 0    ; la balle est collée à la raquette, on attend A
ETAT_JEU     = 1    ; la balle est en mouvement
ETAT_FINI    = 2    ; défaite : on attend Start pour revenir au titre
ETAT_TITRE   = 3    ; l'écran titre
ETAT_PAUSE   = 4    ; petit entracte entre deux niveaux

; --- Les notes de musique ----------------------------------------------------------
;  période = 1 789 773 ÷ (16 × Hz) − 1 (1 789 773 Hz = la cadence du CPU).
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

; --- Géométrie du terrain (en pixels) ------------------------------------------------
RAQUETTE_Y    = 208
BALLE_X_MIN   = 8
BALLE_X_MAX   = 240
BALLE_Y_MIN   = 32
BALLE_Y_PERDU = 232


; -----------------------------------------------------------------------------
;  VARIABLES en page zéro
; -----------------------------------------------------------------------------
.zeropage

boutons:           .res 1
anciens:           .res 1   ; boutons de l'image précédente...
presses:           .res 1   ; ...pour détecter ceux qui VIENNENT d'être pressés
image:             .res 1   ; compteur d'images, +1 à chaque VBlank (60/s)
etat:              .res 1

; LA BALLE, EN VIRGULE FIXE 8.8. Chaque coordonnée a désormais deux octets :
; les pixels entiers (balle_x) et les 256e de pixel (balle_xs). La vitesse
; aussi : $0180 = 1,5 pixel/image, $FE80 = −1,5 (complément à deux). C'est ce
; qui permet des angles fins — le secret des trajectoires d'Arkanoid !
balle_x:           .res 1
balle_xs:          .res 1   ; sous-pixels de x
balle_y:           .res 1
balle_ys:          .res 1
balle_dx_lo:       .res 1   ; vitesse horizontale (16 bits signés)
balle_dx_hi:       .res 1
balle_dy_lo:       .res 1   ; vitesse verticale
balle_dy_hi:       .res 1

raquette_x:        .res 1

vies:              .res 1
niveau:            .res 1
score_u:           .res 1   ; score : un chiffre par octet, comme à l'école
score_d:           .res 1
score_c:           .res 1
record_u:          .res 1   ; le RECORD de la session. Il n'est remis à zéro
record_d:          .res 1   ; qu'à l'allumage de la console : les parties se
record_c:          .res 1   ; succèdent, lui reste. (Voir la fin de perdre_vie.)
briques_restantes: .res 1

; File d'attente pour la nmi : redessiner UNE brique (2 tuiles) à l'écran.
; v2 : on n'écrit plus forcément du vide — une brique solide touchée est
; REDESSINÉE en brique fissurée. La file transporte donc aussi les tuiles.
effacer_actif:     .res 1
effacer_hi:        .res 1
effacer_lo:        .res 1
effacer_tg:        .res 1   ; tuile gauche à écrire
effacer_td:        .res 1   ; tuile droite

; La capsule bonus (une seule à la fois, c'est bien assez)
capsule_type:      .res 1   ; 0 = aucune, sinon CAPS_...
capsule_x:         .res 1
capsule_y:         .res 1
capsule_suivante:  .res 1   ; pour distribuer les bonus à tour de rôle

; Les minuteries des bonus (décomptées toutes les 4 images : 150 ≈ 10 s)
raquette_large:    .res 1
balle_lente:       .res 1

pause_cpt:         .res 1   ; l'entracte entre deux niveaux
vitesse_extra:     .res 1   ; supplément de vitesse par niveau (en 256e)

; Variables de travail pour les collisions et le dessin
col_tuile:         .res 1
lig_tuile:         .res 1
col_brique:        .res 1
lig_brique:        .res 1
adr_lo:            .res 1
adr_hi:            .res 1
tmp_lo:            .res 1
tmp_hi:            .res 1
tmp2:              .res 1
motif_ptr:         .res 2   ; pointeur vers le motif de briques du niveau

; Le moteur de musique et les bruitages
mus_active:        .res 1
mel_pos:           .res 1
mel_cpt:           .res 1
bas_pos:           .res 1
bas_cpt:           .res 1
bip_cpt:           .res 1
bruit_cpt:         .res 1


; -----------------------------------------------------------------------------
;  VARIABLES en RAM ordinaire
; -----------------------------------------------------------------------------
.bss

grille: .res 96   ; 6 rangées × 16 colonnes (15 briques + 1 case de bourrage)
                  ; chaque case contient un TYPE_... ou 0


; =============================================================================
;  L'EN-TÊTE iNES
; =============================================================================
.segment "HEADER"
        .byte 'N', 'E', 'S', $1A
        .byte 2                    ; 2 blocs de 16 Ko de code (PRG-ROM)
        .byte 1                    ; 1 bloc de 8 Ko de graphismes (CHR-ROM)
        .byte $01
        .byte $00
        .byte 0,0,0,0,0,0,0,0


; =============================================================================
;  LE CODE
; =============================================================================
.segment "CODE"

; -----------------------------------------------------------------------------
;  RESET : le point de départ
; -----------------------------------------------------------------------------
;  Le rituel d'initialisation, identique à la v1. Une nuance IMPORTANTE en
;  v2 : on ne repasse plus JAMAIS par ici entre deux parties (sinon le
;  record serait effacé !). Reset = allumer la console ; commencer une
;  partie = demarrer_partie. Deux choses différentes.

reset:
        sei
        cld
        ldx #$40
        stx APUFRAME
        ldx #$FF
        txs
        inx
        stx PPUCTRL
        stx PPUMASK
        stx $4010
        bit PPUSTATUS
@attente_vblank_1:
        bit PPUSTATUS
        bpl @attente_vblank_1
        lda #0
@vider_ram:
        sta $0000, x
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
        bne @vider_ram
@attente_vblank_2:
        bit PPUSTATUS
        bpl @attente_vblank_2

        jsr charger_palettes
        jsr dessiner_cadre      ; le décor permanent : murs + attributs
        jsr dessiner_ecran_titre
        lda #ETAT_TITRE
        sta etat
        lda #3
        sta vies                ; juste pour l'affichage du bandeau au titre

        lda #%00001111          ; on ouvre les 4 robinets du son...
        sta APUSTATUS
        jsr demarrer_musique    ; ...et en musique !

        jsr allumer_ecran
        jmp principale


; -----------------------------------------------------------------------------
;  eteindre_ecran / allumer_ecran
; -----------------------------------------------------------------------------
;  v2 redessine l'écran en cours de route (nouveau niveau, retour au titre).
;  La règle : on coupe TOUT (affichage et NMI), on redessine tranquillement,
;  on attend un VBlank, et on rallume. L'écran devient noir un instant —
;  toutes les consoles 8 bits font ça, regardez bien les vieux jeux !

eteindre_ecran:
        lda #0
        sta PPUCTRL             ; NMI coupée
        sta PPUMASK             ; affichage coupé
        rts

allumer_ecran:
        bit PPUSTATUS
@attendre:
        bit PPUSTATUS
        bpl @attendre
        lda #0
        sta PPUSCROLL           ; remet le défilement à (0,0) : nos écritures
        sta PPUSCROLL           ; via PPUADDR l'ont déréglé
        lda #%10000000
        sta PPUCTRL
        lda #%00011110
        sta PPUMASK
        rts


; -----------------------------------------------------------------------------
;  charger_palettes : les couleurs
; -----------------------------------------------------------------------------
charger_palettes:
        bit PPUSTATUS
        lda #$3F
        sta PPUADDR
        lda #$00
        sta PPUADDR
        ldx #0
@copier:
        lda palettes, x
        sta PPUDATA
        inx
        cpx #32
        bne @copier
        rts

palettes:
        ; --- 4 palettes de FOND ---
        ;  La palette 0 sert au bandeau et aux murs, la palette 1 à la zone
        ;  des briques (choisie par la table d'attributs, voir
        ;  dessiner_cadre) : c'est elle qui rend les briques dorées... dorées.
        .byte $0F, $27, $10, $30   ; 0 : orange, gris, blanc (chiffres/texte)
        .byte $0F, $27, $10, $28   ; 1 : orange, gris (solides), OR (dorées)
        .byte $0F, $0F, $0F, $0F
        .byte $0F, $0F, $0F, $0F
        ; --- 4 palettes de SPRITES ---
        .byte $0F, $30, $00, $0F   ; 0 : balle blanche
        .byte $0F, $00, $21, $0F   ; 1 : raquette bleue
        .byte $0F, $28, $16, $30   ; 2 : capsules (or, rouge, blanc)
        .byte $0F, $0F, $0F, $0F


; =============================================================================
;  LE DÉCOR PERMANENT : cadre, murs, attributs (dessiné une fois, au reset)
; =============================================================================
dessiner_cadre:
        ; --- 1) Tout vider : 960 tuiles + 64 octets d'attributs -------------
        bit PPUSTATUS
        lda #$20
        sta PPUADDR
        lda #$00
        sta PPUADDR
        ldx #4
        ldy #0
        lda #TUILE_VIDE
@vider:
        sta PPUDATA
        iny
        bne @vider
        dex
        bne @vider

        ; --- 2) Le mur du haut : 32 tuiles sur la rangée 3 ($2060) ----------
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

        ; --- 3) Les murs latéraux : colonnes 0 et 31, rangées 4 à 29 --------
        lda #$20
        sta adr_hi
        lda #$80
        sta adr_lo
        ldx #26
@murs_lateraux:
        bit PPUSTATUS
        lda adr_hi
        sta PPUADDR
        lda adr_lo
        sta PPUADDR
        lda #TUILE_MUR
        sta PPUDATA
        lda adr_lo
        clc
        adc #31
        sta tmp_lo
        lda adr_hi
        adc #0
        sta tmp_hi
        lda tmp_hi
        sta PPUADDR
        lda tmp_lo
        sta PPUADDR
        lda #TUILE_MUR
        sta PPUDATA
        lda adr_lo
        clc
        adc #32
        sta adr_lo
        lda adr_hi
        adc #0
        sta adr_hi
        dex
        bne @murs_lateraux

        ; --- 4) LES ATTRIBUTS : la palette 1 pour la zone des briques -------
        ;  Chaque octet de la table d'attributs ($23C0-$23FF) choisit la
        ;  palette d'un carré de 4×4 tuiles. Les rangées d'attributs 1 et 2
        ;  couvrent les tuiles 4 à 11 — pile la zone des briques. En y
        ;  écrivant %01010101 ("palette 1 partout"), les briques dorées
        ;  deviennent OR sans toucher au blanc des chiffres du bandeau.
        bit PPUSTATUS
        lda #$23
        sta PPUADDR
        lda #$C8                ; $23C8 = début de la rangée d'attributs 1
        sta PPUADDR
        lda #%01010101
        ldx #16                 ; rangées 1 et 2 = 16 octets
@attributs:
        sta PPUDATA
        dex
        bne @attributs
        rts

; Adresses vidéo du début (colonne 0) des 6 rangées de briques.
lignes_briques_lo:  .byte $A0, $C0, $E0, $00, $20, $40
lignes_briques_hi:  .byte $20, $20, $20, $21, $21, $21


; =============================================================================
;  L'ÉCRAN TITRE
; =============================================================================
;  Du TEXTE, enfin ! Chaque lettre est une tuile ($20 et suivantes), et une
;  phrase n'est qu'une suite de numéros de tuiles rangée dans la ROM. On
;  n'a dessiné QUE les lettres utiles : 13 lettres suffisent à nos trois
;  phrases — sur une cartouche, chaque tuile compte.

dessiner_ecran_titre:
        jsr vider_interieur     ; efface le terrain de jeu (ou l'ancien texte)

        bit PPUSTATUS
        lda #$21                ; rangée 12, colonne 10
        sta PPUADDR
        lda #$8A
        sta PPUADDR
        ldx #0
@titre:
        lda texte_titre, x
        sta PPUDATA
        inx
        cpx #12
        bne @titre

        lda #$21                ; rangée 15, colonne 11 : "RECORD " puis les
        sta PPUADDR             ; 3 chiffres — qui suivent immédiatement en
        lda #$EB                ; mémoire vidéo : l'adresse avance seule !
        sta PPUADDR
        ldx #0
@record:
        lda texte_record, x
        sta PPUDATA
        inx
        cpx #7
        bne @record
        lda record_c
        clc
        adc #TUILE_CHIFFRE_0
        sta PPUDATA
        lda record_d
        clc
        adc #TUILE_CHIFFRE_0
        sta PPUDATA
        lda record_u
        clc
        adc #TUILE_CHIFFRE_0
        sta PPUDATA

        lda #$22                ; rangée 18, colonne 8
        sta PPUADDR
        lda #$48
        sta PPUADDR
        ldx #0
@appuie:
        lda texte_appuie, x
        sta PPUDATA
        inx
        cpx #16
        bne @appuie
        rts

texte_titre:
        .byte L_C, L_A, L_S, L_S, L_E, TIRET, L_B, L_R, L_I, L_Q, L_U, L_E
texte_record:
        .byte L_R, L_E, L_C, L_O, L_R, L_D, ESPACE
texte_appuie:
        .byte L_A, L_P, L_P, L_U, L_I, L_E, ESPACE, L_S, L_U, L_R, ESPACE
        .byte L_S, L_T, L_A, L_R, L_T


; -----------------------------------------------------------------------------
;  vider_interieur : efface tout le terrain (rangées 4-29, entre les murs)
; -----------------------------------------------------------------------------
vider_interieur:
        lda #$20
        sta adr_hi
        lda #$80                ; $2080 = rangée 4, colonne 0
        sta adr_lo
        ldx #26
@rangee:
        bit PPUSTATUS
        lda adr_hi
        sta PPUADDR
        lda adr_lo
        clc
        adc #1                  ; colonne 1 : on épargne les murs
        sta PPUADDR
        lda #TUILE_VIDE
        ldy #30
@case:
        sta PPUDATA
        dey
        bne @case
        lda adr_lo
        clc
        adc #32
        sta adr_lo
        lda adr_hi
        adc #0
        sta adr_hi
        dex
        bne @rangee
        rts


; =============================================================================
;  DÉMARRER UNE PARTIE, CHARGER UN NIVEAU
; =============================================================================
demarrer_partie:
        lda #0
        sta score_u
        sta score_d
        sta score_c
        sta capsule_type
        sta raquette_large
        sta balle_lente
        lda #3
        sta vies
        lda #1
        sta niveau
        lda #116
        sta raquette_x
        jsr eteindre_ecran
        jsr charger_niveau
        jsr allumer_ecran
        lda #ETAT_ATTENTE
        sta etat
        rts

; -----------------------------------------------------------------------------
;  charger_niveau — remplit la grille depuis un MOTIF en ROM, et la dessine.
;  À appeler écran éteint. Le motif est choisi par (niveau−1) modulo 4 :
;  après le 4e niveau, les motifs reviennent, mais plus vite !
; -----------------------------------------------------------------------------
charger_niveau:
        ; --- quel motif ? ------------------------------------------------------
        lda niveau
        sec
        sbc #1
        and #%00000011          ; modulo 4, sans division : merci le binaire
        tax
        lda motifs_lo, x
        sta motif_ptr
        lda motifs_hi, x
        sta motif_ptr+1

        ; --- copier les 96 cases du motif dans la grille -----------------------
        ldy #0
@copier:
        lda (motif_ptr), y
        sta grille, y
        iny
        cpy #96
        bne @copier

        ; --- compter les briques ------------------------------------------------
        ;  Une solide compte pour UNE brique : elle ne sera décomptée qu'à sa
        ;  destruction finale, pas à la fissure.
        lda #0
        sta briques_restantes
        ldx #95
@compter:
        lda grille, x
        beq @suivante
        inc briques_restantes
@suivante:
        dex
        bpl @compter

        ; --- la vitesse du niveau -----------------------------------------------
        ;  +0,25 pixel/image ($40 en 256e) par niveau, plafonné à +0,75 :
        ;  au-delà, même un champion n'y verrait plus rien.
        lda niveau
        sec
        sbc #1
        cmp #4
        bcc @vitesse_ok
        lda #3
@vitesse_ok:
        asl a
        asl a
        asl a
        asl a
        asl a
        asl a                   ; ×64 = ×$40
        sta vitesse_extra

        ; --- dessiner -----------------------------------------------------------
        jsr vider_interieur
        jsr dessiner_briques
        rts

; Où trouver chaque motif (4 tableaux de 96 octets, tout en bas du fichier)
motifs_lo: .byte <motif_classique, <motif_damier, <motif_coeur, <motif_forteresse
motifs_hi: .byte >motif_classique, >motif_damier, >motif_coeur, >motif_forteresse

; -----------------------------------------------------------------------------
;  dessiner_briques — traduit la grille en tuiles à l'écran (écran éteint)
; -----------------------------------------------------------------------------
dessiner_briques:
        lda #0
        sta lig_brique
@rangee:
        bit PPUSTATUS
        ldy lig_brique
        lda lignes_briques_hi, y
        sta PPUADDR
        lda lignes_briques_lo, y
        clc
        adc #1
        sta PPUADDR
        ; X = index de la première case de la rangée = rangée × 16
        tya
        asl a
        asl a
        asl a
        asl a
        tax
        lda #15
        sta tmp2
@brique:
        lda grille, x           ; le type de la brique...
        tay
        lda tuiles_brique_g, y  ; ...devient une paire de tuiles
        sta PPUDATA
        lda tuiles_brique_d, y
        sta PPUDATA
        inx
        dec tmp2
        bne @brique
        inc lig_brique
        lda lig_brique
        cmp #6
        bne @rangee
        rts

; L'apparence de chaque type (indexé par TYPE_...) :
;                      vide        normale          solide          dorée          fissurée
tuiles_brique_g: .byte TUILE_VIDE, TUILE_NORMALE_G, TUILE_SOLIDE_G, TUILE_DOREE_G, TUILE_FISSURE_G
tuiles_brique_d: .byte TUILE_VIDE, TUILE_NORMALE_D, TUILE_SOLIDE_D, TUILE_DOREE_D, TUILE_FISSURE_D
; ... et ce que rapporte sa destruction :
points_brique:   .byte 0, 1, 0, 5, 2


; =============================================================================
;  LA BOUCLE PRINCIPALE
; =============================================================================
principale:
        jsr attendre_nmi
        jsr maj_musique
        jsr maj_bruitages
        jsr lire_manette
        jsr maj_raquette

        ; L'aiguillage des 5 états. Les branches conditionnelles du 6502 ne
        ; portent qu'à ±127 octets : pour les destinations lointaines, on
        ; branche sur un JMP tout proche, qui lui va où il veut.
        lda etat
        cmp #ETAT_JEU
        bne @pas_jeu
        jmp @en_jeu
@pas_jeu:
        cmp #ETAT_ATTENTE
        bne @pas_attente
        jmp @en_attente
@pas_attente:
        cmp #ETAT_TITRE
        beq @au_titre
        cmp #ETAT_PAUSE
        beq @entracte

        ; --- État FINI : Start ramène à l'écran titre ------------------------
        lda presses
        and #BTN_START
        bne @retour_titre
        jmp @dessiner
@retour_titre:
        jsr eteindre_ecran
        jsr dessiner_ecran_titre
        lda #ETAT_TITRE
        sta etat
        lda #3
        sta vies                ; cosmétique : le bandeau du titre affiche 3
        jsr demarrer_musique
        jsr allumer_ecran
        jmp @dessiner

@au_titre:
        lda presses
        and #BTN_START
        bne @lancer_partie
        jmp @dessiner           ; (un BEQ n'irait pas si loin : les branches
@lancer_partie:                 ;  conditionnelles portent à ±127 octets !)
        jsr demarrer_partie
        jsr bip_raquette
        jmp @dessiner

@entracte:
        ; --- Entre deux niveaux : petite pause, puis niveau suivant ----------
        dec pause_cpt
        beq @niveau_suivant
        jmp @dessiner
@niveau_suivant:
        inc niveau
        lda #0
        sta capsule_type
        sta raquette_large
        sta balle_lente
        jsr eteindre_ecran
        jsr charger_niveau
        jsr allumer_ecran
        lda #ETAT_ATTENTE
        sta etat
        jmp @dessiner

@en_attente:
        ; --- La balle est collée au centre de la raquette ---------------------
        lda raquette_x
        clc
        adc #8
        sta balle_x
        lda #RAQUETTE_Y - 8
        sta balle_y
        lda boutons
        and #BTN_A
        beq @dessiner
        ; A pressé : on lance ! Vers le haut à 2 px/image (+ bonus du niveau),
        ; et en diagonale douce, côté tiré à pile ou face sur le compteur
        ; d'images.
        lda #ETAT_JEU
        sta etat
        jsr bip_raquette
        lda #0
        sec
        sbc vitesse_extra       ; dy = −2,0 − extra : 0 − extra donne le bas...
        sta balle_dy_lo
        lda #$FE                ; ...et $FE − retenue donne le haut. Une
        sbc #0                  ; soustraction 16 bits comme une autre !
        sta balle_dy_hi
        lda #0
        sta balle_dx_lo
        lda #1                  ; dx = +1,0...
        sta balle_dx_hi
        lda image
        and #1
        beq @dessiner
        lda #$FF                ; ...ou −1,0 : $FF00 = −256/256 = −1
        sta balle_dx_hi
        lda #0
        sta balle_dx_lo
        jmp @dessiner

@en_jeu:
        jsr deplacer_balle
        jsr maj_capsule
        jsr maj_minuteries

@dessiner:
        jsr maj_sprites
        jmp principale


attendre_nmi:
        lda image
@patienter:
        cmp image
        beq @patienter
        rts


; -----------------------------------------------------------------------------
;  lire_manette — avec détection des boutons "qui viennent d'être pressés"
; -----------------------------------------------------------------------------
lire_manette:
        lda boutons
        sta anciens
        lda #1
        sta JOYPAD1
        lda #0
        sta JOYPAD1
        ldx #8
@bouton:
        lda JOYPAD1
        lsr a
        rol boutons
        dex
        bne @bouton
        lda anciens
        eor #$FF                ; presses = (PAS anciens) ET boutons :
        and boutons             ; 1 seulement l'image où le bouton s'enfonce
        sta presses
        rts


; -----------------------------------------------------------------------------
;  maj_raquette — déplacement, avec une largeur qui peut changer !
; -----------------------------------------------------------------------------
maj_raquette:
        lda boutons
        and #BTN_GAUCHE
        beq @pas_a_gauche
        lda raquette_x
        sec
        sbc #2
        sta raquette_x
        cmp #8
        bcs @pas_a_gauche
        lda #8
        sta raquette_x
@pas_a_gauche:
        lda boutons
        and #BTN_DROITE
        beq @pas_a_droite
        lda raquette_x
        clc
        adc #2
        sta raquette_x
        ; la butée droite dépend de la largeur : 24 px (max 224) ou,
        ; raquette élargie, 32 px (max 216)
        ldx #224
        lda raquette_large
        beq @borne_choisie
        ldx #216
@borne_choisie:
        stx tmp_lo
        lda raquette_x
        cmp tmp_lo
        bcc @pas_a_droite
        lda tmp_lo
        sta raquette_x
@pas_a_droite:
        rts


; =============================================================================
;  deplacer_balle — mouvement en virgule fixe + rebonds sur les murs
; =============================================================================
deplacer_balle:
        ; --- bonus "balle lente" : la balle ne bouge qu'une image sur deux ---
        lda balle_lente
        beq @pleine_vitesse
        lda image
        and #1
        bne @pleine_vitesse
        rts
@pleine_vitesse:

        ; --- axe X : les sous-pixels d'abord, la retenue passe aux pixels ----
        lda balle_xs
        clc
        adc balle_dx_lo
        sta balle_xs
        lda balle_x
        adc balle_dx_hi
        sta balle_x
        cmp #BALLE_X_MIN
        bcs @pas_mur_gauche
        lda #BALLE_X_MIN
        sta balle_x
        lda balle_dx_hi         ; on repart vers la droite (si on allait bien
        bpl @pas_mur_gauche     ; vers la gauche : prudence)
        jsr inverser_dx
        jsr bip_mur
@pas_mur_gauche:
        lda balle_x
        cmp #BALLE_X_MAX + 1
        bcc @pas_mur_droit
        lda #BALLE_X_MAX
        sta balle_x
        lda balle_dx_hi
        bmi @pas_mur_droit
        jsr inverser_dx
        jsr bip_mur
@pas_mur_droit:

        ; --- axe Y -------------------------------------------------------------
        lda balle_ys
        clc
        adc balle_dy_lo
        sta balle_ys
        lda balle_y
        adc balle_dy_hi
        sta balle_y
        cmp #BALLE_Y_MIN
        bcs @pas_mur_haut
        lda #BALLE_Y_MIN
        sta balle_y
        lda balle_dy_hi
        bpl @pas_mur_haut
        jsr inverser_dy
        jsr bip_mur
@pas_mur_haut:
        lda balle_y
        cmp #BALLE_Y_PERDU
        bcc @pas_perdue
        jmp perdre_vie
@pas_perdue:
        jsr collision_briques
        jsr collision_raquette
        rts

; -----------------------------------------------------------------------------
;  inverser_dx / inverser_dy — l'opposé d'un nombre de 16 bits
; -----------------------------------------------------------------------------
;  Comme sur 8 bits (inverser les bits puis +1), mais la retenue du +1
;  traverse les deux octets. −(−1,5) = +1,5 : le rebond parfait.
inverser_dx:
        lda balle_dx_lo
        eor #$FF
        clc
        adc #1
        sta balle_dx_lo
        lda balle_dx_hi
        eor #$FF
        adc #0
        sta balle_dx_hi
        rts

inverser_dy:
        lda balle_dy_lo
        eor #$FF
        clc
        adc #1
        sta balle_dy_lo
        lda balle_dy_hi
        eor #$FF
        adc #0
        sta balle_dy_hi
        rts


; =============================================================================
;  collision_briques — v2 : trois familles de briques
; =============================================================================
collision_briques:
        lda balle_x
        clc
        adc #4                  ; le CENTRE de la balle
        lsr a
        lsr a
        lsr a                   ; ÷8 → colonne de tuile
        sta col_tuile
        lda balle_y
        clc
        adc #4
        lsr a
        lsr a
        lsr a
        sta lig_tuile

        lda lig_tuile           ; dans la zone des briques (rangées 5-10) ?
        sec
        sbc #5
        cmp #6
        bcs @rien
        sta lig_brique
        lda col_tuile           ; entre les murs (colonnes 1-30) ?
        beq @rien
        cmp #31
        bcs @rien
        sec
        sbc #1
        lsr a                   ; ÷2 : une brique = 2 tuiles
        sta col_brique

        lda lig_brique          ; index = rangée × 16 + colonne
        asl a
        asl a
        asl a
        asl a
        clc
        adc col_brique
        tax
        lda grille, x
        beq @rien               ; pas de brique ici
        sta tmp2                ; on retient son TYPE

        ; --- touché ! le rebond d'abord, quoi qu'il arrive --------------------
        jsr inverser_dy

        ; --- brique SOLIDE ? elle encaisse : elle se fissure -------------------
        lda tmp2
        cmp #TYPE_SOLIDE
        bne @detruire
        lda #TYPE_FISSUREE
        sta grille, x           ; dans la grille...
        ldy #TYPE_FISSUREE      ; ...et à l'écran, au prochain VBlank
        jsr programmer_redessin
        jsr bip_mur             ; "toc" : du solide !
        rts

@detruire:
        ; --- toute autre brique est détruite -----------------------------------
        lda #0
        sta grille, x
        ldy tmp2
        lda points_brique, y    ; 1, 2 ou 5 points selon le type
        jsr ajouter_points
        jsr bip_brique
        ldy #0                  ; à l'écran : deux tuiles vides
        jsr programmer_redessin
        jsr lacher_capsule      ; une capsule bonus, peut-être ?

        dec briques_restantes
        bne @rien
        ; --- plus une brique : NIVEAU TERMINÉ ! --------------------------------
        lda #ETAT_PAUSE
        sta etat
        lda #120                ; deux secondes d'entracte
        sta pause_cpt
        jsr bip_victoire
@rien:
        rts

; -----------------------------------------------------------------------------
;  programmer_redessin — note l'adresse et les tuiles pour la nmi
; -----------------------------------------------------------------------------
;  Entrée : Y = le type à AFFICHER (0 = effacer, TYPE_FISSUREE = fissurer).
;  Utilise col_brique / lig_brique laissés par collision_briques.
programmer_redessin:
        lda tuiles_brique_g, y
        sta effacer_tg
        lda tuiles_brique_d, y
        sta effacer_td
        lda col_brique
        asl a
        clc
        adc #1
        ldy lig_brique
        clc
        adc lignes_briques_lo, y
        sta effacer_lo
        lda lignes_briques_hi, y
        sta effacer_hi
        lda #1
        sta effacer_actif
        rts

; -----------------------------------------------------------------------------
;  ajouter_points — A = combien (1 à 5), en décimal chiffre par chiffre
; -----------------------------------------------------------------------------
ajouter_points:
        sta tmp_lo
@encore:
        jsr incrementer_score
        dec tmp_lo
        bne @encore
        rts

incrementer_score:
        inc score_u
        lda score_u
        cmp #10
        bne @fini
        lda #0
        sta score_u
        inc score_d
        lda score_d
        cmp #10
        bne @fini
        lda #0
        sta score_d
        inc score_c
        lda score_c
        cmp #10
        bne @fini
        lda #0                  ; 999 + 1 = 000. Les puristes apprécieront.
        sta score_c
@fini:
        rts


; =============================================================================
;  collision_raquette — v2 : CINQ zones, cinq angles !
; =============================================================================
;  C'est LA grande nouveauté du gameplay. La raquette est découpée en 5
;  zones : frapper du bout renvoie la balle très inclinée, frapper au
;  centre la renvoie presque verticale. Les vitesses sont des paires
;  (dx, dy) en virgule fixe, rangées dans des tables — visez bien !
;
;      zone :    0        1        2        3        4
;      dx   :  −2,0     −1,5    ±0,5     +1,5     +2,0
;      dy   :  −1,0     −1,75   −2,25    −1,75    −1,0

collision_raquette:
        lda balle_dy_hi
        bmi @rate               ; la balle monte : rien à faire

        lda balle_y             ; à hauteur de raquette ?
        cmp #RAQUETTE_Y - 8
        bcc @rate
        cmp #RAQUETTE_Y
        bcs @rate

        ; point d'impact = balle_x − raquette_x + 7 : entre 0 et 30 (raquette
        ; normale) ou 0 et 38 (élargie), sinon c'est raté
        lda balle_x
        sec
        sbc raquette_x
        clc
        adc #7
        ldx raquette_large
        beq @largeur_normale
        cmp #39
        bcs @rate
        sec                     ; élargie : on recentre l'impact sur 0-30
        sbc #4                  ; pour garder les mêmes 5 zones
        bcs @impact_connu
        lda #0
        jmp @impact_connu
@largeur_normale:
        cmp #31
        bcs @rate
@impact_connu:
        ; --- quelle zone ? ------------------------------------------------------
        ldy #0
        cmp #6
        bcc @zone_choisie
        iny
        cmp #12
        bcc @zone_choisie
        iny
        cmp #19
        bcc @zone_choisie
        iny
        cmp #25
        bcc @zone_choisie
        iny                     ; zone 4
@zone_choisie:
        cpy #2
        bne @dx_table
        ; --- zone centrale : dx = ±0,5, en GARDANT le sens actuel -------------
        lda balle_dx_hi
        bmi @centre_gauche
        lda #$80
        sta balle_dx_lo
        lda #$00
        sta balle_dx_hi
        jmp @regler_dy
@centre_gauche:
        lda #$80
        sta balle_dx_lo
        lda #$FF                ; $FF80 = −0,5
        sta balle_dx_hi
        jmp @regler_dy
@dx_table:
        lda zones_dx_lo, y
        sta balle_dx_lo
        lda zones_dx_hi, y
        sta balle_dx_hi
@regler_dy:
        lda zones_dy_lo, y      ; dy de la zone, PLUS la vitesse du niveau
        sec                     ; (dy est négatif : soustraire = accélérer
        sbc vitesse_extra       ; vers le haut)
        sta balle_dy_lo
        lda zones_dy_hi, y
        sbc #0
        sta balle_dy_hi
        jsr bip_raquette
@rate:
        rts

; Les 5 paires (dx, dy) en virgule fixe 8.8. La zone 2 (centre) a un dx
; spécial géré dans le code ; sa colonne ici ne sert que de bouche-trou.
zones_dx_lo: .byte $00, $80, $80, $80, $00
zones_dx_hi: .byte $FE, $FE, $00, $01, $02
zones_dy_lo: .byte $00, $40, $C0, $40, $00
zones_dy_hi: .byte $FF, $FE, $FD, $FE, $FF


; =============================================================================
;  LES CAPSULES BONUS
; =============================================================================
;  Quand une brique meurt, une chance sur quatre qu'une capsule en tombe
;  (s'il n'y en a pas déjà une). L'attraper avec la raquette donne son
;  bonus. Les trois bonus sont distribués à tour de rôle : pas besoin d'un
;  vrai générateur aléatoire, un compteur suffit — et le moment du tirage
;  (image + position de la balle) est déjà bien imprévisible.

lacher_capsule:
        lda capsule_type
        bne @fin                ; déjà une capsule en l'air
        lda image
        eor balle_x             ; notre "dé" : 2 bits qui valsent sans arrêt
        and #%00000011
        bne @fin                ; raté (3 chances sur 4)
        lda capsule_suivante    ; à qui le tour ?
        clc
        adc #1
        cmp #4
        bcc @type_ok
        lda #1
@type_ok:
        sta capsule_suivante
        sta capsule_type
        lda col_brique          ; la capsule naît au milieu de la brique
        asl a
        asl a
        asl a
        asl a                   ; colonne × 16...
        clc
        adc #12                 ; ...+ 8 (mur) + 4 (centrage)
        sta capsule_x
        lda lig_brique
        asl a
        asl a
        asl a                   ; rangée × 8...
        clc
        adc #40                 ; ...+ 40 (le haut des briques)
        sta capsule_y
@fin:
        rts

maj_capsule:
        lda capsule_type
        beq @fin
        inc capsule_y           ; elle tombe d'un pixel par image
        lda capsule_y
        cmp #BALLE_Y_PERDU
        bcc @pas_perdue
        lda #0                  ; perdue dans les profondeurs...
        sta capsule_type
        rts
@pas_perdue:
        cmp #RAQUETTE_Y - 8     ; à hauteur de raquette ?
        bcc @fin
        cmp #RAQUETTE_Y
        bcs @fin
        lda capsule_x           ; chevauchement horizontal, comme la balle
        sec
        sbc raquette_x
        clc
        adc #7
        ldx raquette_large
        beq @normale
        cmp #39
        bcs @fin
        bcc @attrapee
@normale:
        cmp #31
        bcs @fin
@attrapee:
        lda capsule_type
        cmp #CAPS_LARGE
        beq @elargir
        cmp #CAPS_LENTE
        beq @ralentir
        lda vies                ; CAPS_VIE : +1 vie, 9 au maximum
        cmp #9
        bcs @consommer
        inc vies
        jmp @consommer
@elargir:
        lda #150                ; ~10 secondes (décompte toutes les 4 images)
        sta raquette_large
        jmp @consommer
@ralentir:
        lda #150
        sta balle_lente
@consommer:
        lda #0
        sta capsule_type
        jsr bip_bonus
@fin:
        rts

; Les minuteries des bonus fondent d'un cran toutes les 4 images
maj_minuteries:
        lda image
        and #%00000011
        bne @fin
        lda raquette_large
        beq @lente
        dec raquette_large
@lente:
        lda balle_lente
        beq @fin
        dec balle_lente
@fin:
        rts


; =============================================================================
;  perdre_vie — et la gestion du RECORD
; =============================================================================
perdre_vie:
        lda #0                  ; la balle emporte les bonus avec elle
        sta capsule_type
        sta raquette_large
        sta balle_lente
        dec vies
        beq @plus_de_vies
        lda #ETAT_ATTENTE
        sta etat
        jmp bruit_vie
@plus_de_vies:
        lda #ETAT_FINI
        sta etat
        lda #$F0                ; cache la balle sous l'écran
        sta balle_y
        jsr maj_record
        jsr arreter_musique
        jmp bruit_fin

; -----------------------------------------------------------------------------
;  maj_record — score > record ? Une comparaison à 3 chiffres se fait comme
;  dans le dictionnaire : centaines d'abord, et on ne regarde la suite qu'en
;  cas d'égalité.
; -----------------------------------------------------------------------------
maj_record:
        lda score_c
        cmp record_c
        bcc @non
        bne @oui
        lda score_d
        cmp record_d
        bcc @non
        bne @oui
        lda score_u
        cmp record_u
        bcc @non
        beq @non
@oui:
        lda score_u
        sta record_u
        lda score_d
        sta record_d
        lda score_c
        sta record_c
@non:
        rts


; =============================================================================
;  LE SON — un juke-box en 6502
; =============================================================================
demarrer_musique:
        lda #1
        sta mus_active
        sta mel_cpt
        sta bas_cpt
        lda #0
        sta mel_pos
        sta bas_pos
        rts

arreter_musique:
        lda #0
        sta mus_active
        lda #%00110000
        sta CARRE2_VOL
        lda #%10000000
        sta TRI_LIN
        rts

maj_musique:
        lda mus_active
        bne @active
        rts
@active:
        ; ---------- la MÉLODIE, sur le canal carré 2 ----------
        dec mel_cpt
        bne @basse
        ldx mel_pos
        lda melodie, x
        cmp #$FF
        bne @note_lue
        ldx #0
        lda melodie, x
@note_lue:
        beq @soupir
        tay
        lda #%10110110          ; onde carrée 50 %, volume 6
        sta CARRE2_VOL
        lda #$08
        sta CARRE2_BAL
        lda notes_bas, y
        sta CARRE2_BAS
        lda notes_haut, y
        ora #%11111000
        sta CARRE2_HAUT
        jmp @duree
@soupir:
        lda #%00110000
        sta CARRE2_VOL
@duree:
        inx
        lda melodie, x
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
        lda #%11111111
        sta TRI_LIN
        lda notes_bas, y
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

melodie:
        .byte NOTE_DO5,  12, NOTE_MI5, 12, NOTE_SOL5, 12, NOTE_MI5, 12
        .byte NOTE_LA4,  12, NOTE_DO5, 12, NOTE_MI5,  12, NOTE_DO5, 12
        .byte NOTE_FA4,  12, NOTE_LA4, 12, NOTE_DO5,  12, NOTE_LA4, 12
        .byte NOTE_SOL4, 12, NOTE_SI4, 12, NOTE_RE5,  12, NOTE_SI4, 12
        .byte $FF

basse:
        .byte NOTE_DO3, 48, NOTE_LA2, 48, NOTE_FA2, 48, NOTE_SOL2, 48
        .byte $FF

;                 sil  fa2  sol2 la2  do3  fa4  sol4 la4  si4  do5  ré5  mi5  fa5  sol5 la5
notes_bas:  .byte $00, $00, $74, $F8, $56, $3F, $1C, $FD, $E1, $D5, $BD, $A9, $9F, $8E, $7E
notes_haut: .byte $00, $05, $04, $03, $03, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00

; A = période octet bas, X = période octet haut, Y = durée en images
jouer_bip:
        sta CARRE1_BAS
        txa
        ora #%11111000
        sta CARRE1_HAUT
        lda #%10111010
        sta CARRE1_VOL
        lda #$08
        sta CARRE1_BAL
        sty bip_cpt
        rts

; A = période du bruit (0 = aigu ... 15 = grave), Y = durée en images
jouer_bruit:
        sta BRUIT_PER
        lda #%00111010
        sta BRUIT_VOL
        lda #%11111000
        sta BRUIT_LON
        sty bruit_cpt
        rts

maj_bruitages:
        lda bip_cpt
        beq @bruit
        dec bip_cpt
        bne @bruit
        lda #%00110000
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

; Le catalogue des sons :
bip_mur:                        ; toc discret (murs, briques solides)
        lda #$1C
        ldx #$01
        ldy #3
        jmp jouer_bip
bip_raquette:                   ; ponk (raquette, lancement, Start)
        lda #$FD
        ldx #$00
        ldy #4
        jmp jouer_bip
bip_brique:                     ; cling ! une brique de moins
        lda #$6A
        ldx #$00
        ldy #4
        jmp jouer_bip
bip_bonus:                      ; l'éclat d'une capsule attrapée
        lda #$8E
        ldx #$00
        ldy #6
        jmp jouer_bip
bip_victoire:                   ; niveau terminé !
        lda #$7E
        ldx #$00
        ldy #40
        jmp jouer_bip
bruit_vie:                      ; pshh : une vie s'envole
        lda #$0A
        ldy #20
        jmp jouer_bruit
bruit_fin:                      ; long grondement de game over
        lda #$0C
        ldy #45
        jmp jouer_bruit


; =============================================================================
;  maj_sprites — balle, raquette (3 OU 4 segments !), capsule
; =============================================================================
maj_sprites:
        lda etat
        cmp #ETAT_TITRE
        bne @en_jeu
        lda #$F0                ; au titre : tout le monde en coulisses
        sta $0200
        sta $0204
        sta $0208
        sta $020C
        sta $0210
        sta $0214
        rts
@en_jeu:
        ; --- Sprite 0 : la balle ------------------------------------------------
        lda balle_y
        sta $0200
        lda #TUILE_BALLE
        sta $0201
        lda #0
        sta $0202
        lda balle_x
        sta $0203

        ; --- Sprites 1-3 : la raquette -------------------------------------------
        lda #RAQUETTE_Y
        sta $0204
        sta $0208
        sta $020C
        lda #TUILE_RAQ_G
        sta $0205
        lda #TUILE_RAQ_M
        sta $0209
        ; le 3e segment : bout droit... sauf si la raquette est élargie,
        ; auquel cas c'est un segment du milieu de plus
        ldx #TUILE_RAQ_D
        lda raquette_large
        beq @segment3
        ldx #TUILE_RAQ_M
@segment3:
        stx $020D
        lda #1
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

        ; --- Sprite 4 : le 4e segment (raquette élargie seulement) ---------------
        lda raquette_large
        beq @cacher_segment4
        lda #RAQUETTE_Y
        sta $0210
        lda #TUILE_RAQ_D
        sta $0211
        lda #1
        sta $0212
        lda raquette_x
        clc
        adc #24
        sta $0213
        jmp @capsule
@cacher_segment4:
        lda #$F0
        sta $0210

@capsule:
        ; --- Sprite 5 : la capsule bonus ------------------------------------------
        lda capsule_type
        beq @cacher_capsule
        tay
        lda capsule_y
        sta $0214
        lda tuiles_capsules, y
        sta $0215
        lda #2                  ; palette 2 (or / rouge / blanc)
        sta $0216
        lda capsule_x
        sta $0217
        rts
@cacher_capsule:
        lda #$F0
        sta $0214
        rts

tuiles_capsules: .byte 0, TUILE_CAPS_LARGE, TUILE_CAPS_LENTE, TUILE_CAPS_VIE


; =============================================================================
;  NMI : exécutée automatiquement à CHAQUE VBlank (60 fois par seconde)
; =============================================================================
nmi:
        pha
        txa
        pha
        tya
        pha

        lda #$00                ; 1) les 64 sprites, d'un bloc
        sta OAMADDR
        lda #$02
        sta OAMDMA

        lda effacer_actif       ; 2) une brique à redessiner ? (v2 : effacer
        beq @pas_de_brique      ;    OU fissurer — les tuiles sont dans la file)
        bit PPUSTATUS
        lda effacer_hi
        sta PPUADDR
        lda effacer_lo
        sta PPUADDR
        lda effacer_tg
        sta PPUDATA
        lda effacer_td
        sta PPUDATA
        lda #0
        sta effacer_actif
@pas_de_brique:

        ; 3) Le bandeau : score, niveau, vies
        bit PPUSTATUS
        lda #$20
        sta PPUADDR
        lda #$44                ; $2044 = rangée 2, colonnes 4-6 : le score
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
        lda #$20
        sta PPUADDR
        lda #$4F                ; $204F = colonne 15 : le niveau
        sta PPUADDR
        lda niveau
        clc
        adc #TUILE_CHIFFRE_0
        sta PPUDATA
        lda #$20
        sta PPUADDR
        lda #$5B                ; $205B = colonne 27 : les vies
        sta PPUADDR
        lda vies
        clc
        adc #TUILE_CHIFFRE_0
        sta PPUDATA

        ; 4) Remise à zéro du défilement
        bit PPUSTATUS
        lda #0
        sta PPUSCROLL
        sta PPUSCROLL
        lda #%10000000
        sta PPUCTRL

        inc image

        pla
        tay
        pla
        tax
        pla
        rti

irq:
        rti


; =============================================================================
;  LES MOTIFS DE NIVEAUX — le level design, c'est ici !
; =============================================================================
;  Chaque motif est la grille complète : 6 rangées de 16 cases (15 briques
;  + 1 case de bourrage, toujours à 0). Les lettres :
;     V = vide   N = normale (1 pt)   S = solide (2 coups)   D = dorée (5 pts)
;  Dessinez vos propres niveaux — c'est fait pour !

V = 0
N = TYPE_NORMALE
S = TYPE_SOLIDE
D = TYPE_DOREE

motif_classique:                        ; niveau 1 : l'échauffement,
        .byte D,D,D,D,D,D,D,D,D,D,D,D,D,D,D, V   ; avec un toit doré
        .byte N,N,N,N,N,N,N,N,N,N,N,N,N,N,N, V
        .byte N,N,N,N,N,N,N,N,N,N,N,N,N,N,N, V
        .byte N,N,N,N,N,N,N,N,N,N,N,N,N,N,N, V
        .byte N,N,N,N,N,N,N,N,N,N,N,N,N,N,N, V
        .byte N,N,N,N,N,N,N,N,N,N,N,N,N,N,N, V

motif_damier:                           ; niveau 2 : le damier, gare aux
        .byte N,V,N,V,N,V,N,V,N,V,N,V,N,V,N, V   ; trous ! et un plancher
        .byte V,N,V,N,V,N,V,N,V,N,V,N,V,N,V, V   ; blindé
        .byte N,V,N,V,N,V,N,V,N,V,N,V,N,V,N, V
        .byte V,N,V,N,V,N,V,N,V,N,V,N,V,N,V, V
        .byte N,V,N,V,N,V,N,V,N,V,N,V,N,V,N, V
        .byte S,S,S,S,S,S,S,S,S,S,S,S,S,S,S, V

motif_coeur:                            ; niveau 3 : tout cœur, fourré à l'or
        .byte V,N,N,N,V,V,V,V,V,V,V,N,N,N,V, V
        .byte N,D,D,D,N,V,V,V,V,V,N,D,D,D,N, V
        .byte N,D,D,D,D,D,D,D,D,D,D,D,D,D,N, V
        .byte V,N,D,D,D,D,D,D,D,D,D,D,D,N,V, V
        .byte V,V,V,N,D,D,D,D,D,D,D,N,V,V,V, V
        .byte V,V,V,V,V,V,N,N,N,V,V,V,V,V,V, V

motif_forteresse:                       ; niveau 4 : la forteresse et ses
        .byte S,S,S,S,S,S,S,S,S,S,S,S,S,S,S, V   ; coffres au trésor
        .byte S,N,N,N,N,N,N,N,N,N,N,N,N,N,S, V
        .byte S,N,D,D,N,N,D,D,D,N,N,D,D,N,S, V
        .byte S,N,D,D,N,N,D,D,D,N,N,D,D,N,S, V
        .byte S,N,N,N,N,N,N,N,N,N,N,N,N,N,S, V
        .byte S,S,S,S,S,S,S,S,S,S,S,S,S,S,S, V


; =============================================================================
;  LES VECTEURS
; =============================================================================
.segment "VECTORS"
        .word nmi, reset, irq


; =============================================================================
;  LES GRAPHISMES (CHR-ROM) : nos tuiles, dessinées octet par octet !
; =============================================================================
;  Rappel : chaque tuile = 2 "plans" de 8 octets. Couleur d'un pixel :
;  plan0 seul → couleur 1, plan1 seul → couleur 2, les deux → couleur 3.

.macro TUILE_BLANCHE l0, l1, l2, l3, l4, l5, l6, l7
        .byte l0, l1, l2, l3, l4, l5, l6, l7   ; plan 0
        .byte l0, l1, l2, l3, l4, l5, l6, l7   ; plan 1
.endmacro

.segment "CHR"

; --- $00 : vide -----------------------------------------------------------------
        .res 16

; --- $01/$02 : brique NORMALE (couleur 1 : orange) -------------------------------
        .byte %00000000
        .byte %01111111
        .byte %01111111
        .byte %01111111
        .byte %01111111
        .byte %01111111
        .byte %01111111
        .byte %00000000
        .res 8
        .byte %00000000
        .byte %11111110
        .byte %11111110
        .byte %11111110
        .byte %11111110
        .byte %11111110
        .byte %11111110
        .byte %00000000
        .res 8

; --- $03 : mur (couleur 2 : gris) --------------------------------------------------
        .res 8
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111

; --- $04 : la balle (couleur 1) ----------------------------------------------------
        .byte %00111100
        .byte %01111110
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %01111110
        .byte %00111100
        .res 8

; --- $05-$07 : la raquette (couleur 2) ---------------------------------------------
        .res 8
        .byte %00000000
        .byte %00000000
        .byte %00111111
        .byte %01111111
        .byte %01111111
        .byte %00111111
        .byte %00000000
        .byte %00000000
        .res 8
        .byte %00000000
        .byte %00000000
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %00000000
        .byte %00000000
        .res 8
        .byte %00000000
        .byte %00000000
        .byte %11111100
        .byte %11111110
        .byte %11111110
        .byte %11111100
        .byte %00000000
        .byte %00000000

; --- $08/$09 : brique SOLIDE (couleur 2 : grise, rivets dorés en couleur 3) --------
        .byte %00000000         ; plan 0 : les rivets (couleur 3 avec plan 1)
        .byte %00000000
        .byte %00100100
        .byte %00000000
        .byte %00000000
        .byte %00100100
        .byte %00000000
        .byte %00000000
        .byte %00000000         ; plan 1 : le corps gris
        .byte %01111111
        .byte %01111111
        .byte %01111111
        .byte %01111111
        .byte %01111111
        .byte %01111111
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00100100
        .byte %00000000
        .byte %00000000
        .byte %00100100
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %11111110
        .byte %11111110
        .byte %11111110
        .byte %11111110
        .byte %11111110
        .byte %11111110
        .byte %00000000

; --- $0A/$0B : brique FISSURÉE (couleur 2, avec des trous : la lézarde !) ----------
        .res 8
        .byte %00000000
        .byte %01110111
        .byte %01101101
        .byte %01011011
        .byte %01110110
        .byte %01101101
        .byte %01011011
        .byte %00000000
        .res 8
        .byte %00000000
        .byte %11101110
        .byte %10110110
        .byte %11011010
        .byte %01101110
        .byte %10110110
        .byte %11011010
        .byte %00000000

; --- $0C/$0D : brique DORÉE (couleur 3 : l'or de la palette 1 !) --------------------
        TUILE_BLANCHE %00000000, %01111111, %01111111, %01111111, %01111111, %01111111, %01111111, %00000000
        TUILE_BLANCHE %00000000, %11111110, %11111110, %11111110, %11111110, %11111110, %11111110, %00000000

; --- $0E : capsule ÉLARGIR (pilule or, barre blanche) --------------------------------
        .byte %00000000         ; plan 0 : la pilule (couleur 1 = or)
        .byte %00000000
        .byte %01111110
        .byte %11111111
        .byte %11111111
        .byte %01111110
        .byte %00000000
        .byte %00000000
        .byte %00000000         ; plan 1 : la barre "élargir" (couleur 3)
        .byte %00000000
        .byte %00000000
        .byte %01111110
        .byte %01111110
        .byte %00000000
        .byte %00000000
        .byte %00000000

; --- $0F : capsule LENTE (pilule or, point blanc) ------------------------------------
        .byte %00000000
        .byte %00000000
        .byte %01111110
        .byte %11111111
        .byte %11111111
        .byte %01111110
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00011000
        .byte %00011000
        .byte %00000000
        .byte %00000000
        .byte %00000000

; --- $10-$19 : les chiffres 0 à 9 (couleur 3) -----------------------------------------
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

; --- $1A : capsule VIE (un petit cœur, couleur 2 = rouge) ------------------------------
        .res 8
        .byte %00000000
        .byte %01100110
        .byte %11111111
        .byte %11111111
        .byte %01111110
        .byte %00111100
        .byte %00011000
        .byte %00000000

; --- $1B : le tiret ---------------------------------------------------------------------
        TUILE_BLANCHE %00000000, %00000000, %00000000, %01111110, %00000000, %00000000, %00000000, %00000000

; --- on saute jusqu'à $20, où commence l'alphabet ($1C-$1F libres) ----------------------
        .res 4 * 16

; --- $20-$2C : les 13 lettres de nos textes (couleur 3) ---------------------------------
        TUILE_BLANCHE %00110000, %01111000, %11001100, %11001100, %11111100, %11001100, %11001100, %00000000  ; A
        TUILE_BLANCHE %11111100, %01100110, %01100110, %01111100, %01100110, %01100110, %11111100, %00000000  ; B
        TUILE_BLANCHE %00111100, %01100110, %11000000, %11000000, %11000000, %01100110, %00111100, %00000000  ; C
        TUILE_BLANCHE %11111000, %01101100, %01100110, %01100110, %01100110, %01101100, %11111000, %00000000  ; D
        TUILE_BLANCHE %11111110, %01100010, %01101000, %01111000, %01101000, %01100010, %11111110, %00000000  ; E
        TUILE_BLANCHE %01111000, %00110000, %00110000, %00110000, %00110000, %00110000, %01111000, %00000000  ; I
        TUILE_BLANCHE %00111000, %01101100, %11000110, %11000110, %11000110, %01101100, %00111000, %00000000  ; O
        TUILE_BLANCHE %11111100, %01100110, %01100110, %01111100, %01100000, %01100000, %11110000, %00000000  ; P
        TUILE_BLANCHE %01111000, %11001100, %11001100, %11001100, %11011100, %01111000, %00011100, %00000000  ; Q
        TUILE_BLANCHE %11111100, %01100110, %01100110, %01111100, %01101100, %01100110, %11100110, %00000000  ; R
        TUILE_BLANCHE %01111000, %11001100, %11100000, %01110000, %00011100, %11001100, %01111000, %00000000  ; S
        TUILE_BLANCHE %11111100, %10110100, %00110000, %00110000, %00110000, %00110000, %01111000, %00000000  ; T
        TUILE_BLANCHE %11001100, %11001100, %11001100, %11001100, %11001100, %11001100, %01111100, %00000000  ; U

; Le reste des 8 Ko de CHR-ROM est rempli de zéros par l'éditeur de liens.
; Fin du fichier — et cette fois, vous avez un jeu d'arcade complet !
