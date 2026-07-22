; =============================================================================
;  NÉO-RUNNER 2026 SNES — le défilement en 16 bits (niveau 5 du cours)
; =============================================================================
;
;  Le portage du runner NES (../neo-runner-2026/) : 2 mondes, puces, drones,
;  bandeau de score, écran titre. Les leçons SNES de CE portage :
;
;   - LE BANDEAU FIXE NE COÛTE PLUS RIEN. Sur NES il fallait guetter le
;     sprite 0 pour changer le défilement en pleine image. Sur SNES, le
;     mode 1 offre une TROISIÈME couche de fond (BG3, 4 couleurs) : le
;     bandeau y vit, immobile et prioritaire, pendant que le monde défile
;     sur BG1. Une acrobatie devenue une case à cocher.
;   - LA TILEMAP 64×32 : les deux écrans côte à côte de la NES (miroir
;     vertical) deviennent une simple taille de tilemap. Le streaming de
;     colonnes ne change pas d'un iota — VMAIN $81 écrit même les colonnes
;     verticalement tout seul.
;   - LES QUARTIERS PAR PALETTE : cyan ou rose, le néon du quartier est
;     choisi colonne par colonne par l'octet de palette — plus fin que les
;     attributs NES par nametable entière.
;
;  Physique, caméra, mondes, drones : le code NES ligne à ligne (8 bits,
;  sep #$30). Le son vient du module commun ../snes-commun/son.s (le
;  SPC700), jingles compris. Voir ../casse-brique-snes/ pour l'init 65816
;  commentée pas à pas.
; =============================================================================

.setcpu "65816"

; --- Registres (voir casse-brique-snes pour le détail) -------------------------
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
MDMAEN    = $420B
HDMAEN    = $420C
RDNMI     = $4210
HVBJOY    = $4212
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
BTN_GAUCHE = %00000010
BTN_DROITE = %00000001

; --- La carte VRAM (en mots) -----------------------------------------------------
;  BG1 : tilemap 64×32 ($0400-$0BFF : DEUX écrans côte à côte), tuiles $1000.
;  BG3 : tilemap $0C00 (le bandeau), tuiles 2bpp $3000. Sprites : $4000.
VRAM_CARTE   = $0400
VRAM_BANDEAU = $0C00

; --- Tuiles du monde (mêmes numéros que la version NES) ----------------------------
TUILE_VIDE = $00
TUILE_BLOC = $01
TUILE_NEON = $02
; bandeau (BG3) :
BQ_ICONE   = $01
BQ_TETE    = $02
BQ_LISERET = $03
BQ_CHIFFRE = $10
BQ_TIRET   = $1B
L_A = $20
L_E = $21
L_I = $22
L_N = $23
L_O = $24
L_P = $25
L_R = $26
L_S = $27
L_T = $28
L_U = $29
ESPACE = $00
ATTR_TEXTE   = $24              ; priorité (le bandeau passe DEVANT) + palette
ATTR_ICONE   = $28
ATTR_LISERET = $2C
ATTR_CYAN    = $10              ; BG1 : palette 4 = quartier cyan
ATTR_ROSE    = $14              ; BG1 : palette 5 = quartier rose

OBJ_TETE   = $00
OBJ_CORPS1 = $01
OBJ_CORPS2 = $02
OBJ_DRONE1 = $03
OBJ_DRONE2 = $04
ATTR_ROBOT = $30
ATTR_DRONE = $32

; --- Les types de métatuiles et les états (identiques à la NES) ---------------------
TYPE_VIDE    = 0
TYPE_BLOC    = 1
TYPE_NEON    = 2
TYPE_PUCE    = 3
TYPE_ANTENNE = 4
TYPE_MAT     = 5
ETAT_TITRE = 0
ETAT_JEU   = 1
ETAT_PERDU = 2
ETAT_GAGNE = 3

GRAVITE   = $40
SAUT_LO   = $80
SAUT_HI   = $FA
CHUTE_MAX = 4
NIVEAU_COLONNES = 64
CAMERA_MAX_HI   = $03
BUT_LO = $C0
BUT_HI = $03

OAM_OMBRE = $0200


; -----------------------------------------------------------------------------
;  VARIABLES (page directe) — l'ordre NES, conservé
; -----------------------------------------------------------------------------
.zeropage
boutons:       .res 1
anciens:       .res 1
presses:       .res 1
image:         .res 1
etat:          .res 1
joueur_x_lo:   .res 1
joueur_x_hi:   .res 1
joueur_y:      .res 1
joueur_ysub:   .res 1
vy_lo:         .res 1
vy_hi:         .res 1
au_sol:        .res 1
regard:        .res 1
camera_lo:     .res 1
camera_hi:     .res 1
prochaine_col: .res 1
vies:          .res 1
score_c:       .res 1
score_d:       .res 1
col_actif:     .res 1
col_adr_hi:    .res 1           ; adresse VRAM (mot) de la colonne à écrire
col_adr_lo:    .res 1
col_attr:      .res 1           ; la palette du quartier de cette colonne
puce_actif:    .res 1
puce_adr_hi:   .res 1
puce_adr_lo:   .res 1
puce_attr:     .res 1
sonde_x_lo:    .res 1
sonde_x_hi:    .res 1
sonde_y:       .res 1
carte_ptr:     .res 2
src_ptr:       .res 2
dst_ptr:       .res 2
rang_tmp:      .res 1
meta_tmp:      .res 1
tmp_lo:        .res 1
tmp_hi:        .res 1
compteur:      .res 1
drone_x_lo:    .res 3
drone_x_hi:    .res 3
drone_y:       .res 3
drone_dir:     .res 3
drone_actif:   .res 3
monde:         .res 1
jingle_actif:  .res 1   ; un jingle (mini-partition sur la voix des bips) joue
jingle_pos:    .res 1
jingle_cpt:    .res 1
jingle_ptr:    .res 2

.bss
carte:          .res 1024
tampon_colonne: .res 52


; =============================================================================
;  EN-TÊTE ET RESET
; =============================================================================
.segment "SNESHEADER"
        .byte "NEO-RUNNER 2026      "
        .byte $20, $00, $05, $00, $01, $00, $00
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
@vider_ram:
        sta $0000, x
        sta $0100, x
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

        ; --- PPU : mode 1 avec BG3 prioritaire = le bandeau gratuit -------------
        lda #$09                ; mode 1 + BG3 par-dessus tout : UNE ligne de
        sta BGMODE              ; code remplace toute l'astuce du sprite 0 !
        lda #((VRAM_CARTE >> 10) << 2) | %01
        sta BG1SC               ; tilemap 64×32 : nos deux écrans côte à côte
        lda #(VRAM_BANDEAU >> 10) << 2
        sta BG3SC
        lda #$01                ; tuiles BG1 à $1000
        sta BG12NBA
        lda #$03                ; tuiles BG3 à $3000
        sta BG34NBA
        lda #$02                ; sprites à $4000
        sta OBSEL
        lda #$15                ; couches affichées : BG1 + BG3 + sprites
        sta TM
        stz BG1HOFS
        stz BG1HOFS
        stz BG1VOFS
        stz BG1VOFS
        stz BG3HOFS
        stz BG3HOFS
        stz BG3VOFS
        stz BG3VOFS

        ; --- vider la VRAM, charger tuiles + couleurs (voir casse-brique-snes) --
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

        lda #$01
        sta DMAP0
        ldy #0
@charger_blocs:
        lda blocs_vram_lo, y
        sta VMADDL
        lda blocs_vram_hi, y
        sta VMADDH
        lda blocs_src_lo, y
        sta A1T0L
        lda blocs_src_hi, y
        sta A1T0H
        lda blocs_taille_lo, y
        sta DAS0L
        lda blocs_taille_hi, y
        sta DAS0H
        lda #$01
        sta MDMAEN
        iny
        cpy #3
        bne @charger_blocs

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

        lda #$03                ; le HDMA du ciel nocturne
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

        ; --- l'état de départ -----------------------------------------------------
        lda #3
        sta vies
        stz score_c
        stz score_d
        stz image
        lda #ETAT_TITRE
        sta etat
        lda #1
        sta monde

        ; le SPC700 d'abord (avant la NMI) — et noter que ce jeu relance par
        ; "jmp reset" : initialiser_son sait que le pilote survit (voir son.s)
        jsr initialiser_son
        jsr demarrer_musique

        jsr dessiner_bandeau
        jsr charger_niveau
        jsr dessiner_titre_texte
        jsr allumer_ecran
        jmp principale

mot_zero: .word 0

; Les trois blocs graphiques à charger : (adresse VRAM, source, taille)
blocs_vram_lo:   .byte <$1000, <$3000, <$4000
blocs_vram_hi:   .byte >$1000, >$3000, >$4000
blocs_src_lo:    .byte <gfx_bg, <gfx_bg3, <gfx_obj
blocs_src_hi:    .byte >gfx_bg, >gfx_bg3, >gfx_obj
blocs_taille_lo: .byte <(fin_gfx_bg-gfx_bg), <(fin_gfx_bg3-gfx_bg3), <(fin_gfx_obj-gfx_obj)
blocs_taille_hi: .byte >(fin_gfx_bg-gfx_bg), >(fin_gfx_bg3-gfx_bg3), >(fin_gfx_obj-gfx_obj)


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
;  LE BANDEAU (BG3) : icônes, liseret — dessiné une fois, il ne bouge JAMAIS
; =============================================================================
dessiner_bandeau:
        lda #<(VRAM_BANDEAU + 32 + 4)   ; rangée 1, colonne 4 : l'icône puce
        sta VMADDL
        lda #>(VRAM_BANDEAU + 32 + 4)
        sta VMADDH
        lda #BQ_ICONE
        sta VMDATAL
        lda #ATTR_ICONE
        sta VMDATAH
        lda #<(VRAM_BANDEAU + 32 + 24)  ; colonne 24 : la tête du robot
        sta VMADDL
        lda #>(VRAM_BANDEAU + 32 + 24)
        sta VMADDH
        lda #BQ_TETE
        sta VMDATAL
        lda #ATTR_ICONE
        sta VMDATAH
        lda #<(VRAM_BANDEAU + 3*32)     ; rangée 3 : le liseret néon
        sta VMADDL
        lda #>(VRAM_BANDEAU + 3*32)
        sta VMADDH
        ldx #32
@liseret:
        lda #BQ_LISERET
        sta VMDATAL
        lda #ATTR_LISERET
        sta VMDATAH
        dex
        bne @liseret
        rts

; --- le titre, sur la couche FIXE : il ne défilera pas avec le monde ------------
dessiner_titre_texte:
        lda #<(VRAM_BANDEAU + 8*32 + 8)
        sta VMADDL
        lda #>(VRAM_BANDEAU + 8*32 + 8)
        sta VMADDH
        ldx #0
@nom:
        lda texte_nom, x
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        inx
        cpx #15
        bne @nom
        lda #<(VRAM_BANDEAU + 11*32 + 8)
        sta VMADDL
        lda #>(VRAM_BANDEAU + 11*32 + 8)
        sta VMADDH
        ldx #0
@appuie:
        lda texte_appuie, x
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        inx
        cpx #16
        bne @appuie
        rts

effacer_titre_texte:
        lda #<(VRAM_BANDEAU + 8*32 + 8)
        sta VMADDL
        lda #>(VRAM_BANDEAU + 8*32 + 8)
        sta VMADDH
        ldx #15
@nom:
        stz VMDATAL
        stz VMDATAH
        dex
        bne @nom
        lda #<(VRAM_BANDEAU + 11*32 + 8)
        sta VMADDL
        lda #>(VRAM_BANDEAU + 11*32 + 8)
        sta VMADDH
        ldx #16
@appuie:
        stz VMDATAL
        stz VMDATAH
        dex
        bne @appuie
        rts

texte_nom:
        .byte L_N, L_E, L_O, BQ_TIRET, L_R, L_U, L_N, L_N, L_E, L_R, ESPACE
        .byte BQ_CHIFFRE+2, BQ_CHIFFRE, BQ_CHIFFRE+2, BQ_CHIFFRE+6
texte_appuie:
        .byte L_A, L_P, L_P, L_U, L_I, L_E, ESPACE, L_S, L_U, L_R, ESPACE
        .byte L_S, L_T, L_A, L_R, L_T


; =============================================================================
;  charger_niveau — copie de la carte + dessin des 32 premières colonnes
;  (logique NES ; seul le "où" change : tilemap 64×32 au lieu de 2 nametables)
; =============================================================================
charger_niveau:
        ldx monde
        dex
        lda mondes_lo, x
        sta src_ptr
        lda mondes_hi, x
        sta src_ptr+1
        stz dst_ptr
        lda #>carte
        sta dst_ptr+1
        lda #<carte
        sta dst_ptr
        ldx #NIVEAU_COLONNES
@colonne:
        ldy #0
@copie:
        lda (src_ptr), y
        sta (dst_ptr), y
        iny
        cpy #15
        bne @copie
        lda #0
        sta (dst_ptr), y
        lda src_ptr
        clc
        adc #15
        sta src_ptr
        bcc @src_ok
        inc src_ptr+1
@src_ok:
        lda dst_ptr
        clc
        adc #16
        sta dst_ptr
        bcc @dst_ok
        inc dst_ptr+1
@dst_ok:
        dex
        bne @colonne

        stz compteur
@dessiner:
        lda compteur
        jsr construire_colonne
        jsr ecrire_colonne
        inc compteur
        lda compteur
        cmp #32
        bne @dessiner

        stz camera_lo
        stz camera_hi
        stz col_actif
        stz puce_actif
        stz vy_lo
        stz vy_hi
        stz joueur_ysub
        stz au_sol
        stz regard
        stz joueur_x_hi
        lda #32
        sta joueur_x_lo
        sta prochaine_col
        lda #192
        sta joueur_y

        lda monde               ; les drones du monde en cours (3 par monde)
        sec
        sbc #1
        sta tmp_lo
        asl a
        clc
        adc tmp_lo
        sta tmp_lo
        ldx #2
@drone:
        txa
        clc
        adc tmp_lo
        tay
        lda drones_debut_lo, y
        sta drone_x_lo, x
        lda drones_debut_hi, y
        sta drone_x_hi, x
        lda #200
        sta drone_y, x
        lda #1
        sta drone_dir, x
        sta drone_actif, x
        dex
        bpl @drone
        rts

mondes_lo: .byte <niveau, <niveau_2
mondes_hi: .byte >niveau, >niveau_2
drones_debut_lo: .byte $A0, $C0, $A0,  $90, $80, $70
drones_debut_hi: .byte $00, $01, $02,  $00, $01, $02
drones_min_lo:   .byte $A0, $C0, $A0,  $90, $80, $70
drones_min_hi:   .byte $00, $01, $02,  $00, $01, $02
drones_max_lo:   .byte $E8, $28, $E8,  $C8, $C0, $B8
drones_max_hi:   .byte $00, $02, $02,  $00, $01, $02


; =============================================================================
;  construire_colonne / ecrire_colonne — le streaming, version tilemap 64×32
; =============================================================================
construire_colonne:
        sta meta_tmp
        ldx #>VRAM_CARTE        ; écran gauche ($0400)...
        lda meta_tmp
        and #%00010000
        beq @ecran_ok
        ldx #>(VRAM_CARTE + $400)   ; ...ou droit ($0800) : le bit 4, comme
@ecran_ok:                          ; le choix de nametable sur NES
        stx col_adr_hi
        lda meta_tmp
        and #%00001111
        asl a
        clc
        adc #$80                ; + 4 rangées × 32 : sous le bandeau
        sta col_adr_lo

        ldx #ATTR_CYAN          ; le quartier : cyan ou rose, par le MÊME bit
        lda meta_tmp
        and #%00010000
        beq @quartier_ok
        ldx #ATTR_ROSE
@quartier_ok:
        stx col_attr

        lda meta_tmp            ; pointeur carte : $0300... non ! `carte` est
        lsr a                   ; en BSS, mais toujours à colonne × 16 : le
        lsr a                   ; calcul d'adresse magique de la NES tient
        lsr a                   ; toujours (voir type_carte)
        lsr a
        clc
        adc #>carte
        sta carte_ptr+1
        lda meta_tmp
        asl a
        asl a
        asl a
        asl a
        sta carte_ptr

        ldy #2
@rangee:
        sty rang_tmp
        lda (carte_ptr), y
        tax
        lda rang_tmp
        sec
        sbc #2
        asl a
        tay
        lda metatuile_hg, x
        sta tampon_colonne, y
        lda metatuile_bg, x
        sta tampon_colonne+1, y
        lda metatuile_hd, x
        sta tampon_colonne+26, y
        lda metatuile_bd, x
        sta tampon_colonne+27, y
        ldy rang_tmp
        iny
        cpy #15
        bne @rangee
        rts

metatuile_hg: .byte $00, TUILE_BLOC, TUILE_NEON, $04, $0B, $0D
metatuile_hd: .byte $00, TUILE_BLOC, TUILE_NEON, $05, $0C, $0E
metatuile_bg: .byte $00, TUILE_BLOC, TUILE_BLOC, $06, $0D, $0D
metatuile_bd: .byte $00, TUILE_BLOC, TUILE_BLOC, $07, $0E, $0E
table_solide: .byte 0, 1, 1, 0, 0, 0

ecrire_colonne:
        lda #$81                ; VMAIN : +32 après chaque case = on descend !
        sta VMAIN               ; (la NES faisait pareil avec PPUCTRL bit 2)
        lda col_adr_lo
        sta VMADDL
        lda col_adr_hi
        sta VMADDH
        ldx #0
@gauche:
        lda tampon_colonne, x
        sta VMDATAL
        lda col_attr
        sta VMDATAH
        inx
        cpx #26
        bne @gauche
        lda col_adr_lo
        clc
        adc #1
        sta VMADDL
        lda col_adr_hi
        adc #0
        sta VMADDH
@droite:
        lda tampon_colonne, x
        sta VMDATAL
        lda col_attr
        sta VMDATAH
        inx
        cpx #52
        bne @droite
        lda #$80                ; retour au mode "+1"
        sta VMAIN
        rts


; =============================================================================
;  LA BOUCLE PRINCIPALE (logique NES, sans le son)
; =============================================================================
principale:
        jsr attendre_nmi
        jsr maj_musique
        jsr maj_bruitages_jingle
        jsr maj_jingle
        jsr lire_manette

        lda etat
        cmp #ETAT_JEU
        bne @pas_jeu
        jmp @en_jeu
@pas_jeu:
        cmp #ETAT_TITRE
        beq @au_titre

        ; --- PERDU / GAGNÉ : Start relance la console ---------------------------
        lda presses
        and #BTN_START
        bne @rejouer
        jmp @dessiner
@rejouer:
        jmp reset

@au_titre:
        lda presses
        and #BTN_START
        beq @dessiner
        jsr eteindre_ecran
        jsr effacer_titre_texte
        jsr allumer_ecran
        lda #ETAT_JEU
        sta etat
        jsr bip_depart
        jmp @dessiner

@en_jeu:
        jsr maj_joueur
        lda etat
        cmp #ETAT_JEU
        bne @dessiner
        jsr maj_drones
        lda etat
        cmp #ETAT_JEU
        bne @dessiner
        jsr maj_camera
        jsr maj_defilement

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
;  maj_joueur — course, gravité, saut, sondes : le code NES à l'identique
; =============================================================================
maj_joueur:
        lda boutons
        and #BTN_DROITE
        beq @pas_droite
        lda joueur_x_lo
        clc
        adc #2
        sta joueur_x_lo
        lda joueur_x_hi
        adc #0
        sta joueur_x_hi
        stz regard
        lda joueur_x_lo
        clc
        adc #7
        sta sonde_x_lo
        lda joueur_x_hi
        adc #0
        sta sonde_x_hi
        lda joueur_y
        clc
        adc #2
        sta sonde_y
        jsr type_carte
        jsr est_solide
        bne @cogne_droite
        lda joueur_y
        clc
        adc #13
        sta sonde_y
        jsr type_carte
        jsr est_solide
        beq @pas_droite
@cogne_droite:
        lda sonde_x_lo
        and #$F0
        sec
        sbc #8
        sta joueur_x_lo
        lda sonde_x_hi
        sbc #0
        sta joueur_x_hi
@pas_droite:

        lda boutons
        and #BTN_GAUCHE
        beq @pas_gauche
        lda joueur_x_lo
        sec
        sbc #2
        sta joueur_x_lo
        lda joueur_x_hi
        sbc #0
        sta joueur_x_hi
        lda #1
        sta regard
        lda joueur_x_lo
        sta sonde_x_lo
        lda joueur_x_hi
        sta sonde_x_hi
        lda joueur_y
        clc
        adc #2
        sta sonde_y
        jsr type_carte
        jsr est_solide
        bne @cogne_gauche
        lda joueur_y
        clc
        adc #13
        sta sonde_y
        jsr type_carte
        jsr est_solide
        beq @pas_gauche
@cogne_gauche:
        lda sonde_x_lo
        and #$F0
        clc
        adc #16
        sta joueur_x_lo
        lda sonde_x_hi
        adc #0
        sta joueur_x_hi
@pas_gauche:

        lda joueur_x_hi         ; jamais à gauche de la caméra
        cmp camera_hi
        bcc @colle_camera
        bne @camera_ok
        lda joueur_x_lo
        cmp camera_lo
        bcs @camera_ok
@colle_camera:
        lda camera_lo
        sta joueur_x_lo
        lda camera_hi
        sta joueur_x_hi
@camera_ok:
        lda joueur_x_hi         ; ni au-delà de la fin du niveau
        cmp #$03
        bcc @borne_ok
        lda joueur_x_lo
        cmp #$F0
        bcc @borne_ok
        lda #$F0
        sta joueur_x_lo
@borne_ok:

        ; --- vertical : virgule fixe + gravité -----------------------------------
        lda joueur_ysub
        clc
        adc vy_lo
        sta joueur_ysub
        lda joueur_y
        adc vy_hi
        sta joueur_y
        lda vy_lo
        clc
        adc #GRAVITE
        sta vy_lo
        lda vy_hi
        adc #0
        sta vy_hi
        bmi @monte
        cmp #CHUTE_MAX
        bcc @chute_ok
        lda #CHUTE_MAX
        sta vy_hi
        stz vy_lo
@chute_ok:
        lda joueur_y
        cmp #232
        bcc @pas_tombe
        jmp mourir
@pas_tombe:
        lda joueur_y
        clc
        adc #16
        sta sonde_y
        lda joueur_x_lo
        clc
        adc #1
        sta sonde_x_lo
        lda joueur_x_hi
        adc #0
        sta sonde_x_hi
        jsr type_carte
        jsr est_solide
        bne @atterrir
        lda joueur_x_lo
        clc
        adc #6
        sta sonde_x_lo
        lda joueur_x_hi
        adc #0
        sta sonde_x_hi
        jsr type_carte
        jsr est_solide
        bne @atterrir
        stz au_sol
        jmp @fin_vertical
@atterrir:
        lda sonde_y
        and #$F0
        sec
        sbc #16
        sta joueur_y
        stz joueur_ysub
        stz vy_lo
        stz vy_hi
        lda #1
        sta au_sol
        jmp @fin_vertical
@monte:
        stz au_sol
        lda joueur_y
        sec
        sbc #1
        sta sonde_y
        lda joueur_x_lo
        clc
        adc #1
        sta sonde_x_lo
        lda joueur_x_hi
        adc #0
        sta sonde_x_hi
        jsr type_carte
        jsr est_solide
        bne @cogne_tete
        lda joueur_x_lo
        clc
        adc #6
        sta sonde_x_lo
        lda joueur_x_hi
        adc #0
        sta sonde_x_hi
        jsr type_carte
        jsr est_solide
        beq @fin_vertical
@cogne_tete:
        lda sonde_y
        and #$F0
        clc
        adc #16
        sta joueur_y
        stz joueur_ysub
        stz vy_lo
        stz vy_hi
@fin_vertical:

        lda au_sol              ; le saut
        beq @pas_de_saut
        lda presses
        and #BTN_A
        beq @pas_de_saut
        lda #SAUT_LO
        sta vy_lo
        lda #SAUT_HI
        sta vy_hi
        stz au_sol
        jsr bip_saut
@pas_de_saut:

        lda joueur_x_lo         ; une puce ?
        clc
        adc #4
        sta sonde_x_lo
        lda joueur_x_hi
        adc #0
        sta sonde_x_hi
        lda joueur_y
        clc
        adc #8
        sta sonde_y
        jsr type_carte
        cmp #TYPE_PUCE
        bne @pas_de_puce
        jsr ramasser_puce
@pas_de_puce:

        lda joueur_x_hi         ; l'antenne ?
        cmp #BUT_HI
        bcc @fin
        lda joueur_x_lo
        cmp #BUT_LO
        bcc @fin
        lda monde
        cmp #2
        beq @victoire_finale
        inc monde
        jsr jouer_jingle_victoire
        jsr eteindre_ecran
        jsr charger_niveau
        jsr allumer_ecran
        rts
@victoire_finale:
        lda #ETAT_GAGNE
        sta etat
        jsr arreter_musique
        jsr jouer_jingle_victoire
@fin:
        rts


; -----------------------------------------------------------------------------
;  type_carte — l'adresse déduite des coordonnées : le rangement NES survit,
;  la carte étant alignée sur 256 octets (voir snes.cfg : CARTE à $0400)
; -----------------------------------------------------------------------------
type_carte:
        lda sonde_x_hi
        clc
        adc #>carte
        sta carte_ptr+1
        lda sonde_x_lo
        and #$F0
        sta carte_ptr
        lda sonde_y
        lsr a
        lsr a
        lsr a
        lsr a
        ora carte_ptr
        sta carte_ptr
        ldy #0
        lda (carte_ptr), y
        rts

est_solide:
        tax
        lda table_solide, x
        rts


ramasser_puce:
        lda #0
        tay
        sta (carte_ptr), y
        jsr bip_puce            ; cling !
        inc score_d
        lda score_d
        cmp #10
        bne @score_fait
        stz score_d
        inc score_c
@score_fait:
        ; adresse VRAM de la métatuile : écran ($0400/$0800) + r×64 + colonne×2
        lda sonde_y
        lsr a
        lsr a
        lsr a
        lsr a
        sta rang_tmp
        lda sonde_x_hi
        and #1
        asl a
        asl a                   ; écran droit : +$0400 mots = +4 sur l'octet haut
        sta tmp_lo
        lda rang_tmp
        lsr a
        lsr a
        clc
        adc tmp_lo
        adc #>VRAM_CARTE
        sta puce_adr_hi
        lda sonde_x_lo
        and #$F0
        lsr a
        lsr a
        lsr a
        sta tmp_lo
        lda rang_tmp
        asl a
        asl a
        asl a
        asl a
        asl a
        asl a
        clc
        adc tmp_lo
        sta puce_adr_lo
        ldx #ATTR_CYAN          ; l'attribut du quartier où vit la puce
        lda sonde_x_hi
        and #1
        beq @attr_ok
        ldx #ATTR_ROSE
@attr_ok:
        stx puce_attr
        lda #1
        sta puce_actif
        rts


mourir:
        dec vies
        bne @rejouer
        lda #ETAT_PERDU
        sta etat
        jsr arreter_musique
        jsr jouer_jingle_defaite
        jmp bruit_fin           ; long grondement (son rts conclura)
@rejouer:
        jsr bruit_vie           ; "pshh"
        jsr eteindre_ecran
        jsr charger_niveau
        jsr allumer_ecran
        rts


maj_camera:
        lda joueur_x_lo
        sec
        sbc #112
        sta tmp_lo
        lda joueur_x_hi
        sbc #0
        sta tmp_hi
        bmi @fin
        lda tmp_hi
        cmp camera_hi
        bcc @fin
        bne @avancer
        lda tmp_lo
        cmp camera_lo
        bcc @fin
        beq @fin
@avancer:
        lda tmp_lo
        sta camera_lo
        lda tmp_hi
        sta camera_hi
        lda camera_hi
        cmp #CAMERA_MAX_HI
        bcc @fin
        lda camera_lo
        beq @fin
        stz camera_lo
        lda #CAMERA_MAX_HI
        sta camera_hi
@fin:
        rts

maj_defilement:
        lda col_actif
        bne @fin
        lda prochaine_col
        cmp #NIVEAU_COLONNES
        bcs @fin
        lda camera_lo
        clc
        adc #$10
        sta tmp_lo
        lda camera_hi
        adc #$01
        sta tmp_hi
        lda prochaine_col
        lsr a
        lsr a
        lsr a
        lsr a
        cmp tmp_hi
        bcc @construire
        bne @fin
        lda prochaine_col
        asl a
        asl a
        asl a
        asl a
        cmp tmp_lo
        bcs @fin
@construire:
        lda prochaine_col
        jsr construire_colonne
        inc prochaine_col
        lda #1
        sta col_actif
@fin:
        rts


; =============================================================================
;  maj_drones (logique NES à l'identique)
; =============================================================================
maj_drones:
        ldx #2
@drone:
        lda drone_actif, x
        bne @vivant
        jmp @suivant
@vivant:
        lda drone_dir, x
        bmi @va_a_gauche
        inc drone_x_lo, x
        bne @borne_droite
        inc drone_x_hi, x
@borne_droite:
        lda monde
        sec
        sbc #1
        sta tmp_lo
        asl a
        clc
        adc tmp_lo
        sta tmp_lo
        txa
        clc
        adc tmp_lo
        tay
        lda drone_x_hi, x
        cmp drones_max_hi, y
        bcc @collision
        lda drone_x_lo, x
        cmp drones_max_lo, y
        bcc @collision
        lda #$FF
        sta drone_dir, x
        jmp @collision
@va_a_gauche:
        lda drone_x_lo, x
        bne @dec_bas
        dec drone_x_hi, x
@dec_bas:
        dec drone_x_lo, x
        lda monde
        sec
        sbc #1
        sta tmp_lo
        asl a
        clc
        adc tmp_lo
        sta tmp_lo
        txa
        clc
        adc tmp_lo
        tay
        lda drone_x_hi, x
        cmp drones_min_hi, y
        bcc @demi_tour
        bne @collision
        lda drone_x_lo, x
        cmp drones_min_lo, y
        bcc @demi_tour
        beq @demi_tour
        bne @collision
@demi_tour:
        lda #1
        sta drone_dir, x
@collision:
        lda drone_x_lo, x
        sec
        sbc joueur_x_lo
        sta tmp_lo
        lda drone_x_hi, x
        sbc joueur_x_hi
        beq @ecart_positif
        cmp #$FF
        bne @suivant
        lda tmp_lo
        cmp #$F9
        bcc @suivant
        bcs @vertical
@ecart_positif:
        lda tmp_lo
        cmp #8
        bcs @suivant
@vertical:
        lda joueur_y
        clc
        adc #16
        cmp drone_y, x
        bcc @suivant
        beq @suivant
        lda drone_y, x
        clc
        adc #8
        cmp joueur_y
        bcc @suivant
        beq @suivant
        lda vy_hi
        bmi @fatal
        lda joueur_y
        clc
        adc #16
        sec
        sbc drone_y, x
        cmp #7
        bcs @fatal
        lda #0
        sta drone_actif, x
        sta vy_lo
        lda #$FD
        sta vy_hi
        jsr bruit_ecrase        ; "crounch" (X n'est pas abîmé, ouf)
        jmp @suivant
@fatal:
        jmp mourir
@suivant:
        dex
        bmi @fin
        jmp @drone
@fin:
        rts


; =============================================================================
;  maj_sprites — robot animé (2 poses), drones (rotors), OAM SNES
; =============================================================================
maj_sprites:
        lda etat
        cmp #ETAT_JEU
        beq @robot_visible
        lda image
        and #%00010000
        beq @robot_visible
        lda #$F0
        sta $0201
        sta $0205
        jmp @drones
@robot_visible:
        lda joueur_x_lo
        sec
        sbc camera_lo
        sta $0200
        sta $0204
        lda joueur_y
        sta $0201
        clc
        adc #8
        sta $0205
        lda #OBJ_TETE
        sta $0202
        lda au_sol
        beq @jambes_ecartees
        lda boutons
        and #BTN_GAUCHE|BTN_DROITE
        beq @jambes_serrees
        lda image
        and #%00001000
        beq @jambes_serrees
@jambes_ecartees:
        lda #OBJ_CORPS2
        bne @poser_jambes
@jambes_serrees:
        lda #OBJ_CORPS1
@poser_jambes:
        sta $0206
        ldx #ATTR_ROBOT
        lda regard
        beq @attributs
        ldx #ATTR_ROBOT | $40   ; miroir horizontal : même bit que sur NES !
@attributs:
        stx $0203
        stx $0207

@drones:
        ldx #2
@un_drone:
        txa
        asl a
        asl a
        clc
        adc #8
        tay                     ; sprites 2-4 : OAM $0208 + X×4
        lda drone_actif, x
        beq @cacher
        lda drone_x_lo, x
        sec
        sbc camera_lo
        sta tmp_lo
        lda drone_x_hi, x
        sbc camera_hi
        bne @cacher
        lda tmp_lo
        sta $0200, y
        lda drone_y, x
        sta $0201, y
        lda image
        and #%00000100
        beq @rotor_1
        lda #OBJ_DRONE2
        bne @rotor_ok
@rotor_1:
        lda #OBJ_DRONE1
@rotor_ok:
        sta $0202, y
        lda #ATTR_DRONE
        sta $0203, y
        jmp @drone_suivant
@cacher:
        lda #$F0
        sta $0201, y
@drone_suivant:
        dex
        bpl @un_drone
        rts


; =============================================================================
;  NMI — DMA sprites, colonne en attente, puce, bandeau, DÉFILEMENT
; =============================================================================
nmi:
        pha
        phx
        phy
        lda RDNMI

        stz OAMADDL             ; les sprites, d'un souffle
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

        lda col_actif           ; une colonne de décor ?
        beq @pas_de_colonne
        jsr ecrire_colonne
        stz col_actif
@pas_de_colonne:

        lda puce_actif          ; une puce ramassée ? (4 cases)
        beq @pas_de_puce
        lda puce_adr_lo
        sta VMADDL
        lda puce_adr_hi
        sta VMADDH
        stz VMDATAL
        lda puce_attr
        sta VMDATAH
        stz VMDATAL
        sta VMDATAH
        lda puce_adr_lo
        clc
        adc #32
        sta VMADDL
        lda puce_adr_hi
        adc #0
        sta VMADDH
        stz VMDATAL
        lda puce_attr
        sta VMDATAH
        stz VMDATAL
        sta VMDATAH
        stz puce_actif
@pas_de_puce:

        lda #<(VRAM_BANDEAU + 32 + 5)   ; le score, sur la couche FIXE : pas
        sta VMADDL                      ; de sprite 0, pas d'acrobatie, rien.
        lda #>(VRAM_BANDEAU + 32 + 5)
        sta VMADDH
        lda score_c
        clc
        adc #BQ_CHIFFRE
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        lda score_d
        clc
        adc #BQ_CHIFFRE
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        lda #BQ_CHIFFRE
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        lda #<(VRAM_BANDEAU + 32 + 25)
        sta VMADDL
        lda #>(VRAM_BANDEAU + 32 + 25)
        sta VMADDH
        lda vies
        clc
        adc #BQ_CHIFFRE
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH

        lda camera_lo           ; LE DÉFILEMENT : deux octets dans BG1HOFS.
        sta BG1HOFS             ; La tilemap 64×32 fait le reste — et le
        lda camera_hi           ; bandeau BG3, lui, ne bouge pas d'un pixel.
        sta BG1HOFS

        inc image

        ply
        plx
        pla
        rti

retour_int:
        rti


; =============================================================================
;  LES DEUX MONDES (les cartes NES, copiées telles quelles)
; =============================================================================
V = TYPE_VIDE
B = TYPE_BLOC
N = TYPE_NEON
P = TYPE_PUCE
T = TYPE_ANTENNE
M = TYPE_MAT

niveau:
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,P,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,N,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,P,N,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,N,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,P,V,B,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,B,B,N,B
        .byte V,V,V,V,V,V,V,V,P,V,B,B,B,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,P,V,N,V,V,N,B
        .byte V,V,V,V,V,V,V,V,P,V,N,V,V,N,B
        .byte V,V,V,V,V,V,V,V,P,V,N,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,N,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,N,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,N,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,N,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,P,N,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,N,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,P,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,P,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,P,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,T,M,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B

niveau_2:
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,P,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,P,N,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,B,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,B,B,N,B
        .byte V,V,V,V,V,V,V,V,P,V,B,B,B,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,P,V,N,V,V,N,B
        .byte V,V,V,V,V,V,V,V,P,V,N,V,V,N,B
        .byte V,V,V,V,V,V,V,V,P,V,N,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,B,N,B
        .byte V,V,V,V,V,V,V,V,V,V,B,B,B,N,B
        .byte V,V,V,V,V,V,P,V,B,B,B,B,B,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,P,N,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,P,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,P,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,T,M,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B


; =============================================================================
;  LE SON — le module SPC700 commun, les jingles et le catalogue du runner
; =============================================================================
.include "son.s"

; --- Les jingles : le moteur NES, porté mot pour mot. Seul le "haut-parleur"
;     change : jouer_note sur la voix des bips, au lieu des registres APU. ---
jouer_jingle_victoire:
        lda #<jingle_victoire
        sta jingle_ptr
        lda #>jingle_victoire
        sta jingle_ptr+1
        jmp lancer_jingle
jouer_jingle_defaite:
        lda #<jingle_defaite
        sta jingle_ptr
        lda #>jingle_defaite
        sta jingle_ptr+1
lancer_jingle:
        lda #1
        sta jingle_actif
        sta jingle_cpt          ; la première note part à la prochaine image
        stz jingle_pos
        rts

maj_jingle:
        lda jingle_actif
        bne @actif
        rts
@actif:
        dec jingle_cpt
        beq @note_suivante
        rts
@note_suivante:
        ldy jingle_pos
        lda (jingle_ptr), y
        cmp #$FF
        bne @jouer
        stz jingle_actif        ; partition terminée : silence et rideau
        ldx #VOIX_BIP
        jmp couper_voix
@jouer:
        phy                     ; jouer_note mange Y : on le met à l'abri
        ldx #VOIX_BIP
        jsr jouer_note
        ply
        iny
        lda (jingle_ptr), y
        sta jingle_cpt
        iny
        sty jingle_pos
        rts

jingle_victoire: .byte NOTE_DO5, 8,  NOTE_MI5, 8,  NOTE_SOL5, 8,  NOTE_LA5, 24, $FF
jingle_defaite:  .byte NOTE_MI5, 10, NOTE_DO5, 10, NOTE_LA4, 10, NOTE_FA4, 28, $FF

; Le garde-fou de la NES, conservé : tant qu'un jingle occupe la voix des
; bips, maj_bruitages ne doit pas lui couper le sifflet à contretemps.
maj_bruitages_jingle:
        lda jingle_actif
        beq @normal
        stz bip_cpt             ; le jingle est le seul maître de la voix 2
@normal:
        jmp maj_bruitages

; Le catalogue des sons du jeu (des numéros de notes, plus des périodes) :
bip_depart:                     ; Start pressé
        lda #NOTE_LA4
        ldy #4
        jmp jouer_bip
bip_saut:                       ; hop !
        lda #NOTE_SOL4
        ldy #3
        jmp jouer_bip
bip_puce:                       ; cling ! aigu
        lda #NOTE_DO6
        ldy #4
        jmp jouer_bip
bruit_ecrase:                   ; "crounch" : un drone de moins
        ldy #8
        jmp jouer_bruit
bruit_vie:                      ; "pshh" : une vie s'envole
        ldy #20
        jmp jouer_bruit
bruit_fin:                      ; long grondement de game over
        ldy #45
        jmp jouer_bruit

; LA PARTITION — les mêmes arpèges nocturnes que sur NES, note pour note.
melodie:
        .byte NOTE_MI5, 12, NOTE_DO5,  12, NOTE_LA4, 12, NOTE_DO5, 12
        .byte NOTE_DO5, 12, NOTE_LA4,  12, NOTE_FA4, 12, NOTE_LA4, 12
        .byte NOTE_MI5, 12, NOTE_SOL5, 12, NOTE_MI5, 12, NOTE_DO5, 12
        .byte NOTE_RE5, 12, NOTE_SI4,  12, NOTE_SOL4, 12, NOTE_SI4, 12
        .byte $FF

basse:
        .byte NOTE_LA2, 48, NOTE_FA2, 48, NOTE_DO3, 48, NOTE_SOL2, 48
        .byte $FF


.segment "RODATA"
gfx_bg:      .incbin "gfx_bg.bin"
fin_gfx_bg:
gfx_bg3:     .incbin "gfx_bg3.bin"
fin_gfx_bg3:
gfx_obj:     .incbin "gfx_obj.bin"
fin_gfx_obj:
palettes:    .incbin "palettes.bin"
gradient:    .incbin "gradient.bin"


.segment "VECTORS"
        .word 0, 0, retour_int, retour_int, retour_int, nmi, 0, retour_int
        .word 0, 0, retour_int, 0, retour_int, 0, reset, retour_int
