; =============================================================================
;  CASSE-BRIQUE SNES — le passage à la 16 bits (niveau 4 du cours)
; =============================================================================
;
;  Le même casse-brique que la version NES (../casse-brique-nes/), TOUTES
;  features comprises : 5 zones de rebond, capsules, multiball, briques
;  solides et dorées, niveaux, écran titre, record. Mais sur Super Nintendo :
;
;   - le CPU est un 65816 : un 6502 qui a grandi. Il démarre en mode
;     "émulation" (100 % compatible 6502 !) puis on le bascule en mode natif
;     (CLC + XCE) où A, X et Y peuvent passer en 16 bits (REP/SEP). Notre
;     choix pédagogique : rester en 8 bits partout — la logique du jeu est
;     LE MÊME code que sur NES, à quelques adresses près. Tout ce que vous
;     avez appris sert encore.
;   - le PPU est un monstre : tuiles de 16 couleurs (4 bits/pixel), 8
;     palettes de fond + 8 de sprites, 64 Ko de VRAM, la même tuile de
;     brique devient orange, acier ou or selon la palette que la tilemap
;     lui donne. Les canaux de DMA chargent tout ça en un éclair.
;   - le HDMA change des registres À CHAQUE LIGNE de l'écran : notre fond
;     est un dégradé bleu nuit → violet, gratuit pour le CPU. C'est LA
;     signature visuelle de la console.
;   - la manette se lit TOUTE SEULE (auto-joypad). Et par un heureux hasard
;     d'ingénierie, l'octet $4219 a exactement la même disposition de bits
;     que notre variable `boutons` sur NES. Zéro adaptation.
;
;  Le son vient du SPC700 : un second processeur complet, avec sa propre
;  RAM, auquel on téléverse un pilote au démarrage. Tout est raconté dans
;  ../snes-commun/son.s — la partition NES rejoue, note pour note.
;
;  Les graphismes ne sont plus écrits en binaire dans le source : à 16
;  couleurs par tuile ce serait illisible. L'atelier tools/make_gfx.py
;  transforme du pixel-art texte en binaires, incorporés par .incbin.
; =============================================================================

.setcpu "65816"

; --- Les registres du PPU SNES (une sélection commentée) ----------------------
LUMIERE   = $2100   ; $0F = écran allumé plein feux, $8F = éteint (forced blank)
OBSEL     = $2101   ; taille des sprites + adresse de leurs tuiles
OAMADDL   = $2102
OAMADDH   = $2103
BGMODE    = $2105   ; nous : mode 1 (2 fonds 16 couleurs + 1 fond 4 couleurs)
BG1SC     = $2107   ; adresse de la tilemap du fond 1
BG12NBA   = $210B   ; adresse des tuiles des fonds 1 et 2
BG1HOFS   = $210D
BG1VOFS   = $210E
VMAIN     = $2115   ; $80 = l'adresse VRAM avance après l'octet HAUT
VMADDL    = $2116   ; adresse VRAM — attention, comptée en MOTS de 16 bits !
VMADDH    = $2117
VMDATAL   = $2118   ; données VRAM : octet bas (la tuile)...
VMDATAH   = $2119   ; ...et haut (la palette), qui déclenche l'incrément
CGADD     = $2121   ; adresse dans la mémoire des couleurs (CGRAM)
CGDATA    = $2122
TM        = $212C   ; les couches affichées ($11 = fond 1 + sprites)
NMITIMEN  = $4200   ; $81 = NMI au VBlank + lecture auto des manettes
MDMAEN    = $420B   ; déclencheur des DMA (1 bit par canal)
HDMAEN    = $420C   ; activation des HDMA
RDNMI     = $4210   ; à LIRE dans la nmi pour acquitter l'interruption
HVBJOY    = $4212   ; bit 0 : la lecture auto des manettes est en cours
JOY1H     = $4219   ; manette 1 : B Y Sel St ↑ ↓ ← → — comme sur NES !

DMAP0 = $4300       ; le canal DMA 0 : nos transferts éclair
BBAD0 = $4301
A1T0L = $4302
A1T0H = $4303
A1B0  = $4304
DAS0L = $4305
DAS0H = $4306
DMAP1 = $4310       ; le canal 1, réservé au HDMA du dégradé
BBAD1 = $4311
A1T1L = $4312
A1T1H = $4313
A1B1  = $4314

; --- Les boutons ($4219 : disposition identique à la NES) ----------------------
BTN_A      = %10000000          ; (physiquement, le bouton B de la SNES)
BTN_START  = %00010000
BTN_GAUCHE = %00000010
BTN_DROITE = %00000001

; --- La carte de la mémoire vidéo (adresses en MOTS) ----------------------------
VRAM_TILEMAP = $0400
VRAM_TUILES  = $1000
VRAM_SPRITES = $4000

; --- Tuiles du décor et attributs (octet haut de la tilemap = palette << 2) -----
TUILE_VIDE      = $00
TUILE_MUR       = $07
TUILE_CHIFFRE_0 = $10
TIRET           = $1B
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
L_G = $2D
L_M = $2E
L_V = $2F
ESPACE = $00
PAL_MURS   = $00                ; palette 0 (acier + texte)
PAL_ORANGE = $04                ; palette 1
PAL_ACIER  = $08                ; palette 2
PAL_OR     = $0C                ; palette 3

; --- Tuiles des sprites et leurs attributs --------------------------------------
OBJ_BALLE = $00
OBJ_RAQ_G = $01
OBJ_RAQ_M = $02
OBJ_RAQ_D = $03
OBJ_CAPS  = $04                 ; +0 élargir, +1 lente, +2 vie, +3 multiball
ATTR_BALLE = $30                ; priorité 3, palette de sprites 0
ATTR_RAQ   = $32                ; palette 1
ATTR_CAPS  = $34                ; palette 2

; --- Types, capsules, états : identiques à la version NES ------------------------
TYPE_NORMALE  = 1
TYPE_SOLIDE   = 2
TYPE_DOREE    = 3
TYPE_FISSUREE = 4
CAPS_LARGE = 1
CAPS_LENTE = 2
CAPS_VIE   = 3
CAPS_MULTI = 4
ETAT_ATTENTE = 0
ETAT_JEU     = 1
ETAT_FINI    = 2
ETAT_TITRE   = 3
ETAT_PAUSE   = 4

; --- La géométrie : l'écran SNES fait 224 lignes (240 sur NES) --------------------
;  Tout glisse d'une rangée : bandeau rangée 1, mur rangée 2, briques 4-9.
RAQUETTE_Y    = 200
BALLE_X_MIN   = 8
BALLE_X_MAX   = 240
BALLE_Y_MIN   = 24
BALLE_Y_PERDU = 216

OAM_OMBRE = $0200               ; le brouillon des sprites : 512 + 32 octets
                                ; envoyés par DMA à chaque VBlank


; -----------------------------------------------------------------------------
;  VARIABLES (la "page directe" du 65816 = notre bonne vieille page zéro)
; -----------------------------------------------------------------------------
.zeropage

boutons:           .res 1
anciens:           .res 1
presses:           .res 1
image:             .res 1
etat:              .res 1

balle_x:           .res 1
balle_xs:          .res 1
balle_y:           .res 1
balle_ys:          .res 1
balle_dx_lo:       .res 1
balle_dx_hi:       .res 1
balle_dy_lo:       .res 1
balle_dy_hi:       .res 1

raquette_x:        .res 1
vies:              .res 1
niveau:            .res 1
score_u:           .res 1
score_d:           .res 1
score_c:           .res 1
record_u:          .res 1
record_d:          .res 1
record_c:          .res 1
briques_restantes: .res 1

; File d'attente vidéo : une brique à redessiner au prochain VBlank
effacer_actif:     .res 1
effacer_vlo:       .res 1       ; adresse VRAM (en mots), octet bas
effacer_vhi:       .res 1
effacer_t1:        .res 1       ; case gauche : tuile + palette
effacer_a1:        .res 1
effacer_t2:        .res 1       ; case droite
effacer_a2:        .res 1

capsule_type:      .res 1
capsule_x:         .res 1
capsule_y:         .res 1
capsule_suivante:  .res 1
raquette_large:    .res 1
balle_lente:       .res 1
pause_cpt:         .res 1
vitesse_extra:     .res 1

col_tuile:         .res 1
lig_tuile:         .res 1
col_brique:        .res 1
lig_brique:        .res 1
adr_lo:            .res 1
adr_hi:            .res 1
tmp_lo:            .res 1
tmp_hi:            .res 1
tmp2:              .res 1
motif_ptr:         .res 2

go_actif:          .res 1
balle_perdue:      .res 1
balle2_active:     .res 1
balle2_x:          .res 1       ; les 8 octets de la balle 2, dans le MÊME
balle2_xs:         .res 1       ; ordre que la balle 1 : echanger_balles
balle2_y:          .res 1       ; y compte !
balle2_ys:         .res 1
balle2_dx_lo:      .res 1
balle2_dx_hi:      .res 1
balle2_dy_lo:      .res 1
balle2_dy_hi:      .res 1

.bss
grille: .res 96


; =============================================================================
;  L'EN-TÊTE de cartouche SNES
; =============================================================================
.segment "SNESHEADER"
        .byte "CASSE-BRIQUE 2026    "   ; 21 caractères exactement
        .byte $20                       ; LoROM, vitesse lente
        .byte $00                       ; pas de puce annexe
        .byte $05                       ; taille : 32 Ko (2^5 Ko)
        .byte $00                       ; pas de sauvegarde
        .byte $01                       ; Amérique (NTSC)
        .byte $00
        .byte $00                       ; version
        .word $FFFF                     ; sommes de contrôle : recalculées par
        .word $0000                     ; tools/checksum.py après l'édition


.segment "CODE"

; =============================================================================
;  RESET — réveiller un 65816
; =============================================================================
reset:
        sei
        clc
        xce                     ; LE geste historique : on quitte le mode
        sep #$30                ; émulation 6502 pour le mode natif... et on
        .a8                     ; garde A, X, Y en 8 bits : notre code NES
        .i8                     ; va tourner presque tel quel !
        ldx #$FF
        txs                     ; pile en $01FF, comme à la maison

        lda #$8F
        sta LUMIERE             ; écran éteint : on prépare tout au calme

        ; --- nettoyer la RAM de travail ($0000-$07FF) -------------------------
        ldx #0
        txa
@vider_ram:
        sta $0000, x
        sta $0100, x
        sta $0300, x
        sta $0500, x
        sta $0600, x
        sta $0700, x
        inx
        bne @vider_ram

        ; --- le brouillon des sprites : tout le monde en coulisses ------------
        ;  Un sprite dont le Y vaut 240 est sous l'écran (224 lignes).
        lda #$F0
@cacher_sprites:
        sta $0200, x            ; pages $0200-$03FF : les 128 sprites
        sta $0300, x
        inx
        bne @cacher_sprites
@vider_haute:                   ; la table haute ($0400-$041F) à zéro :
        stz $0400, x            ; "petits sprites, bit 8 de X à zéro"
        inx
        cpx #$20
        bne @vider_haute

        ; --- configurer le PPU --------------------------------------------------
        lda #$01
        sta BGMODE              ; mode 1
        lda #(VRAM_TILEMAP >> 10) << 2
        sta BG1SC
        lda #VRAM_TUILES >> 12
        sta BG12NBA
        lda #VRAM_SPRITES >> 13
        sta OBSEL
        lda #$11
        sta TM                  ; fond 1 + sprites
        stz BG1HOFS             ; défilement nul (chaque registre se règle
        stz BG1HOFS             ; en DEUX écritures : octet bas, octet haut)
        stz BG1VOFS
        stz BG1VOFS

        ; --- vider les 64 Ko de VRAM : un DMA à source FIGÉE sur un mot nul ----
        lda #$80
        sta VMAIN
        stz VMADDL
        stz VMADDH
        lda #$09                ; mode 1 (alterne $2118/$2119), source fixe
        sta DMAP0
        lda #$18
        sta BBAD0
        lda #<mot_zero
        sta A1T0L
        lda #>mot_zero
        sta A1T0H
        stz A1B0
        stz DAS0L               ; taille 0 = 65 536 octets : toute la VRAM
        stz DAS0H
        lda #$01
        sta MDMAEN              ; ... 64 Ko effacés le temps de lire ceci.

        ; --- charger les graphismes et les couleurs (générés par make_gfx) -----
        lda #<VRAM_TUILES
        sta VMADDL
        lda #>VRAM_TUILES
        sta VMADDH
        lda #$01                ; mode 1 : octets alternés vers $2118/$2119
        sta DMAP0
        lda #<gfx_bg
        sta A1T0L
        lda #>gfx_bg
        sta A1T0H
        lda #<(fin_gfx_bg - gfx_bg)
        sta DAS0L
        lda #>(fin_gfx_bg - gfx_bg)
        sta DAS0H
        lda #$01
        sta MDMAEN

        lda #<VRAM_SPRITES
        sta VMADDL
        lda #>VRAM_SPRITES
        sta VMADDH
        lda #<gfx_obj
        sta A1T0L
        lda #>gfx_obj
        sta A1T0H
        lda #<(fin_gfx_obj - gfx_obj)
        sta DAS0L
        lda #>(fin_gfx_obj - gfx_obj)
        sta DAS0H
        lda #$01
        sta MDMAEN

        stz CGADD               ; les 256 couleurs, d'un bloc
        stz DMAP0               ; mode 0 : octet par octet...
        lda #$22
        sta BBAD0               ; ...vers CGDATA
        lda #<palettes
        sta A1T0L
        lda #>palettes
        sta A1T0H
        stz DAS0L
        lda #$02                ; 512 octets
        sta DAS0H
        lda #$01
        sta MDMAEN

        ; --- le HDMA du dégradé : la couleur du fond change toutes les 8 lignes -
        ;  Mode 3 : chaque entrée de la table écrit $2121,$2121,$2122,$2122 —
        ;  c'est-à-dire "adresse couleur 0" puis la couleur, ligne après
        ;  ligne, pendant que le CPU fait TOUT AUTRE CHOSE. Magique.
        lda #$03
        sta DMAP1
        lda #$21
        sta BBAD1
        lda #<gradient
        sta A1T1L
        lda #>gradient
        sta A1T1H
        stz A1B1
        lda #$02
        sta HDMAEN

        ; --- réveiller le SECOND ordinateur : le SPC700 -------------------------
        ;  Avant d'activer la NMI : le téléversement du pilote son prend
        ;  quelques millisecondes de dialogue ininterrompu (voir son.s).
        jsr initialiser_son
        jsr demarrer_musique

        ; --- le décor permanent, l'écran titre, et rideau -----------------------
        jsr dessiner_cadre
        jsr dessiner_ecran_titre
        lda #ETAT_TITRE
        sta etat
        lda #3
        sta vies

        jsr allumer_ecran
        jmp principale

mot_zero: .word 0


eteindre_ecran:
        lda #$8F
        sta LUMIERE
        stz NMITIMEN
        rts

allumer_ecran:
        lda #$81                ; NMI au VBlank + lecture auto des manettes
        sta NMITIMEN
        lda #$0F
        sta LUMIERE
        rts


; =============================================================================
;  LE DÉCOR PERMANENT — écrit dans la tilemap ($2116/8/9, l'équivalent SNES
;  de PPUADDR/PPUDATA, en deux fois plus riche : chaque case = tuile + palette)
; =============================================================================
dessiner_cadre:
        ; --- tout vider : la tilemap fait 32×32 = 1024 cases --------------------
        lda #<VRAM_TILEMAP
        sta VMADDL
        lda #>VRAM_TILEMAP
        sta VMADDH
        ldx #4
        ldy #0
@vider:
        stz VMDATAL
        stz VMDATAH
        iny
        bne @vider
        dex
        bne @vider

        ; --- le mur du haut : rangée 2 -------------------------------------------
        lda #<(VRAM_TILEMAP + 2*32)
        sta VMADDL
        lda #>(VRAM_TILEMAP + 2*32)
        sta VMADDH
        ldx #32
@mur_haut:
        lda #TUILE_MUR
        sta VMDATAL
        lda #PAL_MURS
        sta VMDATAH
        dex
        bne @mur_haut

        ; --- les murs latéraux : colonnes 0 et 31, rangées 3 à 27 ----------------
        ;  Le même jeu d'adresses 16 bits en deux octets que sur NES.
        lda #<(VRAM_TILEMAP + 3*32)
        sta adr_lo
        lda #>(VRAM_TILEMAP + 3*32)
        sta adr_hi
        ldx #25
@murs:
        lda adr_lo
        sta VMADDL
        lda adr_hi
        sta VMADDH
        lda #TUILE_MUR
        sta VMDATAL
        lda #PAL_MURS
        sta VMDATAH
        lda adr_lo
        clc
        adc #31
        sta VMADDL
        lda adr_hi
        adc #0
        sta VMADDH
        lda #TUILE_MUR
        sta VMDATAL
        lda #PAL_MURS
        sta VMDATAH
        lda adr_lo
        clc
        adc #32
        sta adr_lo
        lda adr_hi
        adc #0
        sta adr_hi
        dex
        bne @murs
        rts

; Adresses VRAM (en mots) de la colonne 1 de chaque rangée de briques (4-9)
lignes_vram_lo: .byte $81, $A1, $C1, $E1, $01, $21
lignes_vram_hi: .byte $04, $04, $04, $04, $05, $05


; =============================================================================
;  L'ÉCRAN TITRE
; =============================================================================
dessiner_ecran_titre:
        jsr vider_interieur

        lda #$8A                ; rangée 12, colonne 10 ($0400 + 12×32 + 10)
        sta VMADDL
        lda #$05
        sta VMADDH
        ldx #0
@titre:
        lda texte_titre, x
        sta VMDATAL
        stz VMDATAH
        inx
        cpx #12
        bne @titre

        lda #$EB                ; rangée 15, colonne 11 : RECORD puis, dans la
        sta VMADDL              ; foulée (l'adresse avance seule), les chiffres
        lda #$05
        sta VMADDH
        ldx #0
@record:
        lda texte_record, x
        sta VMDATAL
        stz VMDATAH
        inx
        cpx #7
        bne @record
        lda record_c
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        stz VMDATAH
        lda record_d
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        stz VMDATAH
        lda record_u
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        stz VMDATAH

        lda #$48                ; rangée 18, colonne 8
        sta VMADDL
        lda #$06
        sta VMADDH
        ldx #0
@appuie:
        lda texte_appuie, x
        sta VMDATAL
        stz VMDATAH
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
texte_gameover:
        .byte L_G, L_A, L_M, L_E, ESPACE, L_O, L_V, L_E, L_R


vider_interieur:
        lda #<(VRAM_TILEMAP + 3*32)
        sta adr_lo
        lda #>(VRAM_TILEMAP + 3*32)
        sta adr_hi
        ldx #25                 ; rangées 3 à 27
@rangee:
        lda adr_lo
        clc
        adc #1                  ; colonne 1 : on épargne les murs
        sta VMADDL
        lda adr_hi
        adc #0
        sta VMADDH
        ldy #30
@case:
        stz VMDATAL
        stz VMDATAH
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
;  DÉMARRER UNE PARTIE, CHARGER UN NIVEAU (logique NES à l'identique)
; =============================================================================
demarrer_partie:
        lda #0
        sta score_u
        sta score_d
        sta score_c
        sta capsule_type
        sta raquette_large
        sta balle_lente
        sta balle2_active
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

charger_niveau:
        lda niveau
        sec
        sbc #1
        and #%00000011
        tax
        lda motifs_lo, x
        sta motif_ptr
        lda motifs_hi, x
        sta motif_ptr+1

        ldy #0
@copier:
        lda (motif_ptr), y
        sta grille, y
        iny
        cpy #96
        bne @copier

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
        asl a
        sta vitesse_extra

        jsr vider_interieur
        jsr dessiner_briques
        rts

motifs_lo: .byte <motif_classique, <motif_damier, <motif_coeur, <motif_forteresse
motifs_hi: .byte >motif_classique, >motif_damier, >motif_coeur, >motif_forteresse

; -----------------------------------------------------------------------------
;  dessiner_briques — et ici, la SNES nous gâte : la MÊME tuile de brique
;  devient orange, acier ou or par le simple octet de palette de la tilemap.
; -----------------------------------------------------------------------------
dessiner_briques:
        lda #0
        sta lig_brique
@rangee:
        ldy lig_brique
        lda lignes_vram_lo, y
        sta VMADDL
        lda lignes_vram_hi, y
        sta VMADDH
        tya
        asl a
        asl a
        asl a
        asl a
        tax                     ; X = index de la rangée dans la grille
        lda #15
        sta tmp2
@brique:
        ldy grille, x
        lda tuiles_brique_g, y
        sta VMDATAL
        lda attr_brique, y
        sta VMDATAH
        lda tuiles_brique_d, y
        sta VMDATAL
        lda attr_brique, y
        sta VMDATAH
        inx
        dec tmp2
        bne @brique
        inc lig_brique
        lda lig_brique
        cmp #6
        bne @rangee
        rts

;                      vide  normale  solide  dorée  fissurée
tuiles_brique_g: .byte $00,  $01,     $03,    $01,   $05
tuiles_brique_d: .byte $00,  $02,     $04,    $02,   $06
attr_brique:     .byte $00,  PAL_ORANGE, PAL_ACIER, PAL_OR, PAL_ACIER
points_brique:   .byte 0, 1, 0, 5, 2


; =============================================================================
;  LA BOUCLE PRINCIPALE (le portage NES, ligne pour ligne)
; =============================================================================
principale:
        jsr attendre_nmi
        jsr maj_musique         ; le moteur NES, qui télégraphie au SPC700
        jsr maj_bruitages
        jsr lire_manette
        jsr maj_raquette

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

        ; --- FINI : Start ramène au titre -----------------------------------
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
        sta vies
        jsr demarrer_musique
        jsr allumer_ecran
        jmp @dessiner

@au_titre:
        lda presses
        and #BTN_START
        bne @lancer_partie
        jmp @dessiner
@lancer_partie:
        jsr demarrer_partie
        jsr bip_raquette
        jmp @dessiner

@entracte:
        dec pause_cpt
        beq @niveau_suivant
        jmp @dessiner
@niveau_suivant:
        inc niveau
        lda #0
        sta capsule_type
        sta raquette_large
        sta balle_lente
        sta balle2_active
        jsr eteindre_ecran
        jsr charger_niveau
        jsr allumer_ecran
        lda #ETAT_ATTENTE
        sta etat
        jmp @dessiner

@en_attente:
        lda raquette_x
        clc
        adc #8
        sta balle_x
        lda #RAQUETTE_Y - 8
        sta balle_y
        lda boutons
        and #BTN_A
        beq @dessiner
        lda #ETAT_JEU
        sta etat
        jsr bip_raquette
        lda #0
        sec
        sbc vitesse_extra
        sta balle_dy_lo
        lda #$FE
        sbc #0
        sta balle_dy_hi
        stz balle_dx_lo
        lda #1
        sta balle_dx_hi
        lda image
        and #1
        beq @dessiner
        lda #$FF
        sta balle_dx_hi
        stz balle_dx_lo
        jmp @dessiner

@en_jeu:
        jsr maj_balles
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
;  lire_manette — l'auto-joypad fait tout : on attend juste qu'il ait fini
; -----------------------------------------------------------------------------
lire_manette:
        lda boutons
        sta anciens
@occupe:
        lda HVBJOY
        and #1
        bne @occupe             ; la console lit encore les manettes
        lda JOY1H               ; ...et voilà. Pas de LSR/ROL cette fois !
        sta boutons
        lda anciens
        eor #$FF
        and boutons
        sta presses
        rts


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
;  LES BALLES (virgule fixe 8.8, multiball : voir la version NES pour le cours)
; =============================================================================
maj_balles:
        lda #0
        sta balle_perdue
        jsr deplacer_balle
        lda balle_perdue
        beq @balle_2
        lda balle2_active
        bne @remplacer
        jmp perdre_vie
@remplacer:
        ldx #7
@promouvoir:
        lda balle2_x, x
        sta balle_x, x
        dex
        bpl @promouvoir
        stz balle2_active
        rts
@balle_2:
        lda balle2_active
        beq @fin
        stz balle_perdue
        jsr echanger_balles
        jsr deplacer_balle
        jsr echanger_balles
        lda balle_perdue
        beq @fin
        stz balle2_active
@fin:
        rts

echanger_balles:
        ldx #7
@boucle:
        lda balle_x, x
        tay
        lda balle2_x, x
        sta balle_x, x
        tya
        sta balle2_x, x
        dex
        bpl @boucle
        rts

deplacer_balle:
        lda balle_lente
        beq @pleine_vitesse
        lda image
        and #1
        bne @pleine_vitesse
        rts
@pleine_vitesse:
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
        lda balle_dx_hi
        bpl @pas_mur_gauche
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
        lda #1
        sta balle_perdue
        rts
@pas_perdue:
        jsr collision_briques
        jsr collision_raquette
        rts

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
;  collision_briques — la zone des briques occupe les rangées de tuiles 4-9
; =============================================================================
collision_briques:
        lda balle_x
        clc
        adc #4
        lsr a
        lsr a
        lsr a
        sta col_tuile
        lda balle_y
        clc
        adc #4
        lsr a
        lsr a
        lsr a
        sta lig_tuile

        lda lig_tuile
        sec
        sbc #4                  ; rangées 4-9 (l'écran a une rangée de moins)
        cmp #6
        bcs @rien
        sta lig_brique
        lda col_tuile
        beq @rien
        cmp #31
        bcs @rien
        sec
        sbc #1
        lsr a
        sta col_brique

        lda lig_brique
        asl a
        asl a
        asl a
        asl a
        clc
        adc col_brique
        tax
        lda grille, x
        beq @rien
        sta tmp2

        jsr inverser_dy

        lda tmp2
        cmp #TYPE_SOLIDE
        bne @detruire
        lda #TYPE_FISSUREE
        sta grille, x
        ldy #TYPE_FISSUREE
        jsr programmer_redessin
        jmp bip_mur             ; "toc" : du solide !

@detruire:
        lda #0
        sta grille, x
        ldy tmp2
        lda points_brique, y
        jsr ajouter_points
        jsr bip_brique
        ldy #0
        jsr programmer_redessin
        jsr lacher_capsule

        dec briques_restantes
        bne @rien
        lda #ETAT_PAUSE
        sta etat
        lda #120
        sta pause_cpt
        jsr bip_victoire
@rien:
        rts

; Y = le type à AFFICHER (0 = effacer, TYPE_FISSUREE = fissurer)
programmer_redessin:
        lda tuiles_brique_g, y
        sta effacer_t1
        lda tuiles_brique_d, y
        sta effacer_t2
        lda attr_brique, y
        sta effacer_a1
        sta effacer_a2
        lda col_brique
        asl a
        ldy lig_brique
        clc
        adc lignes_vram_lo, y
        sta effacer_vlo
        lda lignes_vram_hi, y
        adc #0
        sta effacer_vhi
        lda #1
        sta effacer_actif
        rts

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
        stz score_u
        inc score_d
        lda score_d
        cmp #10
        bne @fini
        stz score_d
        inc score_c
        lda score_c
        cmp #10
        bne @fini
        stz score_c
@fini:
        rts


; =============================================================================
;  collision_raquette — les 5 zones, comme sur NES
; =============================================================================
collision_raquette:
        lda balle_dy_hi
        bpl @descend
        rts
@descend:
        lda balle_y
        cmp #RAQUETTE_Y - 8
        bcc @rate
        cmp #RAQUETTE_Y
        bcs @rate
        lda balle_x
        sec
        sbc raquette_x
        clc
        adc #7
        ldx raquette_large
        beq @largeur_normale
        cmp #39
        bcs @rate
        sec
        sbc #4
        bcs @impact_connu
        lda #0
        jmp @impact_connu
@largeur_normale:
        cmp #31
        bcs @rate
@impact_connu:
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
        iny
@zone_choisie:
        cpy #2
        bne @dx_table
        lda balle_dx_hi
        bmi @centre_gauche
        lda #$80
        sta balle_dx_lo
        stz balle_dx_hi
        jmp @regler_dy
@centre_gauche:
        lda #$80
        sta balle_dx_lo
        lda #$FF
        sta balle_dx_hi
        jmp @regler_dy
@dx_table:
        lda zones_dx_lo, y
        sta balle_dx_lo
        lda zones_dx_hi, y
        sta balle_dx_hi
@regler_dy:
        lda zones_dy_lo, y
        sec
        sbc vitesse_extra
        sta balle_dy_lo
        lda zones_dy_hi, y
        sbc #0
        sta balle_dy_hi
        ; --- le son suit la zone (v2.1 NES) : grave au bord, clair au centre.
        ;     Sur SNES, plus de périodes APU : un simple NUMÉRO de note.
        lda sons_zone, y
        ldy #4
        jsr jouer_bip
@rate:
        rts

sons_zone: .byte NOTE_SOL4, NOTE_LA4, NOTE_DO5, NOTE_LA4, NOTE_SOL4

zones_dx_lo: .byte $00, $80, $80, $80, $00
zones_dx_hi: .byte $FE, $FE, $00, $01, $02
zones_dy_lo: .byte $00, $40, $C0, $40, $00
zones_dy_hi: .byte $FF, $FE, $FD, $FE, $FF


; =============================================================================
;  LES CAPSULES ET LE MULTIBALL (logique NES inchangée)
; =============================================================================
lacher_capsule:
        lda capsule_type
        bne @fin
        lda image
        eor balle_x
        and #%00000011
        bne @fin
        lda capsule_suivante
        clc
        adc #1
        cmp #5
        bcc @type_ok
        lda #1
@type_ok:
        sta capsule_suivante
        sta capsule_type
        lda col_brique
        asl a
        asl a
        asl a
        asl a
        clc
        adc #12
        sta capsule_x
        lda lig_brique
        asl a
        asl a
        asl a
        clc
        adc #32                 ; le haut des briques est à y = 32
        sta capsule_y
@fin:
        rts

maj_capsule:
        lda capsule_type
        beq @fin
        inc capsule_y
        lda capsule_y
        cmp #BALLE_Y_PERDU
        bcc @pas_perdue
        stz capsule_type
        rts
@pas_perdue:
        cmp #RAQUETTE_Y - 8
        bcc @fin
        cmp #RAQUETTE_Y
        bcs @fin
        lda capsule_x
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
        jsr bip_bonus
        lda capsule_type
        cmp #CAPS_LARGE
        beq @elargir
        cmp #CAPS_LENTE
        beq @ralentir
        cmp #CAPS_VIE
        beq @une_vie
        lda balle2_active       ; CAPS_MULTI
        bne @consommer
        ldx #7
@jumeler:
        lda balle_x, x
        sta balle2_x, x
        dex
        bpl @jumeler
        lda balle2_dx_lo
        eor #$FF
        clc
        adc #1
        sta balle2_dx_lo
        lda balle2_dx_hi
        eor #$FF
        adc #0
        sta balle2_dx_hi
        lda #1
        sta balle2_active
        jmp @consommer
@une_vie:
        lda vies
        cmp #9
        bcs @consommer
        inc vies
        jmp @consommer
@elargir:
        lda #150
        sta raquette_large
        jmp @consommer
@ralentir:
        lda #150
        sta balle_lente
@consommer:
        stz capsule_type
@fin:
        rts

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


perdre_vie:
        lda #0
        sta capsule_type
        sta raquette_large
        sta balle_lente
        sta balle2_active
        dec vies
        beq @plus_de_vies
        lda #ETAT_ATTENTE
        sta etat
        jmp bruit_vie
@plus_de_vies:
        lda #ETAT_FINI
        sta etat
        lda #$F0
        sta balle_y
        lda #1
        sta go_actif
        jsr maj_record
        jsr arreter_musique
        jmp bruit_fin

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
;  maj_sprites — l'OAM SNES : X, Y, tuile, attributs (l'ordre change de la NES !)
; =============================================================================
maj_sprites:
        lda etat
        cmp #ETAT_TITRE
        bne @en_jeu
        lda #$F0                ; au titre : tout le monde en coulisses
        sta $0201
        sta $0205
        sta $0209
        sta $020D
        sta $0211
        sta $0215
        sta $0219
        rts
@en_jeu:
        ; --- sprite 0 : la balle ------------------------------------------------
        lda balle_x
        sta $0200
        lda balle_y
        sta $0201
        lda #OBJ_BALLE
        sta $0202
        lda #ATTR_BALLE
        sta $0203

        ; --- sprites 1-4 : la raquette (3 segments, 4 si élargie) ---------------
        lda raquette_x
        sta $0204
        clc
        adc #8
        sta $0208
        clc
        adc #8
        sta $020C
        lda #RAQUETTE_Y
        sta $0205
        sta $0209
        sta $020D
        lda #OBJ_RAQ_G
        sta $0206
        lda #OBJ_RAQ_M
        sta $020A
        ldx #OBJ_RAQ_D
        lda raquette_large
        beq @segment3
        ldx #OBJ_RAQ_M
@segment3:
        stx $020E
        lda #ATTR_RAQ
        sta $0207
        sta $020B
        sta $020F
        lda raquette_large
        beq @cacher_segment4
        lda raquette_x
        clc
        adc #24
        sta $0210
        lda #RAQUETTE_Y
        sta $0211
        lda #OBJ_RAQ_D
        sta $0212
        lda #ATTR_RAQ
        sta $0213
        jmp @capsule
@cacher_segment4:
        lda #$F0
        sta $0211

@capsule:
        lda capsule_type
        beq @cacher_capsule
        clc
        adc #OBJ_CAPS - 1
        sta $0216
        lda capsule_x
        sta $0214
        lda capsule_y
        sta $0215
        lda #ATTR_CAPS
        sta $0217
        jmp @balle_2
@cacher_capsule:
        lda #$F0
        sta $0215

@balle_2:
        lda balle2_active
        beq @cacher_balle_2
        lda balle2_x
        sta $0218
        lda balle2_y
        sta $0219
        lda #OBJ_BALLE
        sta $021A
        lda #ATTR_BALLE
        sta $021B
        rts
@cacher_balle_2:
        lda #$F0
        sta $0219
        rts


; =============================================================================
;  NMI — à chaque VBlank : acquitter, DMA des sprites, files vidéo, bandeau
; =============================================================================
nmi:
        pha
        phx
        phy
        lda RDNMI               ; OBLIGATOIRE : lire $4210 acquitte la NMI

        ; --- 1) les 544 octets de sprites, d'un souffle de DMA ------------------
        stz OAMADDL
        stz OAMADDH
        stz DMAP0               ; mode 0, octet par octet
        lda #$04                ; vers $2104 (OAMDATA)
        sta BBAD0
        lda #<OAM_OMBRE
        sta A1T0L
        lda #>OAM_OMBRE
        sta A1T0H
        stz A1B0
        lda #<544
        sta DAS0L
        lda #>544
        sta DAS0H
        lda #$01
        sta MDMAEN

        ; --- 2) une brique à redessiner ? ----------------------------------------
        lda effacer_actif
        beq @pas_de_brique
        lda effacer_vlo
        sta VMADDL
        lda effacer_vhi
        sta VMADDH
        lda effacer_t1
        sta VMDATAL
        lda effacer_a1
        sta VMDATAH
        lda effacer_t2
        sta VMDATAL
        lda effacer_a2
        sta VMDATAH
        stz effacer_actif
@pas_de_brique:

        ; --- 3) GAME OVER ? --------------------------------------------------------
        lda go_actif
        beq @pas_de_game_over
        lda #$CB                ; rangée 14, colonne 11
        sta VMADDL
        lda #$05
        sta VMADDH
        ldx #0
@ecrire_go:
        lda texte_gameover, x
        sta VMDATAL
        stz VMDATAH
        inx
        cpx #9
        bne @ecrire_go
        stz go_actif
@pas_de_game_over:

        ; --- 4) le bandeau : score, niveau, vies (rangée 1) --------------------------
        lda #$24                ; colonne 4
        sta VMADDL
        lda #$04
        sta VMADDH
        lda score_c
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        stz VMDATAH
        lda score_d
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        stz VMDATAH
        lda score_u
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        stz VMDATAH
        lda #$2F                ; colonne 15 : le niveau
        sta VMADDL
        lda #$04
        sta VMADDH
        lda niveau
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        stz VMDATAH
        lda #$3B                ; colonne 27 : les vies
        sta VMADDL
        lda #$04
        sta VMADDH
        lda vies
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        stz VMDATAH

        inc image

        ply
        plx
        pla
        rti

retour_int:
        rti


; =============================================================================
;  LES MOTIFS DE NIVEAUX (identiques à la version NES)
; =============================================================================
V = 0
N = TYPE_NORMALE
R = TYPE_SOLIDE   ; ("S" est interdit : c'est le registre de pile du 65816 !)
D = TYPE_DOREE

motif_classique:
        .byte D,D,D,D,D,D,D,D,D,D,D,D,D,D,D, V
        .byte N,N,N,N,N,N,N,N,N,N,N,N,N,N,N, V
        .byte N,N,N,N,N,N,N,N,N,N,N,N,N,N,N, V
        .byte N,N,N,N,N,N,N,N,N,N,N,N,N,N,N, V
        .byte N,N,N,N,N,N,N,N,N,N,N,N,N,N,N, V
        .byte N,N,N,N,N,N,N,N,N,N,N,N,N,N,N, V
motif_damier:
        .byte N,V,N,V,N,V,N,V,N,V,N,V,N,V,N, V
        .byte V,N,V,N,V,N,V,N,V,N,V,N,V,N,V, V
        .byte N,V,N,V,N,V,N,V,N,V,N,V,N,V,N, V
        .byte V,N,V,N,V,N,V,N,V,N,V,N,V,N,V, V
        .byte N,V,N,V,N,V,N,V,N,V,N,V,N,V,N, V
        .byte R,R,R,R,R,R,R,R,R,R,R,R,R,R,R, V
motif_coeur:
        .byte V,N,N,N,V,V,V,V,V,V,V,N,N,N,V, V
        .byte N,D,D,D,N,V,V,V,V,V,N,D,D,D,N, V
        .byte N,D,D,D,D,D,D,D,D,D,D,D,D,D,N, V
        .byte V,N,D,D,D,D,D,D,D,D,D,D,D,N,V, V
        .byte V,V,V,N,D,D,D,D,D,D,D,N,V,V,V, V
        .byte V,V,V,V,V,V,N,N,N,V,V,V,V,V,V, V
motif_forteresse:
        .byte R,R,R,R,R,R,R,R,R,R,R,R,R,R,R, V
        .byte R,N,N,N,N,N,N,N,N,N,N,N,N,N,R, V
        .byte R,N,D,D,N,N,D,D,D,N,N,D,D,N,R, V
        .byte R,N,D,D,N,N,D,D,D,N,N,D,D,N,R, V
        .byte R,N,N,N,N,N,N,N,N,N,N,N,N,N,R, V
        .byte R,R,R,R,R,R,R,R,R,R,R,R,R,R,R, V


; =============================================================================
;  LE SON — le module SPC700 commun, et le catalogue propre à ce jeu
; =============================================================================
;  Sur NES, chaque bip donnait une PÉRIODE au registre APU. Ici, un NUMÉRO
;  de note suffit : le module son.s convertit et télégraphie au SPC700.
.include "son.s"

bip_mur:                        ; toc discret (murs, briques solides)
        lda #NOTE_SOL4
        ldy #3
        jmp jouer_bip
bip_raquette:                   ; ponk (lancement, Start)
        lda #NOTE_LA4
        ldy #4
        jmp jouer_bip
bip_brique:                     ; cling ! une brique de moins
        lda #NOTE_DO6
        ldy #4
        jmp jouer_bip
bip_bonus:                      ; l'éclat d'une capsule attrapée
        lda #NOTE_SOL5
        ldy #6
        jmp jouer_bip
bip_victoire:                   ; niveau terminé !
        lda #NOTE_LA5
        ldy #40
        jmp jouer_bip
bruit_vie:                      ; pshh : une vie s'envole
        ldy #20
        jmp jouer_bruit
bruit_fin:                      ; long grondement de game over
        ldy #45
        jmp jouer_bruit

; Les partitions : les MÊMES que sur NES, note pour note.
melodie:
        .byte NOTE_DO5,  12, NOTE_MI5, 12, NOTE_SOL5, 12, NOTE_MI5, 12
        .byte NOTE_LA4,  12, NOTE_DO5, 12, NOTE_MI5,  12, NOTE_DO5, 12
        .byte NOTE_FA4,  12, NOTE_LA4, 12, NOTE_DO5,  12, NOTE_LA4, 12
        .byte NOTE_SOL4, 12, NOTE_SI4, 12, NOTE_RE5,  12, NOTE_SI4, 12
        .byte $FF

basse:
        .byte NOTE_DO3, 48, NOTE_LA2, 48, NOTE_FA2, 48, NOTE_SOL2, 48
        .byte $FF


; =============================================================================
;  LES GRAPHISMES ET LE DÉGRADÉ, incorporés depuis l'atelier make_gfx.py
; =============================================================================
.segment "RODATA"
gfx_bg:     .incbin "gfx_bg.bin"
fin_gfx_bg:
gfx_obj:    .incbin "gfx_obj.bin"
fin_gfx_obj:
palettes:   .incbin "palettes.bin"
gradient:   .incbin "gradient.bin"


; =============================================================================
;  LES VECTEURS — le 65816 en a deux jeux : mode natif ET mode émulation
; =============================================================================
.segment "VECTORS"
        ;      -       -       COP         BRK         ABORT       NMI    -       IRQ
        .word  0,      0,      retour_int, retour_int, retour_int, nmi,   0,      retour_int
        ;      -       -       COP         -           ABORT       NMI    RESET   IRQ
        .word  0,      0,      retour_int, 0,          retour_int, 0,     reset,  retour_int
