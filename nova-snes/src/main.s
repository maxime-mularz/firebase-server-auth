; =============================================================================
;  NOVA-2026 SNES — le shoot'em up passe en 16 bits (niveau 6 du cours)
; =============================================================================
;
;  Le même NOVA que la version NES (../nova-2026/) : 8 vagues, zigzags,
;  i-frames, réservoirs d'objets, LFSR. Mais sur Super Nintendo :
;
;   1. LE DÉFILEMENT VERTICAL, version 16 bits. Sur NES, il fallait câbler
;      la cartouche en miroir horizontal (deux écrans EMPILÉS) et jongler
;      entre defil_y et le bit de nametable. Sur SNES... c'est une taille
;      de tilemap (32×64, bit 1 de BG1SC) et UN registre de 16 bits
;      (BG1VOFS). Le ciel fait 512 pixels de haut et boucle tout seul.
;
;   2. LES ÉTOILES MULTICOLORES : la MÊME tuile d'étoile devient bleutée,
;      dorée ou blanche par l'octet de palette de sa case — le LFSR choisit
;      aussi la couleur ! Sur NES, les attributs imposaient une couleur par
;      bloc de 16×16 : ici, chaque étoile a la sienne.
;
;   3. LE HUD SANS SPRITES. Sur NES, score et GAME OVER volaient en sprites
;      pour échapper au défilement du ciel. Sur SNES, ils vivent sur BG3,
;      la couche fixe (BGMODE $09) : le texte ne défile pas, par nature.
;      Les sprites servent au JEU, plus à l'affichage.
;
;   4. LE SON EST DE LA PARTIE dès la première ligne : le module commun
;      ../snes-commun/son.s téléverse notre pilote dans le SPC700 (le
;      second ordinateur de la console) et la partition NES rejoue,
;      note pour note, sur des échantillons BRR.
;
;  La logique du jeu, elle, n'a pas bougé d'un octet : sep #$30, et le
;  code 6502 tourne tel quel. Comparez les deux fichiers côte à côte.
; =============================================================================

.setcpu "65816"

; --- Les registres (voir ../casse-brique-snes/ pour le cours détaillé) --------
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

; --- La carte VRAM (en mots) ---------------------------------------------------
;  BG1 : tilemap 32×64 — DEUX écrans de 32×32 EMPILÉS, $0400 puis $0800.
;  (Sur NES, cet empilement était un fil à souder dans la cartouche !)
;  BG3 : tilemap $0C00 (la couche fixe). Tuiles : $1000 (BG1), $3000 (BG3),
;  $4000 (sprites).
VRAM_CIEL   = $0400
VRAM_CIEL2  = $0800
VRAM_FIXE   = $0C00
VRAM_TUILES  = $1000
VRAM_TUILES3 = $3000
VRAM_SPRITES = $4000

; ... et les adresses des textes sur la couche fixe :
TITRE_VRAM    = VRAM_FIXE + 11*32 + 11
RECORD_VRAM   = VRAM_FIXE + 14*32 + 11
APPUIE_VRAM   = VRAM_FIXE + 17*32 + 8
GAMEOVER_VRAM = VRAM_FIXE + 12*32 + 11
HUD_SCORE     = VRAM_FIXE + 1*32 + 2
HUD_VIES      = VRAM_FIXE + 1*32 + 29

; --- Les tuiles ------------------------------------------------------------------
TUILE_VIDE      = $00
TUILE_ETOILE    = $01   ; petite étoile — sa COULEUR viendra de la palette !
TUILE_ETOILE2   = $02   ; étoile brillante
TUILE_NAV_G     = $03   ; l'intercepteur, moitié gauche (sprites)
TUILE_NAV_D     = $04
TUILE_TIR       = $05
TUILE_DRONE_1   = $06
TUILE_DRONE_2   = $07
TUILE_EXPLOSION = $08
TUILE_CHIFFRE_0 = $10   ; sur BG3
TIRET           = $1B
L_A = $20
L_C = $21
L_D = $22
L_E = $23
L_G = $24
L_I = $25
L_M = $26
L_N = $27
L_O = $28
L_P = $29
L_R = $2A
L_T = $2C               ; (R : voir la remarque sur le mot réservé "s"
L_U = $2D               ;  dans le casse-brique SNES — ici pas de piège,
L_V = $2E               ;  nos étiquettes sont L_xxx)
L_LS = $2B              ; la lettre S

; --- Les attributs de tilemap et de sprites ---------------------------------------
ATTR_TEXTE  = $24       ; BG3 : priorité (devant le ciel) + palette 1 (blanc)
ATTR_TITRE  = $28       ; BG3 : palette 2 (cyan) pour le nom du jeu
ATTR_BLEUE  = $10       ; BG1 : palette 4 — étoile bleutée
ATTR_DOREE  = $14       ; BG1 : palette 5 — étoile dorée
ATTR_BLANCHE= $18       ; BG1 : palette 6 — étoile blanche
ATTR_NAV    = $30       ; sprites : priorité 3, palette 0
ATTR_DRONE  = $32       ; palette 1
ATTR_EXPLO  = $34       ; palette 2

; --- Les états (identiques à la NES) ------------------------------------------------
ETAT_TITRE = 0
ETAT_JEU   = 1
ETAT_FINI  = 2
ETAT_PAUSE = 3

ENN_MORT    = 0
ENN_ATTENTE = 1
ENN_VOL     = 2
ENN_EXPLOSE = 3

NAV_Y      = 200
NAV_X_MIN  = 8
NAV_X_MAX  = 232

OAM_OMBRE = $0200


; -----------------------------------------------------------------------------
;  VARIABLES (page directe) — l'ordre NES, conservé
; -----------------------------------------------------------------------------
.zeropage
boutons:          .res 1
anciens:          .res 1
presses:          .res 1
image:            .res 1
etat:             .res 1
nav_x:            .res 1
nav_inv:          .res 1
tir_cd:           .res 1
vies:             .res 1
vague_num:        .res 1
boucle:           .res 1
chute:            .res 1
score_u:          .res 1
score_d:          .res 1
score_c:          .res 1
record_u:         .res 1
record_d:         .res 1
record_c:         .res 1
defil_lo:         .res 1   ; le défilement vertical... sur 16 bits ! Fini le
defil_hi:         .res 1   ; jonglage defil_y/defil_nt de la NES : 0-511.
ennemis_restants: .res 1
pause_cpt:        .res 1
graine:           .res 1
tmp:              .res 1   ; tmp et tmp2 se suivent : (tmp) est un pointeur
tmp2:             .res 1
go_actif:         .res 1   ; la nmi doit écrire GAME OVER sur BG3

tir_actif:        .res 3
tir_x:            .res 3
tir_y:            .res 3

enn_etat:         .res 8
enn_x:            .res 8
enn_y:            .res 8
enn_dx:           .res 8
enn_delai:        .res 8
enn_type:         .res 8


; =============================================================================
;  EN-TÊTE ET RESET
; =============================================================================
.segment "SNESHEADER"
        .byte "NOVA-2026            "
        .byte $20, $00, $05, $00, $01, $00, $00
        .word $FFFF
        .word $0000

.segment "CODE"

reset:
        sei
        clc
        xce                     ; mode natif...
        sep #$30                ; ...mais A, X, Y en 8 bits : du 6502 qui a
        .a8                     ; simplement déménagé.
        .i8
        ldx #$FF
        txs

        lda #$8F
        sta LUMIERE             ; rideau : on installe tout dans le noir

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
        lda #$F0
@cacher_sprites:
        sta $0200, x            ; le brouillon OAM : tout le monde à Y=240,
        sta $0300, x            ; sous les 224 lignes de l'écran
        inx
        bne @cacher_sprites
@vider_haute:
        stz $0400, x            ; la table haute : petits sprites, X < 256
        inx
        cpx #$20
        bne @vider_haute

        ; --- le PPU : mode 1, BG3 prioritaire (notre couche fixe) ---------------
        lda #$09
        sta BGMODE
        lda #((VRAM_CIEL >> 10) << 2) | %10
        sta BG1SC               ; %10 : tilemap 32×64 — l'empilement vertical
        lda #(VRAM_FIXE >> 10) << 2
        sta BG3SC
        lda #VRAM_TUILES >> 12
        sta BG12NBA
        lda #VRAM_TUILES3 >> 12
        sta BG34NBA
        lda #VRAM_SPRITES >> 13
        sta OBSEL
        lda #$15
        sta TM                  ; fond 1 + fond 3 + sprites
        stz BG1HOFS             ; (chaque registre de défilement se règle en
        stz BG1HOFS             ;  DEUX écritures : octet bas puis haut)
        stz BG1VOFS
        stz BG1VOFS
        stz BG3HOFS
        stz BG3HOFS
        stz BG3VOFS
        stz BG3VOFS

        ; --- vider les 64 Ko de VRAM (DMA à source figée) -----------------------
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

        ; --- charger les trois blocs de tuiles et les couleurs ------------------
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

        ; --- le HDMA du fond : l'espace profond, ligne après ligne --------------
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

        ; --- le monde ------------------------------------------------------------
        lda #$5A                ; n'importe quoi SAUF zéro : un LFSR nourri
        sta graine              ; de zéro ne produit que des zéros !
        jsr semer_les_etoiles
        jsr dessiner_ecran_titre
        lda #ETAT_TITRE
        sta etat
        lda #3
        sta vies
        lda #116
        sta nav_x

        ; --- le SPC700 (avant la NMI : le téléversement veut le silence) --------
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
        lda #$81                ; NMI au VBlank + lecture auto des manettes
        sta NMITIMEN
        lda #$0F
        sta LUMIERE
        rts


; =============================================================================
;  aleatoire — le MÊME LFSR que sur NES, au bit près
; =============================================================================
aleatoire:
        lda graine
        asl a
        bcc @sans_xor
        eor #$1D
@sans_xor:
        sta graine
        rts

; -----------------------------------------------------------------------------
;  semer_les_etoiles — remplit les DEUX écrans empilés (32×64 = 2048 cases)
; -----------------------------------------------------------------------------
;  Nouveauté SNES : le LFSR choisit AUSSI la couleur. Une étoile sur 32,
;  bleutée ou dorée selon un bit de la graine ; les très rares brillantes
;  sont blanches. L'octet haut de la tilemap (la palette) fait tout.
semer_les_etoiles:
        lda #$80
        sta VMAIN
        lda #<VRAM_CIEL         ; l'écran du haut ($0400)...
        ldx #>VRAM_CIEL
        jsr @un_ecran
        lda #<VRAM_CIEL2        ; ...puis celui du bas ($0800)
        ldx #>VRAM_CIEL2
@un_ecran:
        sta VMADDL
        stx VMADDH
        ldx #4                  ; 4 paquets de 256 cases = 1024
@paquet:
        ldy #0
@case:
        jsr aleatoire           ; chaque case tire son destin au sort :
        sta tmp
        and #%00011111
        beq @petite             ; 1 chance sur 32 : une petite étoile
        lda tmp
        cmp #$E7
        beq @brillante          ; 1 chance sur 256 : une brillante !
        stz VMDATAL             ; le vide spatial
        stz VMDATAH
        jmp @suivante           ; (le PIÈGE du "bne" est raconté dans la
@petite:                        ;  version NES — ici, jmp et on n'y pense plus)
        lda #TUILE_ETOILE
        sta VMDATAL
        lda tmp                 ; le bit 5 de la graine choisit la teinte
        and #%00100000
        beq @bleutee
        lda #ATTR_DOREE
        sta VMDATAH
        jmp @suivante
@bleutee:
        lda #ATTR_BLEUE
        sta VMDATAH
        jmp @suivante
@brillante:
        lda #TUILE_ETOILE2
        sta VMDATAL
        lda #ATTR_BLANCHE
        sta VMDATAH
@suivante:
        dey
        bne @case
        dex
        bne @paquet
        rts                     ; (pas d'attributs à écrire : sur SNES, la
                                ;  couleur est DANS la tilemap. Adieu, blocs
                                ;  de 16×16 de la NES !)


; =============================================================================
;  L'ÉCRAN TITRE — sur BG3, la couche fixe (le ciel défile derrière !)
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
        lda texte_titre, x
        sta VMDATAL
        lda #ATTR_TITRE         ; le nom du jeu en cyan
        sta VMDATAH
        inx
        cpx #9
        bne @titre

        lda #<RECORD_VRAM
        sta VMADDL
        lda #>RECORD_VRAM
        sta VMADDH
        ldx #0
@record:
        lda texte_record, x
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        inx
        cpx #7
        bne @record
        lda record_c
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        lda record_d
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        lda record_u
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH

        lda #<APPUIE_VRAM
        sta VMADDL
        lda #>APPUIE_VRAM
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

texte_titre:
        .byte L_N, L_O, L_V, L_A, TIRET
        .byte TUILE_CHIFFRE_0+2, TUILE_CHIFFRE_0, TUILE_CHIFFRE_0+2, TUILE_CHIFFRE_0+6
texte_record:
        .byte L_R, L_E, L_C, L_O, L_R, L_D, ESPACE
texte_appuie:
        .byte L_A, L_P, L_P, L_U, L_I, L_E, ESPACE, L_LS, L_U, L_R, ESPACE
        .byte L_LS, L_T, L_A, L_R, L_T
ESPACE = $00

effacer_ecran_titre:
        lda #$80
        sta VMAIN
        lda #<TITRE_VRAM
        sta VMADDL
        lda #>TITRE_VRAM
        sta VMADDH
        ldx #9
@l1:    stz VMDATAL
        stz VMDATAH
        dex
        bne @l1
        lda #<RECORD_VRAM
        sta VMADDL
        lda #>RECORD_VRAM
        sta VMADDH
        ldx #10
@l2:    stz VMDATAL
        stz VMDATAH
        dex
        bne @l2
        lda #<APPUIE_VRAM
        sta VMADDL
        lda #>APPUIE_VRAM
        sta VMADDH
        ldx #16
@l3:    stz VMDATAL
        stz VMDATAH
        dex
        bne @l3
        rts

effacer_gameover:
        lda #$80
        sta VMAIN
        lda #<GAMEOVER_VRAM
        sta VMADDL
        lda #>GAMEOVER_VRAM
        sta VMADDH
        ldx #9
@l:     stz VMDATAL
        stz VMDATAH
        dex
        bne @l
        rts


; =============================================================================
;  DÉMARRER, VAGUES — la logique NES, à l'identique
; =============================================================================
demarrer_partie:
        jsr eteindre_ecran
        jsr effacer_ecran_titre
        lda #0
        sta score_u
        sta score_d
        sta score_c
        sta vague_num
        sta boucle
        sta nav_inv
        sta tir_cd
        ldx #2
@tirs:
        sta tir_actif, x
        dex
        bpl @tirs
        ldx #7
@ennemis:
        sta enn_etat, x
        dex
        bpl @ennemis
        lda #1
        sta chute
        lda #3
        sta vies
        lda #116
        sta nav_x
        lda #ETAT_PAUSE
        sta etat
        lda #60
        sta pause_cpt
        jsr charger_vague
        jsr allumer_ecran
        rts

charger_vague:
        lda vague_num
        and #%00000111
        tax
        lda vagues_lo, x
        sta tmp
        lda vagues_hi, x
        sta tmp2
        ldy #0
        ldx #0
@drone:
        lda (tmp), y
        sta enn_type, x
        iny
        lda (tmp), y
        sta enn_x, x
        iny
        lda (tmp), y
        sta enn_delai, x
        iny
        lda #ENN_ATTENTE
        sta enn_etat, x
        lda #8
        sta enn_y, x
        lda #1
        sta enn_dx, x
        inx
        cpx #8
        bne @drone
        lda #8
        sta ennemis_restants
        rts

vagues_lo: .byte <vague_1, <vague_2, <vague_3, <vague_4
           .byte <vague_5, <vague_6, <vague_7, <vague_8
vagues_hi: .byte >vague_1, >vague_2, >vague_3, >vague_4
           .byte >vague_5, >vague_6, >vague_7, >vague_8


; =============================================================================
;  LA BOUCLE PRINCIPALE
; =============================================================================
principale:
        jsr attendre_nmi
        jsr maj_musique
        jsr maj_bruitages
        jsr lire_manette

        lda etat
        cmp #ETAT_JEU
        bne @pas_jeu
        jmp @en_jeu
@pas_jeu:
        cmp #ETAT_PAUSE
        beq @entracte
        cmp #ETAT_TITRE
        beq @au_titre

        ; --- FINI : Start pour revenir au titre --------------------------------
        lda presses
        and #BTN_START
        bne @retour_titre
        jmp @dessiner
@retour_titre:
        jsr eteindre_ecran
        jsr effacer_gameover
        jsr dessiner_ecran_titre
        stz defil_lo
        stz defil_hi
        stz go_actif
        lda #0                  ; (A doit valoir 0 : la boucle le range partout)
        ldx #7
@nettoyer:
        sta enn_etat, x
        cpx #3
        bcs @pas_tir
        sta tir_actif, x
@pas_tir:
        dex
        bpl @nettoyer
        lda #ETAT_TITRE
        sta etat
        lda #3
        sta vies
        jsr demarrer_musique
        jsr allumer_ecran
        jmp @dessiner

@au_titre:
        ; le ciel est figé au titre : le texte trône sur la couche fixe
        lda presses
        and #BTN_START
        beq @dessiner
        jsr demarrer_partie
        jsr bip_depart
        jmp @dessiner

@entracte:
        jsr defiler_le_ciel
        jsr maj_nav
        jsr maj_tirs
        dec pause_cpt
        bne @dessiner
        lda #ETAT_JEU
        sta etat
        jsr bip_vague
        jmp @dessiner

@en_jeu:
        jsr defiler_le_ciel
        jsr maj_nav
        jsr maj_tirs
        jsr maj_ennemis
        jsr collisions_tirs
        lda ennemis_restants
        bne @dessiner
        inc vague_num
        lda vague_num
        cmp #8
        bcc @vague_suivante
        lda #0
        sta vague_num
        lda boucle
        cmp #2
        bcs @vague_suivante
        inc boucle
        inc chute
@vague_suivante:
        jsr charger_vague
        lda #ETAT_PAUSE
        sta etat
        lda #90
        sta pause_cpt

@dessiner:
        jsr maj_sprites
        jmp principale


attendre_nmi:
        lda image
@patienter:
        cmp image
        beq @patienter
        rts

; Le ciel défile : sur NES c'était un octet, un drapeau de nametable et une
; couture à 240. Ici : UN nombre de 16 bits qui boucle sur 512. Voilà tout.
defiler_le_ciel:
        lda defil_lo
        bne @simple
        dec defil_hi            ; l'emprunt de la soustraction 16 bits
@simple:
        dec defil_lo
        lda defil_hi
        and #%00000001          ; le ciel fait 512 pixels : on reboucle
        sta defil_hi
        rts


lire_manette:
        lda boutons
        sta anciens
@occupe:
        lda HVBJOY              ; l'auto-joypad travaille encore ?
        and #1
        bne @occupe
        lda JOY1H               ; même disposition de bits que sur NES !
        sta boutons
        lda anciens
        eor #$FF
        and boutons
        sta presses
        rts


; =============================================================================
;  maj_nav — piloter, tirer, encaisser (le code NES, octet pour octet)
; =============================================================================
maj_nav:
        lda boutons
        and #BTN_GAUCHE
        beq @pas_gauche
        lda nav_x
        sec
        sbc #2
        sta nav_x
        cmp #NAV_X_MIN
        bcs @pas_gauche
        lda #NAV_X_MIN
        sta nav_x
@pas_gauche:
        lda boutons
        and #BTN_DROITE
        beq @pas_droite
        lda nav_x
        clc
        adc #2
        sta nav_x
        cmp #NAV_X_MAX + 1
        bcc @pas_droite
        lda #NAV_X_MAX
        sta nav_x
@pas_droite:

        lda nav_inv
        beq @vulnerable
        dec nav_inv
@vulnerable:

        lda tir_cd
        beq @charge
        dec tir_cd
        rts
@charge:
        lda boutons
        and #BTN_A
        beq @fin
        ldx #2
@chercher:
        lda tir_actif, x
        beq @tirer
        dex
        bpl @chercher
        rts
@tirer:
        lda #1
        sta tir_actif, x
        lda nav_x
        clc
        adc #4
        sta tir_x, x
        lda #NAV_Y - 8
        sta tir_y, x
        lda #12
        sta tir_cd
        jsr bip_tir
@fin:
        rts


maj_tirs:
        ldx #2
@tir:
        lda tir_actif, x
        beq @suivant
        lda tir_y, x
        sec
        sbc #4
        sta tir_y, x
        cmp #12
        bcs @suivant
        lda #0
        sta tir_actif, x
@suivant:
        dex
        bpl @tir
        rts


; =============================================================================
;  maj_ennemis — délais, vol, zigzag, explosions, contact
; =============================================================================
maj_ennemis:
        ldx #7
@drone:
        lda enn_etat, x
        cmp #ENN_ATTENTE
        beq @patiente
        cmp #ENN_VOL
        beq @vole
        cmp #ENN_EXPLOSE
        beq @explose
        jmp @suivant

        ; (Les branches conditionnelles ne portent qu'à ±127 octets, et les
        ;  appels aux bruitages ont allongé la routine : on saute donc sur
        ;  des JMP tout proches — la parade classique, voir le casse-brique.)
@patiente:
        dec enn_delai, x
        beq @entre_en_scene
        jmp @suivant
@entre_en_scene:
        lda #ENN_VOL
        sta enn_etat, x
        jmp @suivant

@explose:
        dec enn_delai, x
        beq @feu_eteint
        jmp @suivant
@feu_eteint:
        lda #ENN_MORT
        sta enn_etat, x
        jmp @suivant

@vole:
        lda enn_y, x
        clc
        adc chute
        sta enn_y, x
        cmp #237
        bcc @dans_le_ciel
        lda #ENN_MORT
        sta enn_etat, x
        dec ennemis_restants
        jmp @suivant
@dans_le_ciel:
        lda enn_type, x
        beq @contact
        lda enn_x, x
        clc
        adc enn_dx, x
        sta enn_x, x
        cmp #9
        bcs @pas_bord_gauche
        lda #1
        sta enn_dx, x
@pas_bord_gauche:
        lda enn_x, x
        cmp #240
        bcc @contact
        lda #$FF
        sta enn_dx, x

@contact:
        lda nav_inv
        bne @suivant
        lda enn_y, x
        cmp #NAV_Y - 7
        bcc @suivant
        cmp #NAV_Y + 8
        bcs @suivant
        lda enn_x, x
        sec
        sbc nav_x
        clc
        adc #7
        cmp #24
        bcs @suivant
        ; --- touché ! -----------------------------------------------------------
        lda #ENN_EXPLOSE
        sta enn_etat, x
        lda #12
        sta enn_delai, x
        dec ennemis_restants
        lda #90
        sta nav_inv
        jsr bruit_touche
        dec vies
        bne @suivant
        lda #ETAT_FINI          ; plus de vies : GAME OVER
        sta etat
        lda #1                  ; ...que la nmi écrira sur la couche fixe
        sta go_actif
        jsr maj_record
        jsr arreter_musique
        jsr bruit_fin
@suivant:
        dex
        bmi @fin
        jmp @drone
@fin:
        rts


; =============================================================================
;  collisions_tirs — chaque tir contre chaque drone en vol
; =============================================================================
collisions_tirs:
        ldx #2
@tir:
        lda tir_actif, x
        bne @tir_reel
        jmp @tir_suivant
@tir_reel:
        ldy #7
@drone:
        lda enn_etat, y
        cmp #ENN_VOL
        bne @drone_suivant
        lda tir_y, x
        sec
        sbc enn_y, y
        clc
        adc #7
        cmp #15
        bcs @drone_suivant
        lda tir_x, x
        sec
        sbc enn_x, y
        clc
        adc #5
        cmp #13
        bcs @drone_suivant
        ; --- TOUCHÉ ! -------------------------------------------------------------
        lda #0
        sta tir_actif, x
        lda #ENN_EXPLOSE
        sta enn_etat, y
        lda #12
        sta enn_delai, y
        dec ennemis_restants
        inc score_d
        lda score_d
        cmp #10
        bne @score_ok
        lda #0
        sta score_d
        inc score_c
        lda score_c
        cmp #10
        bne @score_ok
        lda #0
        sta score_c
@score_ok:
        jsr bruit_explosion
        jmp @tir_suivant
@drone_suivant:
        dey
        bpl @drone
@tir_suivant:
        dex
        bmi @fin
        jmp @tir
@fin:
        rts


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
;  maj_sprites — vaisseau, tirs, drones. Et C'EST TOUT : le HUD et le
;  GAME OVER ont déménagé sur la couche fixe. Comparez avec la version NES,
;  qui devait dessiner ses chiffres en sprites pour fuir le défilement !
; =============================================================================
;  L'OAM SNES range : X, Y, tuile, attributs (la NES : Y, tuile, attr, X).
maj_sprites:
        lda etat
        cmp #ETAT_FINI
        beq @cacher_nav
        lda nav_inv
        beq @nav_visible
        lda image
        and #%00000100          ; le clignotement des i-frames
        beq @nav_visible
@cacher_nav:
        lda #$F0
        sta $0201
        sta $0205
        jmp @tirs
@nav_visible:
        lda #NAV_Y
        sta $0201
        sta $0205
        lda #TUILE_NAV_G
        sta $0202
        lda #TUILE_NAV_D
        sta $0206
        lda #ATTR_NAV
        sta $0203
        sta $0207
        lda nav_x
        sta $0200
        clc
        adc #8
        sta $0204

@tirs:
        ldx #2
@un_tir:
        txa                     ; sprite 2+X → OAM $0208 + X×4
        asl a
        asl a
        clc
        adc #8
        tay
        lda tir_actif, x
        beq @cacher_tir
        lda tir_y, x
        sta $0201, y
        lda #TUILE_TIR
        sta $0202, y
        lda #ATTR_NAV
        sta $0203, y
        lda tir_x, x
        sta $0200, y
        jmp @tir_suivant
@cacher_tir:
        lda #$F0
        sta $0201, y
@tir_suivant:
        dex
        bpl @un_tir

        ldx #7
@un_drone:
        txa                     ; sprite 5+X → OAM $0214 + X×4
        asl a
        asl a
        clc
        adc #20
        tay
        lda enn_etat, x
        cmp #ENN_VOL
        beq @drone_visible
        cmp #ENN_EXPLOSE
        beq @drone_explose
        lda #$F0
        sta $0201, y
        jmp @drone_suivant
@drone_explose:
        lda enn_y, x
        sta $0201, y
        lda #TUILE_EXPLOSION
        sta $0202, y
        lda #ATTR_EXPLO
        sta $0203, y
        lda enn_x, x
        sta $0200, y
        jmp @drone_suivant
@drone_visible:
        lda enn_y, x
        sta $0201, y
        lda image
        and #%00000100
        beq @rotor_1
        lda #TUILE_DRONE_2
        bne @rotor_ok
@rotor_1:
        lda #TUILE_DRONE_1
@rotor_ok:
        sta $0202, y
        lda #ATTR_DRONE
        sta $0203, y
        lda enn_x, x
        sta $0200, y
@drone_suivant:
        dex
        bpl @un_drone
        rts

texte_gameover:
        .byte L_G, L_A, L_M, L_E, ESPACE, L_O, L_V, L_E, L_R


; =============================================================================
;  NMI — DMA des sprites, GAME OVER en attente, HUD, et le défilement 16 bits
; =============================================================================
nmi:
        pha
        phx
        phy
        lda RDNMI               ; acquitter l'interruption (lecture obligée)

        ; --- 1) les 544 octets de sprites, d'un souffle ---------------------------
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

        ; --- 2) GAME OVER à écrire sur la couche fixe ? ---------------------------
        lda go_actif
        beq @pas_go
        stz go_actif
        lda #<GAMEOVER_VRAM
        sta VMADDL
        lda #>GAMEOVER_VRAM
        sta VMADDH
        ldx #0
@go_lettre:
        lda texte_gameover, x
        sta VMDATAL
        beq @go_vide            ; l'espace : pas d'attribut lumineux
        lda #ATTR_TEXTE
        sta VMDATAH
        jmp @go_suite
@go_vide:
        stz VMDATAH
@go_suite:
        inx
        cpx #9
        bne @go_lettre
@pas_go:

        ; --- 3) le HUD : score et vies, sur la couche fixe -------------------------
        lda #<HUD_SCORE
        sta VMADDL
        lda #>HUD_SCORE
        sta VMADDH
        lda score_c
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        lda score_d
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        lda score_u
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH
        lda #<HUD_VIES
        sta VMADDL
        lda #>HUD_VIES
        sta VMADDH
        lda vies
        clc
        adc #TUILE_CHIFFRE_0
        sta VMDATAL
        lda #ATTR_TEXTE
        sta VMDATAH

        ; --- 4) le défilement : DEUX écritures, et le ciel de 512 px tourne --------
        lda defil_lo
        sta BG1VOFS
        lda defil_hi
        sta BG1VOFS

        inc image
        ply
        plx
        pla
retour_int:
        rti


; =============================================================================
;  LE SON — le module SPC700 commun, et le catalogue de NOVA
; =============================================================================
.include "son.s"

bip_depart:                     ; Start pressé
        lda #NOTE_LA4
        ldy #4
        jmp jouer_bip
bip_tir:                        ; pew ! très bref, très aigu
        lda #NOTE_DO6
        ldy #2
        jmp jouer_bip
bip_vague:                      ; la vague suivante arrive
        lda #NOTE_LA5
        ldy #8
        jmp jouer_bip
bruit_explosion:
        ldy #10
        jmp jouer_bruit
bruit_touche:                   ; ça, c'était notre coque
        ldy #25
        jmp jouer_bruit
bruit_fin:
        ldy #45
        jmp jouer_bruit

; LA PARTITION — la même que sur NES. (Sur NES, la mélodie jouait en onde
; carrée 25 % pour un timbre plus fin ; notre échantillon BRR est un carré
; 50 %. Exercice : dessinez un BRR 25 % dans son.s et comparez à l'oreille !)
melodie:
        .byte NOTE_LA4,  12, NOTE_MI5, 12, NOTE_DO5,  12, NOTE_MI5, 12
        .byte NOTE_LA4,  12, NOTE_MI5, 12, NOTE_DO5,  12, NOTE_MI5, 12
        .byte NOTE_FA4,  12, NOTE_DO5, 12, NOTE_LA4,  12, NOTE_DO5, 12
        .byte NOTE_SOL4, 12, NOTE_RE5, 12, NOTE_SI4,  12, NOTE_RE5, 12
        .byte $FF
basse:
        .byte NOTE_LA2, 48, NOTE_LA2, 48, NOTE_FA2, 48, NOTE_SOL2, 48
        .byte $FF


; =============================================================================
;  LES VAGUES — les mêmes 8 tables de 8 drones que sur NES
; =============================================================================
vague_1:        ; l'accueil : une file bien élevée
        .byte 0, 32,  1,   0, 56, 10,   0, 80, 20,   0,104, 30
        .byte 0,128, 40,   0,152, 50,   0,176, 60,   0,200, 70
vague_2:        ; deux colonnes serrées
        .byte 0, 60,  1,   0,180,  1,   0, 60, 25,   0,180, 25
        .byte 0, 60, 50,   0,180, 50,   0, 60, 75,   0,180, 75
vague_3:        ; les premiers zigzags
        .byte 1, 40,  1,   0, 90, 15,   1,140, 30,   0,190, 45
        .byte 1, 40, 60,   0, 90, 75,   1,140, 90,   0,190,105
vague_4:        ; le grand V
        .byte 0, 24,  1,   0,200,  1,   0, 56, 20,   0,168, 20
        .byte 0, 88, 40,   0,136, 40,   0,112, 60,   1,112, 90
vague_5:        ; tout le monde danse
        .byte 1, 30,  1,   1, 90, 12,   1,150, 24,   1,210, 36
        .byte 1, 60, 48,   1,120, 60,   1,180, 72,   1, 30, 84
vague_6:        ; par les flancs !
        .byte 1, 16,  1,   1,224,  1,   1, 16, 20,   1,224, 20
        .byte 1, 16, 40,   1,224, 40,   1, 16, 60,   1,224, 60
vague_7:        ; le rideau qui tombe
        .byte 0, 24,  1,   0, 52,  5,   0, 80, 10,   0,108, 15
        .byte 0,136, 20,   0,164, 25,   0,192, 30,   0,220, 35
vague_8:        ; le chaos final
        .byte 1, 48,  1,   0,120,  8,   1,192, 16,   0, 72, 24
        .byte 1,144, 32,   0,216, 40,   1, 96, 48,   0, 24, 56


; =============================================================================
;  LES GRAPHISMES, incorporés depuis l'atelier make_gfx.py
; =============================================================================
.segment "RODATA"
gfx_bg:      .incbin "gfx_bg.bin"
fin_gfx_bg:
gfx_bg3:     .incbin "gfx_bg3.bin"
fin_gfx_bg3:
gfx_obj:     .incbin "gfx_obj.bin"
fin_gfx_obj:
palettes:    .incbin "palettes.bin"
gradient:    .incbin "gradient.bin"


; =============================================================================
;  LES VECTEURS — deux jeux : mode natif ET mode émulation
; =============================================================================
.segment "VECTORS"
        ;      -       -       COP         BRK         ABORT       NMI    -       IRQ
        .word  0,      0,      retour_int, retour_int, retour_int, nmi,   0,      retour_int
        ;      -       -       COP         -           ABORT       NMI    RESET   IRQ
        .word  0,      0,      retour_int, 0,          retour_int, 0,     reset,  retour_int
