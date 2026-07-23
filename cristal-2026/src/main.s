; =============================================================================
;  CRISTAL-2026 — la fondation du mini-RPG (niveau 7, phase 1)
; =============================================================================
;
;  Une salle, un héros, un coffre, un cristal de sauvegarde. C'est peu ?
;  C'est surtout QUATRE leçons que aucun de nos jeux n'avait osées, et sans
;  lesquelles aucun RPG n'existe :
;
;   1. LA CARTOUCHE GRANDIT : 256 Ko, HUIT banques de 32 Ko (snes.cfg).
;      Le code reste en banque 0, les DONNÉES vivent en banque $81, lues
;      par ADRESSAGE LONG : `lda f:salle,x` (24 bits), et les pointeurs
;      longs `lda [ptr],y` (3 octets de page directe). Le DMA, lui, a
;      toujours su : son registre A1B0 porte la banque de la source.
;
;   2. LE 65816 EN 16 BITS, POUR DE VRAI. `rep #$20` élargit A : l'or et
;      les pas se comptent jusqu'à 65535 en UNE instruction (`inc a`,
;      `adc #250`). `rep #$10` élargit X : la salle fait 896 cases, un
;      index 8 bits n'y suffirait pas. Et le piège du registre B (l'octet
;      haut caché de A) est documenté là où il mord — voir dessiner_salle.
;
;   3. LA DIVISION MATÉRIELLE ($4204-$4206). Le 6502 ne savait ni
;      multiplier ni diviser. La SNES, si : écrire dividende et diviseur,
;      attendre 16 cycles, lire quotient et reste. C'est elle qui convertit
;      nos compteurs binaires en chiffres décimaux (voir `decimal`).
;
;   4. LA SAUVEGARDE ($70:0000, la SRAM à pile). Un bloc de 16 octets :
;      signature, version, l'état du monde, et une SOMME DE CONTRÔLE —
;      car une pile fatiguée rend des octets menteurs. Au démarrage, on
;      vérifie tout : signature OU somme fausse = pas de « CONTINUER ».
;      C'est exactement le « données corrompues » des vraies cartouches.
;
;  Le son : le module commun ../snes-commun/son.s, thème du cristal.
; =============================================================================

.setcpu "65816"

; --- Les registres (le cours détaillé : ../casse-brique-snes/) ----------------
LUMIERE   = $2100
OBSEL     = $2101
OAMADDL   = $2102
OAMADDH   = $2103
BGMODE    = $2105
BG1SC     = $2107
BG3SC     = $2109
BG12NBA   = $210B
BG34NBA   = $210C
BG1HOFS   = $210D
BG1VOFS   = $210E
BG3HOFS   = $2111
BG3VOFS   = $2112
VMAIN     = $2115
VMADDL    = $2116
VMADDH    = $2117
VMDATAL   = $2118
VMDATAH   = $2119
CGADD     = $2121
CGDATA    = $2122
TM        = $212C
NMITIMEN  = $4200
WRMPYA    = $4202   ; multiplication 8x8 : opérandes...
WRMPYB    = $4203   ; ...(l'écriture ici déclenche le calcul)
WRDIVL    = $4204   ; division 16/8 : le dividende...
WRDIVH    = $4205
WRDIVB    = $4206   ; ...le diviseur (l'écriture déclenche, 16 cycles)
MDMAEN    = $420B
HDMAEN    = $420C
RDNMI     = $4210
HVBJOY    = $4212
RDDIVL    = $4214   ; le quotient...
RDDIVH    = $4215
RDMPYL    = $4216   ; ...et le reste (ou le produit de la multiplication)
RDMPYH    = $4217
JOY1H     = $4219
DMAP0 = $4300
BBAD0 = $4301
A1T0L = $4302
A1T0H = $4303
A1B0  = $4304
DAS0L = $4305
DAS0H = $4306
DMAP1 = $4310
BBAD1 = $4311
A1T1L = $4312
A1T1H = $4313
A1B1  = $4314

BTN_A      = %10000000
BTN_START  = %00010000
BTN_HAUT   = %00001000
BTN_BAS    = %00000100
BTN_GAUCHE = %00000010
BTN_DROITE = %00000001

; --- La carte VRAM (en mots) ---------------------------------------------------
VRAM_SALLE   = $0400
VRAM_FIXE    = $0C00
VRAM_TUILES  = $1000
VRAM_TUILES3 = $3000
VRAM_SPRITES = $4000

TITRE_VRAM    = VRAM_FIXE +  8*32 + 10
NOUVELLE_VRAM = VRAM_FIXE + 14*32 +  9
CONTINUER_VRAM= VRAM_FIXE + 16*32 +  9
MSG_VRAM      = VRAM_FIXE + 24*32 +  7
HUD_OR_TXT    = VRAM_FIXE +  1*32 +  2
HUD_OR        = VRAM_FIXE +  1*32 +  5
HUD_PAS_TXT   = VRAM_FIXE +  1*32 + 18
HUD_PAS       = VRAM_FIXE +  1*32 + 22
COFFRE_VRAM   = VRAM_SALLE + 17*32 + 23

; --- Les tuiles de la salle ------------------------------------------------------
TUILE_CHIFFRE_0 = $10   ; sur BG3
ATTR_TEXTE   = $24      ; BG3 : priorité + palette 1 (blanc)
ATTR_TITRE   = $28      ; palette 2 (cyan)
ATTR_SALLE   = $10      ; BG1 : palette 4 (pierre et tapis)
ATTR_CRISTAL = $14      ; palette 5
ATTR_COFFRE  = $18      ; palette 6 (or)
ATTR_HEROS   = $30      ; sprites : priorité 3, palette 0
ATTR_CURSEUR = $32      ; palette 1
TUILE_CURSEUR = $18

ETAT_TITRE = 0
ETAT_JEU   = 1

OAM_OMBRE = $0200


; -----------------------------------------------------------------------------
;  VARIABLES (page directe)
; -----------------------------------------------------------------------------
.zeropage
boutons:       .res 1
anciens:       .res 1
presses:       .res 1
image:         .res 1
etat:          .res 1
curseur:       .res 1   ; 0 = NOUVELLE PARTIE, 1 = CONTINUER
heros_x:       .res 1
heros_y:       .res 1
direction:     .res 1   ; 0 bas, 1 haut, 2 gauche, 3 droite
pose:          .res 1   ; l'animation de marche (0/1)
pose_cpt:      .res 1
sous_pas:      .res 1   ; 16 pixels de marche = 1 pas
or_lo:         .res 1   ; l'or : 16 BITS. Nos jeux plafonnaient à 999...
or_hi:         .res 1
pas_lo:        .res 1   ; ...un héros de RPG compte jusqu'à 65535 !
pas_hi:        .res 1
coffre_ouvert: .res 1
sauve_ok:      .res 1   ; une sauvegarde VALIDE existe en SRAM
msg_cpt:       .res 1
msg_ecrire:    .res 1   ; files d'attente pour la nmi
msg_effacer:   .res 1
coffre_maj:    .res 1
sonde_x:       .res 1
sonde_y:       .res 1
dec_lo:        .res 1
dec_hi:        .res 1
som_lo:        .res 1
som_hi:        .res 1
tmp:           .res 1
tmp2:          .res 1
chiffres:      .res 10  ; 0-4 : l'or, 5-9 : les pas (valeurs 0-9)
salle_ptr:     .res 3   ; un pointeur de 24 BITS : le 3e octet est la banque
sram_ptr:      .res 3
tampon_sauve:  .res 16


; =============================================================================
;  EN-TÊTE — regardez bien : la cartouche déclare sa SRAM et sa taille
; =============================================================================
.segment "SNESHEADER"
        .byte "CRISTAL-2026         "
        .byte $20               ; LoROM
        .byte $02               ; ROM + SRAM + PILE : la sauvegarde !
        .byte $08               ; taille ROM : 2^8 = 256 Ko
        .byte $03               ; taille SRAM : 2^3 = 8 Ko
        .byte $01, $00, $00
        .word $FFFF
        .word $0000

.segment "CODE"

reset:
        sei
        clc
        xce
        sep #$30
        .a8
        .i8
        ldx #$FF
        txs

        lda #$8F
        sta LUMIERE

        ldx #0
        txa
@vider_ram:                     ; la RAM de travail — PAS la SRAM, elle !
        sta $0000, x
        sta $0100, x
        sta $0300, x
        sta $0500, x
        sta $0600, x
        sta $0700, x
        inx
        bne @vider_ram
        lda #$F0
@cacher_sprites:
        sta $0200, x
        sta $0300, x
        inx
        bne @cacher_sprites
@vider_haute:
        stz $0400, x
        inx
        cpx #$20
        bne @vider_haute

        ; --- le PPU : mode 1, BG3 prioritaire ------------------------------------
        lda #$09
        sta BGMODE
        lda #(VRAM_SALLE >> 10) << 2
        sta BG1SC
        lda #(VRAM_FIXE >> 10) << 2
        sta BG3SC
        lda #VRAM_TUILES >> 12
        sta BG12NBA
        lda #VRAM_TUILES3 >> 12
        sta BG34NBA
        lda #VRAM_SPRITES >> 13
        sta OBSEL
        lda #$15
        sta TM
        stz BG1HOFS
        stz BG1HOFS
        stz BG1VOFS
        stz BG1VOFS
        stz BG3HOFS
        stz BG3HOFS
        stz BG3VOFS
        stz BG3VOFS

        ; --- vider la VRAM (DMA à source figée) ----------------------------------
        lda #$80
        sta VMAIN
        stz VMADDL
        stz VMADDH
        lda #$09
        sta DMAP0
        lda #$18
        sta BBAD0
        lda #<mot_zero
        sta A1T0L
        lda #>mot_zero
        sta A1T0H
        stz A1B0
        stz DAS0L
        stz DAS0H
        lda #$01
        sta MDMAEN

        ; --- charger les graphismes : ILS VIVENT EN BANQUE $81 ! ------------------
        ;  Le DMA n'a jamais été limité à la banque 0 : son registre A1B0
        ;  reçoit la banque de la source. L'opérateur ^ de ca65 l'extrait.
        lda #<VRAM_TUILES
        sta VMADDL
        lda #>VRAM_TUILES
        sta VMADDH
        lda #$01
        sta DMAP0
        lda #<gfx_bg
        sta A1T0L
        lda #>gfx_bg
        sta A1T0H
        lda #^gfx_bg            ; la BANQUE de la source ($81)
        sta A1B0
        lda #<(fin_gfx_bg - gfx_bg)
        sta DAS0L
        lda #>(fin_gfx_bg - gfx_bg)
        sta DAS0H
        lda #$01
        sta MDMAEN

        lda #<VRAM_TUILES3
        sta VMADDL
        lda #>VRAM_TUILES3
        sta VMADDH
        lda #<gfx_bg3
        sta A1T0L
        lda #>gfx_bg3
        sta A1T0H
        lda #<(fin_gfx_bg3 - gfx_bg3)
        sta DAS0L
        lda #>(fin_gfx_bg3 - gfx_bg3)
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

        stz CGADD
        stz DMAP0
        lda #$22
        sta BBAD0
        lda #<palettes
        sta A1T0L
        lda #>palettes
        sta A1T0H
        stz DAS0L
        lda #$02
        sta DAS0H
        lda #$01
        sta MDMAEN

        ; --- le HDMA de la pénombre ------------------------------------------------
        lda #$03
        sta DMAP1
        lda #$21
        sta BBAD1
        lda #<gradient
        sta A1T1L
        lda #>gradient
        sta A1T1H
        lda #^gradient
        sta A1B1
        lda #$02
        sta HDMAEN

        ; --- la SRAM a-t-elle une sauvegarde honnête ? -----------------------------
        jsr verifier_sauvegarde
        jsr dessiner_ecran_titre
        lda #ETAT_TITRE
        sta etat
        stz curseur

        jsr initialiser_son
        jsr demarrer_musique

        jsr allumer_ecran
        jmp principale

mot_zero: .word 0


eteindre_ecran:
        lda #$8F
        sta LUMIERE
        stz NMITIMEN
        rts

allumer_ecran:
        lda #$81
        sta NMITIMEN
        lda #$0F
        sta LUMIERE
        rts


; =============================================================================
;  LA SAUVEGARDE — 16 octets en SRAM ($70:0000), et pas un de plus
; =============================================================================
;  0-3  : "CR26", la signature. 4 : la version du format.
;  5-7  : heros_x, heros_y, direction.  8-11 : or, pas (16 bits chacun).
;  12   : le coffre est-il ouvert ?  13 : réservé.
;  14-15: la somme de contrôle des octets 0-13.
;
;  POURQUOI une somme de contrôle ? Parce que la SRAM n'est que de la RAM
;  avec une pile : pile faible, octets aléatoires. Sans elle, « CONTINUER »
;  chargerait n'importe quoi avec assurance. Les jeux d'époque affichaient
;  « données corrompues » : maintenant vous savez qui parlait.

viser_sram:
        stz sram_ptr            ; le pointeur long : $70:0000
        stz sram_ptr+1
        lda #$70
        sta sram_ptr+2
        rts

sauvegarder:
        lda #'C'
        sta tampon_sauve+0
        lda #'R'
        sta tampon_sauve+1
        lda #'2'
        sta tampon_sauve+2
        lda #'6'
        sta tampon_sauve+3
        lda #1
        sta tampon_sauve+4
        lda heros_x
        sta tampon_sauve+5
        lda heros_y
        sta tampon_sauve+6
        lda direction
        sta tampon_sauve+7
        lda or_lo
        sta tampon_sauve+8
        lda or_hi
        sta tampon_sauve+9
        lda pas_lo
        sta tampon_sauve+10
        lda pas_hi
        sta tampon_sauve+11
        lda coffre_ouvert
        sta tampon_sauve+12
        stz tampon_sauve+13
        jsr somme_tampon
        lda som_lo
        sta tampon_sauve+14
        lda som_hi
        sta tampon_sauve+15
        jsr viser_sram
        ldy #0
@copier:
        lda tampon_sauve, y
        sta [sram_ptr], y       ; l'écriture LONGUE : elle part en banque $70
        iny
        cpy #16
        bne @copier
        lda #1
        sta sauve_ok
        rts

; la somme de contrôle : les octets 0-13 additionnés sur 16 bits
somme_tampon:
        stz som_lo
        stz som_hi
        ldx #0
@somme:
        lda tampon_sauve, x
        clc
        adc som_lo
        sta som_lo
        bcc @pas_retenue
        inc som_hi
@pas_retenue:
        inx
        cpx #14
        bne @somme
        rts

lire_sram:
        jsr viser_sram
        ldy #0
@lire:
        lda [sram_ptr], y
        sta tampon_sauve, y
        iny
        cpy #16
        bne @lire
        rts

verifier_sauvegarde:
        stz sauve_ok
        jsr lire_sram
        lda tampon_sauve+0      ; la signature d'abord...
        cmp #'C'
        bne @invalide
        lda tampon_sauve+1
        cmp #'R'
        bne @invalide
        lda tampon_sauve+2
        cmp #'2'
        bne @invalide
        lda tampon_sauve+3
        cmp #'6'
        bne @invalide
        jsr somme_tampon        ; ...puis la somme : les DEUX doivent tenir
        lda som_lo
        cmp tampon_sauve+14
        bne @invalide
        lda som_hi
        cmp tampon_sauve+15
        bne @invalide
        lda #1
        sta sauve_ok
@invalide:
        rts

charger_sauvegarde:
        jsr lire_sram
        lda tampon_sauve+5
        sta heros_x
        lda tampon_sauve+6
        sta heros_y
        lda tampon_sauve+7
        sta direction
        lda tampon_sauve+8
        sta or_lo
        lda tampon_sauve+9
        sta or_hi
        lda tampon_sauve+10
        sta pas_lo
        lda tampon_sauve+11
        sta pas_hi
        lda tampon_sauve+12
        sta coffre_ouvert
        rts


; =============================================================================
;  L'ÉCRAN TITRE
; =============================================================================
dessiner_ecran_titre:
        lda #$80
        sta VMAIN
        lda #<TITRE_VRAM
        sta VMADDL
        lda #>TITRE_VRAM
        sta VMADDH
        ldx #0
@titre:
        lda f:texte_titre, x    ; même les TEXTES vivent en banque $81
        sta VMDATAL
        lda #ATTR_TITRE
        sta VMDATAH
        inx
        cpx #12
        bne @titre

        lda #<NOUVELLE_VRAM
        sta VMADDL
        lda #>NOUVELLE_VRAM
        sta VMADDH
        ldx #0
@nouvelle:
        lda f:texte_nouvelle, x
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        inx
        cpx #15
        bne @nouvelle

        lda sauve_ok            ; pas de sauvegarde : pas de CONTINUER
        beq @fin
        lda #<CONTINUER_VRAM
        sta VMADDL
        lda #>CONTINUER_VRAM
        sta VMADDH
        ldx #0
@continuer:
        lda f:texte_continuer, x
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        inx
        cpx #9
        bne @continuer
@fin:
        rts

effacer_texte_titre:
        lda #$80
        sta VMAIN
        lda #<TITRE_VRAM
        sta VMADDL
        lda #>TITRE_VRAM
        sta VMADDH
        ldx #12
@l1:    stz VMDATAL
        stz VMDATAH
        dex
        bne @l1
        lda #<NOUVELLE_VRAM
        sta VMADDL
        lda #>NOUVELLE_VRAM
        sta VMADDH
        ldx #15
@l2:    stz VMDATAL
        stz VMDATAH
        dex
        bne @l2
        lda #<CONTINUER_VRAM
        sta VMADDL
        lda #>CONTINUER_VRAM
        sta VMADDH
        ldx #9
@l3:    stz VMDATAL
        stz VMDATAH
        dex
        bne @l3
        rts


; =============================================================================
;  ENTRER DANS LA SALLE
; =============================================================================
nouvelle_partie:
        lda #120
        sta heros_x
        lda #168
        sta heros_y
        lda #1                  ; face au cristal
        sta direction
        stz or_lo
        stz or_hi
        stz pas_lo
        stz pas_hi
        stz coffre_ouvert
        stz sous_pas
        ; (et c'est tout : rien n'est écrit en SRAM avant le cristal !)
        jmp entrer_salle

continuer_partie:
        jsr charger_sauvegarde
        jmp entrer_salle

entrer_salle:
        jsr eteindre_ecran
        jsr effacer_texte_titre
        jsr dessiner_salle
        jsr dessiner_pancarte
        lda coffre_ouvert
        beq @coffre_ok
        jsr ouvrir_coffre_direct
@coffre_ok:
        jsr calculer_chiffres_or
        jsr calculer_chiffres_pas
        stz msg_cpt
        stz msg_ecrire
        stz msg_effacer
        stz coffre_maj
        stz pose
        stz pose_cpt
        lda #ETAT_JEU
        sta etat
        jsr allumer_ecran
        rts

; -----------------------------------------------------------------------------
;  dessiner_salle — 896 cases lues en BANQUE $81, avec un index de 16 BITS
; -----------------------------------------------------------------------------
dessiner_salle:
        lda #$80
        sta VMAIN
        lda #<VRAM_SALLE
        sta VMADDL
        lda #>VRAM_SALLE
        sta VMADDH
        ; PIÈGE DU 65816, vécu : TAY en mode index 16 bits copie AUSSI
        ; l'octet HAUT caché de l'accumulateur (le registre B). S'il traîne
        ; un reste de calcul 16 bits, Y part dans le décor. On vide B :
        rep #$20
        .a16
        lda #0
        sep #$20
        .a8
        rep #$10                ; X en 16 BITS : 896 cases, l'index suit
        .i16
        ldx #0
@case:
        lda f:salle, x          ; l'adressage LONG : banque $81, index 16 bits
        tay
        sta VMDATAL
        lda attrs_tuile, y
        sta VMDATAH
        inx
        cpx #896
        bne @case
        sep #$10
        .i8
        rts

dessiner_pancarte:
        lda #$80
        sta VMAIN
        lda #<HUD_OR_TXT
        sta VMADDL
        lda #>HUD_OR_TXT
        sta VMADDH
        ldx #0
@or:
        lda f:texte_or, x
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        inx
        cpx #2
        bne @or
        lda #<HUD_PAS_TXT
        sta VMADDL
        lda #>HUD_PAS_TXT
        sta VMADDH
        ldx #0
@pas:
        lda f:texte_pas, x
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        inx
        cpx #3
        bne @pas
        rts

ouvrir_coffre_direct:           ; écran éteint : on écrit la VRAM en direct
        lda #$80
        sta VMAIN
        lda #<COFFRE_VRAM
        sta VMADDL
        lda #>COFFRE_VRAM
        sta VMADDH
        lda #$0C
        sta VMDATAL
        lda #ATTR_COFFRE
        sta VMDATAH
        lda #$0D
        sta VMDATAL
        lda #ATTR_COFFRE
        sta VMDATAH
        lda #<(COFFRE_VRAM+32)
        sta VMADDL
        lda #>(COFFRE_VRAM+32)
        sta VMADDH
        lda #$0E
        sta VMDATAL
        lda #ATTR_COFFRE
        sta VMDATAH
        lda #$0F
        sta VMDATAL
        lda #ATTR_COFFRE
        sta VMDATAH
        rts


; =============================================================================
;  LA BOUCLE PRINCIPALE
; =============================================================================
principale:
        jsr attendre_nmi
        jsr maj_musique
        jsr maj_bruitages
        jsr lire_manette

        lda etat
        bne @en_jeu

        ; --- AU TITRE ------------------------------------------------------------
        lda presses
        and #BTN_BAS
        beq @pas_bas
        lda sauve_ok            ; une seule option sans sauvegarde valide
        beq @pas_bas
        lda curseur
        bne @pas_bas
        lda #1
        sta curseur
        jsr bip_curseur
@pas_bas:
        lda presses
        and #BTN_HAUT
        beq @pas_haut
        lda curseur
        beq @pas_haut
        stz curseur
        jsr bip_curseur
@pas_haut:
        lda presses
        and #BTN_A | BTN_START
        beq @dessiner
        jsr bip_choix
        lda curseur
        bne @continuer
        jsr nouvelle_partie
        jmp @dessiner
@continuer:
        jsr continuer_partie
        jmp @dessiner

@en_jeu:
        jsr maj_heros
        jsr interagir
        lda msg_cpt             ; le message s'efface tout seul
        beq @dessiner
        dec msg_cpt
        bne @dessiner
        lda #1
        sta msg_effacer

@dessiner:
        jsr maj_sprites
        jmp principale


attendre_nmi:
        lda image
@patienter:
        cmp image
        beq @patienter
        rts

lire_manette:
        lda boutons
        sta anciens
@occupe:
        lda HVBJOY
        and #1
        bne @occupe
        lda JOY1H
        sta boutons
        lda anciens
        eor #$FF
        and boutons
        sta presses
        rts


; =============================================================================
;  LE HÉROS — marcher, buter contre les murs, compter ses pas
; =============================================================================
;  La sonde : un point (sonde_x, sonde_y) → la tuile de la carte, lue en
;  banque $81 par POINTEUR LONG. La table rangs_lo/hi (générée par .repeat)
;  donne l'adresse de chaque rangée : pas de multiplication à faire.

tuile_en:
        lda sonde_y
        lsr a
        lsr a
        lsr a
        tax
        lda rangs_lo, x
        sta salle_ptr
        lda rangs_hi, x
        sta salle_ptr+1
        lda #^salle             ; l'octet de BANQUE du pointeur long
        sta salle_ptr+2
        lda sonde_x
        lsr a
        lsr a
        lsr a
        tay
        lda [salle_ptr], y      ; la tuile sous la sonde
        rts

solide_en:
        jsr tuile_en
        tax
        lda solides_tuile, x
        rts

maj_heros:
        stz tmp2                ; a-t-on bougé cette image ?

        lda boutons
        and #BTN_HAUT
        beq @pas_haut
        lda #1
        sta direction
        lda heros_y
        sec
        sbc #1
        sta sonde_y
        lda heros_x
        clc
        adc #2
        sta sonde_x
        jsr solide_en
        bne @pas_haut
        lda heros_x
        clc
        adc #13
        sta sonde_x
        jsr solide_en
        bne @pas_haut
        dec heros_y
        inc tmp2
@pas_haut:
        lda boutons
        and #BTN_BAS
        beq @pas_bas
        lda #0
        sta direction
        lda heros_y
        clc
        adc #16
        sta sonde_y
        lda heros_x
        clc
        adc #2
        sta sonde_x
        jsr solide_en
        bne @pas_bas
        lda heros_x
        clc
        adc #13
        sta sonde_x
        jsr solide_en
        bne @pas_bas
        inc heros_y
        inc tmp2
@pas_bas:
        lda boutons
        and #BTN_GAUCHE
        beq @pas_gauche
        lda #2
        sta direction
        lda heros_x
        sec
        sbc #1
        sta sonde_x
        lda heros_y
        clc
        adc #2
        sta sonde_y
        jsr solide_en
        bne @pas_gauche
        lda heros_y
        clc
        adc #13
        sta sonde_y
        jsr solide_en
        bne @pas_gauche
        dec heros_x
        inc tmp2
@pas_gauche:
        lda boutons
        and #BTN_DROITE
        beq @pas_droite
        lda #3
        sta direction
        lda heros_x
        clc
        adc #16
        sta sonde_x
        lda heros_y
        clc
        adc #2
        sta sonde_y
        jsr solide_en
        bne @pas_droite
        lda heros_y
        clc
        adc #13
        sta sonde_y
        jsr solide_en
        bne @pas_droite
        inc heros_x
        inc tmp2
@pas_droite:

        lda tmp2
        bne @marche
        stz pose                ; à l'arrêt : au garde-à-vous
        stz pose_cpt
        rts
@marche:
        inc pose_cpt            ; l'animation : une enjambée toutes les 8 images
        lda pose_cpt
        cmp #8
        bcc @compter
        stz pose_cpt
        lda pose
        eor #1
        sta pose
@compter:
        inc sous_pas            ; 16 pixels = UN PAS — et le compteur est
        lda sous_pas            ; en 16 BITS : voici rep #$20 au travail.
        cmp #16
        bcc @fin
        stz sous_pas
        rep #$20
        .a16
        lda pas_lo              ; pas_lo et pas_hi se suivent en mémoire :
        inc a                   ; UN lda, UN inc — le 65816 fait le reste
        sta pas_lo
        sep #$20
        .a8
        jsr calculer_chiffres_pas
@fin:
        rts


; =============================================================================
;  INTERAGIR — le bouton A face au coffre ou au cristal
; =============================================================================
interagir:
        lda presses
        and #BTN_A
        bne @regarder
        rts
@regarder:
        ldx direction           ; le point juste devant le héros
        lda heros_x
        clc
        adc devant_dx, x
        sta sonde_x
        lda heros_y
        clc
        adc devant_dy, x
        sta sonde_y
        jsr tuile_en
        cmp #$04
        bcc @rien
        cmp #$08
        bcc @cristal            ; tuiles $04-$07 : le cristal
        cmp #$0C
        bcs @rien               ; tuiles $08-$0B : le coffre fermé
        ; --- LE COFFRE ------------------------------------------------------------
        ;  (la carte en ROM le dit toujours fermé : c'est notre drapeau
        ;   coffre_ouvert qui fait foi — et il part dans la sauvegarde)
        lda coffre_ouvert
        bne @rien
        lda #1
        sta coffre_ouvert
        sta coffre_maj          ; la nmi changera les tuiles au VBlank
        rep #$20
        .a16
        lda or_lo               ; +250 pièces d'or, en UNE addition 16 bits
        clc
        adc #250
        sta or_lo
        sep #$20
        .a8
        jsr calculer_chiffres_or
        jmp son_coffre
@cristal:
        jsr sauvegarder
        lda #1
        sta msg_ecrire
        lda #150
        sta msg_cpt
        jmp son_sauve
@rien:
        rts

;                 bas   haut  gauche droite   ($FD = -3 : la sonde recule)
devant_dx: .byte  8,    8,    $FD,   18
devant_dy: .byte  18,   $FD,  8,     8


; =============================================================================
;  L'AFFICHAGE DÉCIMAL — la DIVISION MATÉRIELLE de la SNES
; =============================================================================
;  Convertir 64789 en "6 4 7 8 9", c'est diviser par 10 en boucle. Le 6502
;  aurait souffert ; la SNES a un diviseur câblé : dividende dans
;  $4204-$4205, diviseur dans $4206 — et 16 cycles plus tard, quotient en
;  $4214-$4215, reste en $4216. Le reste EST le chiffre.

calculer_chiffres_or:
        lda or_lo
        sta dec_lo
        lda or_hi
        sta dec_hi
        ldx #4                  ; les chiffres 4..0 (unités en dernier index)
        jmp decimal
calculer_chiffres_pas:
        lda pas_lo
        sta dec_lo
        lda pas_hi
        sta dec_hi
        ldx #9

decimal:
        ldy #5
@chiffre:
        lda dec_lo
        sta WRDIVL
        lda dec_hi
        sta WRDIVH
        lda #10
        sta WRDIVB              ; la division démarre ICI...
        nop                     ; ...et rend son verdict 16 cycles plus tard.
        nop                     ; Huit NOP (2 cycles chacun) : la politesse
        nop                     ; envers le matériel, réglée d'avance.
        nop
        nop
        nop
        nop
        nop
        lda RDDIVL              ; le quotient repart au tour suivant...
        sta dec_lo
        lda RDDIVH
        sta dec_hi
        lda RDMPYL              ; ...le reste est un chiffre (0-9) !
        sta chiffres, x
        dex
        dey
        bne @chiffre
        rts


; =============================================================================
;  maj_sprites — le héros 16×16 (4 sprites) et le curseur du menu
; =============================================================================
maj_sprites:
        lda etat
        bne @en_jeu             ; (l'écran titre est à plus de 127 octets :
        jmp @au_titre           ;  on passe par un JMP, comme toujours)
@en_jeu:
        lda #$F0                ; en jeu : le curseur se cache
        sta $0211
        ; les 4 quarts du héros
        lda heros_y
        sta $0201
        sta $0205
        clc
        adc #8
        sta $0209
        sta $020D
        lda heros_x
        sta $0200
        sta $0208
        clc
        adc #8
        sta $0204
        sta $020C
        ldx direction
        lda bases_dir, x
        ldx pose
        beq @pose_ok
        clc
        adc #4
@pose_ok:
        sta tmp
        lda direction
        cmp #2
        beq @miroir
        lda tmp
        sta $0202
        inc a
        sta $0206
        inc a
        sta $020A
        inc a
        sta $020E
        lda #ATTR_HEROS
        sta $0203
        sta $0207
        sta $020B
        sta $020F
        rts
@miroir:
        ; --- GAUCHE = DROITE dans un miroir : le bit H des attributs OAM.
        ;     Chaque quart se retourne SUR PLACE... il faut donc aussi
        ;     échanger les colonnes : la tuile droite passe à gauche !
        lda tmp
        inc a
        sta $0202               ; à gauche : la tuile DROITE, retournée
        lda tmp
        sta $0206
        lda tmp
        inc a
        inc a
        inc a
        sta $020A
        lda tmp
        inc a
        inc a
        sta $020E
        lda #ATTR_HEROS | $40
        sta $0203
        sta $0207
        sta $020B
        sta $020F
        rts

@au_titre:
        lda #$F0                ; au titre : le héros attend en coulisses
        sta $0201
        sta $0205
        sta $0209
        sta $020D
        lda #58
        sta $0210
        lda curseur
        asl a
        asl a
        asl a
        asl a
        clc
        adc #112
        sta $0211
        lda #TUILE_CURSEUR
        sta $0212
        lda #ATTR_CURSEUR
        sta $0213
        rts

;                 bas   haut  côté (gauche et droite : le miroir fait le reste)
bases_dir: .byte  $00,  $08,  $10,  $10


; =============================================================================
;  NMI — et l'idiome 65816 : SAUVER LES REGISTRES EN LARGE
; =============================================================================
;  La NMI peut interrompre du code en plein rep #$20 ! pha en 8 bits ne
;  sauverait que la moitié de A. La parade classique : rep #$30 d'entrée,
;  tout empiler en 16 bits, sep #$30 pour travailler — et symétrie en
;  sortie. Le rti restaure P, donc les largeurs de l'interrompu.
nmi:
        rep #$30
        pha
        phx
        phy
        sep #$30
        lda RDNMI

        stz OAMADDL
        stz OAMADDH
        stz DMAP0
        lda #$04
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

        lda #$80
        sta VMAIN

        ; --- le coffre s'ouvre ? ---------------------------------------------------
        lda coffre_maj
        beq @pas_coffre
        stz coffre_maj
        lda #<COFFRE_VRAM
        sta VMADDL
        lda #>COFFRE_VRAM
        sta VMADDH
        lda #$0C
        sta VMDATAL
        lda #ATTR_COFFRE
        sta VMDATAH
        lda #$0D
        sta VMDATAL
        lda #ATTR_COFFRE
        sta VMDATAH
        lda #<(COFFRE_VRAM+32)
        sta VMADDL
        lda #>(COFFRE_VRAM+32)
        sta VMADDH
        lda #$0E
        sta VMDATAL
        lda #ATTR_COFFRE
        sta VMDATAH
        lda #$0F
        sta VMDATAL
        lda #ATTR_COFFRE
        sta VMDATAH
@pas_coffre:

        ; --- un message à écrire / effacer ? ----------------------------------------
        lda msg_ecrire
        beq @pas_msg
        stz msg_ecrire
        lda #<MSG_VRAM
        sta VMADDL
        lda #>MSG_VRAM
        sta VMADDH
        ldx #0
@msg:
        lda f:texte_sauve, x
        sta VMDATAL
        beq @msg_vide
        lda #ATTR_TEXTE
        sta VMDATAH
        jmp @msg_suite
@msg_vide:
        stz VMDATAH
@msg_suite:
        inx
        cpx #18
        bne @msg
@pas_msg:
        lda msg_effacer
        beq @pas_eff
        stz msg_effacer
        lda #<MSG_VRAM
        sta VMADDL
        lda #>MSG_VRAM
        sta VMADDH
        ldx #18
@eff:
        stz VMDATAL
        stz VMDATAH
        dex
        bne @eff
@pas_eff:

        ; --- le bandeau : OR et PAS, cinq chiffres chacun ----------------------------
        lda etat
        beq @pas_hud
        lda #<HUD_OR
        sta VMADDL
        lda #>HUD_OR
        sta VMADDH
        ldx #0
@chiffres_or:
        lda chiffres, x
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        inx
        cpx #5
        bne @chiffres_or
        lda #<HUD_PAS
        sta VMADDL
        lda #>HUD_PAS
        sta VMADDH
@chiffres_pas:
        lda chiffres, x
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        inx
        cpx #10
        bne @chiffres_pas
@pas_hud:

        inc image
        rep #$30
        ply
        plx
        pla
retour_int:
        rti


; =============================================================================
;  LE SON — le module SPC700 commun, thème du cristal
; =============================================================================
.include "son.s"

bip_curseur:
        lda #NOTE_LA4
        ldy #2
        jmp jouer_bip
bip_choix:
        lda #NOTE_DO6
        ldy #5
        jmp jouer_bip
son_coffre:                     ; le trésor scintille
        lda #NOTE_SOL5
        ldy #10
        jmp jouer_bip
son_sauve:                      ; la note du cristal
        lda #NOTE_LA5
        ldy #30
        jmp jouer_bip

; Le thème du cristal : lent, suspendu — on est dans un sanctuaire.
melodie:
        .byte NOTE_MI5,  24, NOTE_SI4, 24, NOTE_DO5,  24, NOTE_SOL4, 24
        .byte NOTE_LA4,  24, NOTE_MI5, 24, NOTE_RE5,  24, NOTE_SI4,  24
        .byte $FF
basse:
        .byte NOTE_LA2, 48, NOTE_FA2, 48, NOTE_DO3, 48, NOTE_SOL2, 48
        .byte $FF


; =============================================================================
;  LES TABLES près du code (banque 0)
; =============================================================================
.segment "RODATA"
; l'adresse (16 bits) de chaque rangée de la salle — générée par .repeat !
rangs_lo:
.repeat 28, R
        .byte <(salle + R*32)
.endrepeat
rangs_hi:
.repeat 28, R
        .byte >(salle + R*32)
.endrepeat

;                  vide sol  mur  tapis [cristal x4] [coffre fermé x4] [ouvert x4] [colonne x2]
attrs_tuile:  .byte ATTR_SALLE, ATTR_SALLE, ATTR_SALLE, ATTR_SALLE
              .byte ATTR_CRISTAL, ATTR_CRISTAL, ATTR_CRISTAL, ATTR_CRISTAL
              .byte ATTR_COFFRE, ATTR_COFFRE, ATTR_COFFRE, ATTR_COFFRE
              .byte ATTR_COFFRE, ATTR_COFFRE, ATTR_COFFRE, ATTR_COFFRE
              .byte ATTR_SALLE, ATTR_SALLE
solides_tuile: .byte 1, 0, 1, 0
               .byte 1, 1, 1, 1
               .byte 1, 1, 1, 1
               .byte 1, 1, 1, 1
               .byte 1, 1


; =============================================================================
;  LA BANQUE DES DONNÉES ($81) — tout ce qui n'est pas du code déménage ici
; =============================================================================
.segment "DONNEES"

; --- l'alphabet en clair : .charmap traduit les chaînes pour nous -------------
;  Fini les .byte L_C, L_R, L_I... : on écrit "CRISTAL-2026" et l'assembleur
;  convertit chaque lettre vers nos numéros de tuiles. Petit luxe de ca65.
;
;  PIÈGE VÉCU : écrire `.charmap 'A' + I, ...` échoue en silence, car dès
;  la première itération, la littérale 'A' est ELLE-MÊME remappée ($20) —
;  et toutes les suivantes partent du mauvais pied. Codes NUMÉRIQUES only.
.repeat 26, I
        .charmap 65 + I, $20 + I        ; 65 = 'A' en ASCII
.endrepeat
.repeat 10, I
        .charmap 48 + I, $10 + I        ; 48 = '0'
.endrepeat
.charmap 45, $1B                        ; le tiret
.charmap 32, $00                        ; l'espace = la tuile vide

texte_titre:     .byte "CRISTAL-2026"
texte_nouvelle:  .byte "NOUVELLE PARTIE"
texte_continuer: .byte "CONTINUER"
texte_sauve:     .byte "PARTIE SAUVEGARDEE"
texte_or:        .byte "OR"
texte_pas:       .byte "PAS"

; --- la salle : 32 x 28 tuiles, lisible comme un plan --------------------------
N  = $00        ; le noir au-delà des murs
_  = $01        ; le sol
M  = $02        ; le mur
T  = $03        ; le tapis
G1 = $04        ; le cristal (quatre quarts)...
D1 = $05
G2 = $06
D2 = $07
F1 = $08        ; le coffre fermé
F2 = $09
F3 = $0A
F4 = $0B
P1 = $10        ; la colonne
P2 = $11

salle:
 .byte N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N
 .byte N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N
 .byte M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M
 .byte M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,_,_,_,P1,_,_,_,_,_,_,_,_,T,T,G1,D1,T,T,_,_,_,_,_,_,_,_,P1,_,_,_,M
 .byte M,_,_,_,P2,_,_,_,_,_,_,_,_,T,T,G2,D2,T,T,_,_,_,_,_,_,_,_,P2,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,T,T,T,T,T,T,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,T,T,T,T,T,T,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,_,T,T,T,T,_,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,_,T,T,T,T,_,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,_,T,T,T,T,_,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,_,T,T,T,T,_,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,_,T,T,T,T,_,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,_,T,T,T,T,_,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,_,T,T,T,T,_,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,_,T,T,T,T,_,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,_,T,T,T,T,_,_,_,_,_,F1,F2,_,_,_,_,_,_,M
 .byte M,_,_,_,P1,_,_,_,_,_,_,_,_,_,T,T,T,T,_,_,_,_,_,F3,F4,_,_,P1,_,_,_,M
 .byte M,_,_,_,P2,_,_,_,_,_,_,_,_,_,T,T,T,T,_,_,_,_,_,_,_,_,_,P2,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,_,T,T,T,T,_,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,_,T,T,T,T,_,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,M
 .byte M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M,M
 .byte N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N
 .byte N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N,N
 ; le garde-fou : une virgule oubliée et toute la salle se décale !
 .assert * - salle = 896, error, "la salle doit faire 32 x 28 = 896 cases"

; --- les graphismes, eux aussi en banque $81 (le DMA connaît le chemin) --------
gfx_bg:      .incbin "gfx_bg.bin"
fin_gfx_bg:
gfx_bg3:     .incbin "gfx_bg3.bin"
fin_gfx_bg3:
gfx_obj:     .incbin "gfx_obj.bin"
fin_gfx_obj:
palettes:    .incbin "palettes.bin"
gradient:    .incbin "gradient.bin"


; =============================================================================
;  LES VECTEURS
; =============================================================================
.segment "VECTORS"
        ;      -       -       COP         BRK         ABORT       NMI    -       IRQ
        .word  0,      0,      retour_int, retour_int, retour_int, nmi,   0,      retour_int
        ;      -       -       COP         -           ABORT       NMI    RESET   IRQ
        .word  0,      0,      retour_int, 0,          retour_int, 0,     reset,  retour_int
