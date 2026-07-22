; =============================================================================
;  NOVA-2026 — un shoot'em up spatial en assembleur 6502 (niveau 3 du cours)
; =============================================================================
;
;  2026, orbite basse. Les drones de livraison devenus fous foncent sur le
;  relais orbital. Vous pilotez l'intercepteur NOVA : 8 vagues d'ennemis,
;  puis tout recommence — plus vite. Tenez aussi longtemps que possible !
;
;  Commandes : ←/→ piloter · A tirer (maintenez : tir automatique)
;              Start commencer / rejouer.
;  Un drone abattu : 10 points. Un drone qui vous percute : une vie
;  (mais quelques secondes d'invincibilité clignotante pour souffler).
;
;  CE FICHIER EST LE "NIVEAU 3" DU COURS.
;  ---------------------------------------
;  Les bases sont dans ../casse-brique-nes/ (PPU, sprites, APU, virgule
;  fixe...), le défilement horizontal dans ../neo-runner-2026/. Voici les
;  leçons NOUVELLES de ce jeu :
;
;   1. LE DÉFILEMENT VERTICAL. La cartouche est câblée en "miroir
;      HORIZONTAL" (octet 6 de l'en-tête à $00) : les deux écrans internes
;      sont EMPILÉS l'un sur l'autre au lieu d'être côte à côte. Le champ
;      d'étoiles descend de 1 pixel par image : sensation de vol, pour le
;      prix de deux octets par VBlank. Et une fois les étoiles semées, ce
;      jeu N'ÉCRIT PLUS JAMAIS dans le décor : tout ce qui bouge est
;      sprite. Comparez avec les deux autres jeux !
;
;   2. LE HASARD, POUR DE VRAI : un LFSR (registre à décalage rebouclé).
;      Le 6502 n'a pas de fonction random... alors on la fabrique en
;      4 instructions (voir `aleatoire`). C'est lui qui sème les étoiles.
;
;   3. LES RÉSERVOIRS D'OBJETS (object pools). 3 tirs, 8 ennemis : des
;      petits tableaux de tableaux parallèles (enn_x, enn_y, enn_etat...)
;      parcourus avec X et Y. Un objet "meurt" en remettant son état à 0,
;      il "naît" en trouvant une case libre. Aucune allocation, jamais :
;      sur console, la mémoire se découpe une fois pour toutes.
;
;   4. LES VAGUES PILOTÉES PAR LES DONNÉES : chaque vague est une table de
;      8 entrées (type, x, délai). Le code ne connaît aucune vague — il
;      les lit. Ajouter une vague = écrire 24 octets.
;
;   5. L'INVINCIBILITÉ TEMPORAIRE (les "i-frames") : après un choc, un
;      compteur rend le vaisseau intouchable et le fait clignoter. Tous
;      les jeux d'action font ça — maintenant vous savez comment.
; =============================================================================


; --- Registres matériels (voir le casse-brique pour le détail) ----------------
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014
APUSTATUS = $4015
JOYPAD1   = $4016
APUFRAME  = $4017

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

BTN_A      = %10000000
BTN_START  = %00010000
BTN_GAUCHE = %00000010
BTN_DROITE = %00000001

; --- Les tuiles ------------------------------------------------------------------
TUILE_VIDE      = $00
TUILE_ETOILE    = $01   ; petite étoile (couleur 1, discrète)
TUILE_ETOILE2   = $02   ; étoile brillante (couleur 3)
TUILE_NAV_G     = $03   ; l'intercepteur, moitié gauche
TUILE_NAV_D     = $04
TUILE_TIR       = $05
TUILE_DRONE_1   = $06   ; le drone, rotors phase 1
TUILE_DRONE_2   = $07   ; phase 2
TUILE_EXPLOSION = $08
TUILE_CHIFFRE_0 = $10
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
L_S = $2B
L_T = $2C
L_U = $2D
L_V = $2E
ESPACE = $00

; --- Les états -----------------------------------------------------------------------
ETAT_TITRE = 0
ETAT_JEU   = 1
ETAT_FINI  = 2
ETAT_PAUSE = 3      ; le court répit entre deux vagues

; ... et ceux d'un ennemi (dans enn_etat) :
ENN_MORT    = 0
ENN_ATTENTE = 1     ; pas encore entré en scène (son délai décompte)
ENN_VOL     = 2
ENN_EXPLOSE = 3     ; l'explosion s'affiche quelques images

; --- La géométrie -----------------------------------------------------------------------
NAV_Y      = 200    ; l'altitude (fixe) du vaisseau
NAV_X_MIN  = 8
NAV_X_MAX  = 232    ; le vaisseau fait 16 pixels de large

; --- Les notes (mêmes tables que les autres jeux) ------------------------------------------
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


; -----------------------------------------------------------------------------
;  VARIABLES en page zéro
; -----------------------------------------------------------------------------
.zeropage

boutons:          .res 1
anciens:          .res 1
presses:          .res 1
image:            .res 1
etat:             .res 1

nav_x:            .res 1
nav_inv:          .res 1   ; images d'invincibilité restantes (clignote !)
tir_cd:           .res 1   ; recharge du canon (images avant le prochain tir)

vies:             .res 1
vague_num:        .res 1   ; 0-7, puis on reboucle...
boucle:           .res 1   ; ...et ceci augmente : les drones accélèrent
chute:            .res 1   ; vitesse de descente des drones (1 + boucle)

score_u:          .res 1
score_d:          .res 1
score_c:          .res 1
record_u:         .res 1   ; le record de la session (voir le casse-brique)
record_d:         .res 1
record_c:         .res 1

defil_y:          .res 1   ; le défilement vertical : la position des étoiles
defil_nt:         .res 1   ; ...et l'écran (haut/bas) où il commence

ennemis_restants: .res 1
pause_cpt:        .res 1
graine:           .res 1   ; la graine du générateur aléatoire (jamais 0 !)
tmp:              .res 1
tmp2:             .res 1

; Le réservoir de tirs : 3 au maximum à l'écran
tir_actif:        .res 3
tir_x:            .res 3
tir_y:            .res 3

; Le réservoir d'ennemis : 8 drones, en tableaux parallèles
enn_etat:         .res 8
enn_x:            .res 8
enn_y:            .res 8
enn_dx:           .res 8   ; +1 ou $FF : le sens du zigzag
enn_delai:        .res 8   ; délai d'entrée, puis durée d'explosion
enn_type:         .res 8   ; 0 = tout droit, 1 = zigzag

; Le moteur de musique
mus_active:       .res 1
mel_pos:          .res 1
mel_cpt:          .res 1
bas_pos:          .res 1
bas_cpt:          .res 1
bip_cpt:          .res 1
bruit_cpt:        .res 1


; =============================================================================
;  L'EN-TÊTE iNES — ATTENTION, l'octet 6 change tout !
; =============================================================================
.segment "HEADER"
        .byte 'N', 'E', 'S', $1A
        .byte 2
        .byte 1
        .byte $00                  ; $00 = miroir HORIZONTAL : les 2 écrans
        .byte $00                  ; internes sont EMPILÉS verticalement —
        .byte 0,0,0,0,0,0,0,0      ; la clé du défilement vertical !


.segment "CODE"

; =============================================================================
;  RESET
; =============================================================================
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
        sta $0200, x
        lda #0
        inx
        bne @vider_ram
@attente_vblank_2:
        bit PPUSTATUS
        bpl @attente_vblank_2

        lda #$5A                ; n'importe quoi SAUF zéro : un LFSR nourri
        sta graine              ; de zéro ne produit que des zéros !

        jsr charger_palettes
        jsr semer_les_etoiles
        jsr dessiner_ecran_titre
        lda #ETAT_TITRE
        sta etat
        lda #3
        sta vies
        lda #116
        sta nav_x

        lda #%00001111
        sta APUSTATUS
        jsr demarrer_musique
        jsr allumer_ecran
        jmp principale


eteindre_ecran:
        lda #0
        sta PPUCTRL
        sta PPUMASK
        rts

allumer_ecran:
        bit PPUSTATUS
@attendre:
        bit PPUSTATUS
        bpl @attendre
        lda #0
        sta PPUSCROLL           ; défilement horizontal : toujours 0
        lda defil_y
        sta PPUSCROLL           ; défilement vertical : les étoiles !
        lda defil_nt
        asl a                   ; l'écran de départ (haut/bas) est le BIT 1
        ora #%10000000          ; de PPUCTRL (le bit 0, c'est l'horizontal)
        sta PPUCTRL
        lda #%00011110
        sta PPUMASK
        rts


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
        ; --- fond : la nuit spatiale ---
        .byte $0F, $10, $02, $30   ; étoiles grises, bleutées, blanches
        .byte $0F, $0F, $0F, $0F
        .byte $0F, $0F, $0F, $0F
        .byte $0F, $0F, $0F, $0F
        ; --- sprites ---
        .byte $0F, $30, $2C, $16   ; 0 : l'intercepteur (blanc/cyan/rouge)
        .byte $0F, $25, $15, $30   ; 1 : les drones (rose/rouge)
        .byte $0F, $28, $16, $30   ; 2 : les explosions (or/rouge/blanc)
        .byte $0F, $00, $00, $30   ; 3 : les chiffres et le texte (blanc)


; =============================================================================
;  aleatoire — 4 instructions de pur hasard : le LFSR
; =============================================================================
;  Un registre à décalage rebouclé : on décale la graine vers la gauche, et
;  si un 1 est "tombé" du bord, on retourne quelques bits (le XOR $1D, des
;  positions choisies par les mathématiciens). La suite obtenue met 255
;  tours à se répéter et a toutes les apparences du hasard. C'est le
;  générateur aléatoire de la plupart des jeux 8 bits !

aleatoire:
        lda graine
        asl a
        bcc @sans_xor
        eor #$1D
@sans_xor:
        sta graine
        rts

; -----------------------------------------------------------------------------
;  semer_les_etoiles — remplit LES DEUX écrans empilés de ciel étoilé
; -----------------------------------------------------------------------------
semer_les_etoiles:
        lda #$20                ; l'écran du haut ($2000)...
        jsr @un_ecran
        lda #$28                ; ...puis celui du bas ($2800)
@un_ecran:
        bit PPUSTATUS
        sta PPUADDR
        lda #$00
        sta PPUADDR
        ldx #4                  ; 4 paquets de 240 tuiles = 960
@paquet:
        ldy #240
@tuile:
        jsr aleatoire           ; chaque tuile tire son destin au sort :
        sta tmp
        and #%00011111
        beq @petite             ; 1 chance sur 32 : une petite étoile
        lda tmp
        cmp #$E7
        beq @brillante          ; 1 chance sur 256 : une brillante !
        lda #TUILE_VIDE
        jmp @poser              ; PIÈGE : "bne @poser" ici serait FAUX !
@petite:                        ; LDA #0 vient d'allumer le drapeau Z, donc
                                ; le BNE ne serait jamais pris... et tout le
                                ; ciel deviendrait étoile. Vécu.
        lda #TUILE_ETOILE
        bne @poser
@brillante:
        lda #TUILE_ETOILE2
@poser:
        sta PPUDATA
        dey
        bne @tuile
        dex
        bne @paquet
        lda #0                  ; les 64 octets d'attributs : palette 0
        ldx #64
@attribut:
        sta PPUDATA
        dex
        bne @attribut
        rts


; =============================================================================
;  L'ÉCRAN TITRE (et son effacement au lancement)
; =============================================================================
dessiner_ecran_titre:
        bit PPUSTATUS
        lda #$21                ; rangée 12, colonne 11
        sta PPUADDR
        lda #$8B
        sta PPUADDR
        ldx #0
@titre:
        lda texte_titre, x
        sta PPUDATA
        inx
        cpx #9
        bne @titre

        lda #$21                ; rangée 15, colonne 11 : RECORD puis chiffres
        sta PPUADDR
        lda #$EB
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
        .byte L_N, L_O, L_V, L_A, TIRET
        .byte TUILE_CHIFFRE_0+2, TUILE_CHIFFRE_0, TUILE_CHIFFRE_0+2, TUILE_CHIFFRE_0+6
texte_record:
        .byte L_R, L_E, L_C, L_O, L_R, L_D, ESPACE
texte_appuie:
        .byte L_A, L_P, L_P, L_U, L_I, L_E, ESPACE, L_S, L_U, L_R, ESPACE
        .byte L_S, L_T, L_A, L_R, L_T

; On efface les trois lignes du titre (les trous dans les étoiles ne se
; verront pas : le ciel défile aussitôt).
effacer_ecran_titre:
        bit PPUSTATUS
        lda #$21
        sta PPUADDR
        lda #$8B
        sta PPUADDR
        lda #TUILE_VIDE
        ldx #9
@l1:    sta PPUDATA
        dex
        bne @l1
        lda #$21
        sta PPUADDR
        lda #$EB
        sta PPUADDR
        lda #TUILE_VIDE
        ldx #10
@l2:    sta PPUDATA
        dex
        bne @l2
        lda #$22
        sta PPUADDR
        lda #$48
        sta PPUADDR
        lda #TUILE_VIDE
        ldx #16
@l3:    sta PPUDATA
        dex
        bne @l3
        rts


; =============================================================================
;  DÉMARRER, VAGUES
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
        ldx #2                  ; vider le réservoir de tirs...
@tirs:
        sta tir_actif, x
        dex
        bpl @tirs
        ldx #7                  ; ...et celui des ennemis
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
        lda #ETAT_PAUSE         ; un petit répit avant la première vague
        sta etat
        lda #60
        sta pause_cpt
        jsr charger_vague
        jsr allumer_ecran
        rts

; -----------------------------------------------------------------------------
;  charger_vague — lit la table de la vague courante : PAS d'écran à toucher,
;  les ennemis sont des sprites. On peut donc changer de vague en plein vol !
; -----------------------------------------------------------------------------
charger_vague:
        lda vague_num
        and #%00000111
        tax
        lda vagues_lo, x
        sta tmp
        lda vagues_hi, x
        sta tmp2
        ldy #0                  ; l'index dans la table (3 octets par drone)
        ldx #0                  ; le numéro de drone
@drone:
        lda (tmp), y            ; le TYPE...
        sta enn_type, x
        iny
        lda (tmp), y            ; ...la colonne d'entrée...
        sta enn_x, x
        iny
        lda (tmp), y            ; ...et le délai avant d'entrer en scène
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
        jsr dessiner_ecran_titre
        lda #0
        sta defil_y
        sta defil_nt
        ldx #7                  ; on nettoie le ciel des derniers drones
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
        ; le ciel est figé au titre : le texte reste en place
        lda presses
        and #BTN_START
        beq @dessiner
        jsr demarrer_partie
        jsr bip_depart
        jmp @dessiner

@entracte:
        jsr defiler_le_ciel     ; les étoiles continuent de rouler
        jsr maj_nav             ; on peut déjà manœuvrer...
        jsr maj_tirs            ; ...et les tirs finissent leur course
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
        lda ennemis_restants    ; vague nettoyée ?
        bne @dessiner
        inc vague_num
        lda vague_num
        cmp #8
        bcc @vague_suivante
        lda #0                  ; les 8 vagues sont passées : on reboucle...
        sta vague_num
        lda boucle              ; ...plus vite (plafonné, soyons humains)
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

; Le ciel défile : UN octet à décrémenter... et quand il repasse sous zéro,
; on saute à l'autre écran de la pile. 480 pixels de boucle sans couture.
defiler_le_ciel:
        lda defil_y
        bne @descendre
        lda defil_nt            ; on était tout en haut de cet écran :
        eor #1                  ; on bascule sur l'autre...
        sta defil_nt
        lda #240                ; ...par le bas
@descendre:
        sec
        sbc #1
        sta defil_y
        rts


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
        eor #$FF
        and boutons
        sta presses
        rts


; =============================================================================
;  maj_nav — piloter, tirer, encaisser
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

        lda nav_inv             ; l'invincibilité fond d'une image par image
        beq @vulnerable
        dec nav_inv
@vulnerable:

        lda tir_cd              ; le canon recharge...
        beq @charge
        dec tir_cd
        rts
@charge:
        lda boutons             ; ...et A maintenu = tir automatique !
        and #BTN_A
        beq @fin
        ; chercher un tir libre dans le réservoir
        ldx #2
@chercher:
        lda tir_actif, x
        beq @tirer
        dex
        bpl @chercher
        rts                     ; les 3 tirs sont déjà en l'air
@tirer:
        lda #1
        sta tir_actif, x
        lda nav_x
        clc
        adc #4                  ; le canon est au centre du vaisseau
        sta tir_x, x
        lda #NAV_Y - 8
        sta tir_y, x
        lda #12                 ; 12 images de recharge : 5 tirs/seconde
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
        sbc #4                  ; 4 pixels par image, plein ciel
        sta tir_y, x
        cmp #12
        bcs @suivant
        lda #0                  ; sorti par le haut
        sta tir_actif, x
@suivant:
        dex
        bpl @tir
        rts


; =============================================================================
;  maj_ennemis — délais d'entrée, vol, zigzag, explosions, et le contact
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

@patiente:
        dec enn_delai, x        ; son heure approche...
        bne @suivant
        lda #ENN_VOL
        sta enn_etat, x
        jmp @suivant

@explose:
        dec enn_delai, x        ; le feu d'artifice est bref
        bne @suivant
        lda #ENN_MORT
        sta enn_etat, x
        jmp @suivant

@vole:
        lda enn_y, x            ; descendre (de plus en plus vite au fil
        clc                     ; des boucles !)
        adc chute
        sta enn_y, x
        cmp #237
        bcc @dans_le_ciel
        lda #ENN_MORT           ; passé sous l'écran : envolé
        sta enn_etat, x
        dec ennemis_restants
        jmp @suivant
@dans_le_ciel:
        lda enn_type, x         ; type 1 : le zigzag
        beq @contact
        lda enn_x, x
        clc
        adc enn_dx, x
        sta enn_x, x
        cmp #9                  ; rebond sur les bords de l'écran
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
        ; --- percute-t-il le vaisseau ? ------------------------------------------
        lda nav_inv
        bne @suivant            ; intouchable : le drone passe au travers
        lda enn_y, x            ; à hauteur du vaisseau ? (y dans 193-207)
        cmp #NAV_Y - 7
        bcc @suivant
        cmp #NAV_Y + 8
        bcs @suivant
        lda enn_x, x            ; recouvrement : drone 8 px, vaisseau 16 px
        sec
        sbc nav_x
        clc
        adc #7
        cmp #24
        bcs @suivant
        ; --- touché ! -----------------------------------------------------------
        lda #ENN_EXPLOSE        ; le drone y reste aussi
        sta enn_etat, x
        lda #12
        sta enn_delai, x
        dec ennemis_restants
        lda #90                 ; une seconde et demie d'invincibilité
        sta nav_inv
        jsr bruit_touche
        dec vies
        bne @suivant
        ; plus de vies : GAME OVER
        lda #ETAT_FINI
        sta etat
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
        ldx #2                  ; X parcourt les tirs...
@tir:
        lda tir_actif, x
        bne @tir_reel
        jmp @tir_suivant
@tir_reel:
        ldy #7                  ; ...et Y les drones. Deux index, deux
@drone:                         ; registres : ils sont faits pour ça.
        lda enn_etat, y
        cmp #ENN_VOL
        bne @drone_suivant
        lda tir_y, x            ; recouvrement vertical ?
        sec
        sbc enn_y, y
        clc
        adc #7
        cmp #15
        bcs @drone_suivant
        lda tir_x, x            ; recouvrement horizontal ?
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
        inc score_d             ; +10 points
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
        jmp @tir_suivant        ; ce tir est consommé : au suivant
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
;  LE SON (le moteur du casse-brique, partition spatiale)
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
        lda #%01110100          ; onde carrée 25 % cette fois : plus fine,
        sta CARRE2_VOL          ; plus "spatiale" — le timbre, c'est le duty !
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
        .byte NOTE_LA4,  12, NOTE_MI5, 12, NOTE_DO5,  12, NOTE_MI5, 12
        .byte NOTE_LA4,  12, NOTE_MI5, 12, NOTE_DO5,  12, NOTE_MI5, 12
        .byte NOTE_FA4,  12, NOTE_DO5, 12, NOTE_LA4,  12, NOTE_DO5, 12
        .byte NOTE_SOL4, 12, NOTE_RE5, 12, NOTE_SI4,  12, NOTE_RE5, 12
        .byte $FF
basse:
        .byte NOTE_LA2, 48, NOTE_LA2, 48, NOTE_FA2, 48, NOTE_SOL2, 48
        .byte $FF

notes_bas:  .byte $00, $00, $74, $F8, $56, $3F, $1C, $FD, $E1, $D5, $BD, $A9, $9F, $8E, $7E
notes_haut: .byte $00, $05, $04, $03, $03, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00

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

bip_depart:
        lda #$FD
        ldx #$00
        ldy #4
        jmp jouer_bip
bip_tir:                        ; pew ! très bref, très aigu
        lda #$54
        ldx #$00
        ldy #2
        jmp jouer_bip
bip_vague:                      ; la vague suivante arrive
        lda #$7E
        ldx #$00
        ldy #8
        jmp jouer_bip
bruit_explosion:
        lda #$06
        ldy #10
        jmp jouer_bruit
bruit_touche:                   ; ça, c'était notre coque
        lda #$0A
        ldy #25
        jmp jouer_bruit
bruit_fin:
        lda #$0C
        ldy #45
        jmp jouer_bruit


; =============================================================================
;  maj_sprites — vaisseau, tirs, drones, HUD, GAME OVER... tout est sprite !
; =============================================================================
maj_sprites:
        ; --- le vaisseau (2 sprites), qui clignote s'il est invincible -----------
        lda etat
        cmp #ETAT_FINI
        beq @cacher_nav         ; au game over, l'épave a coulé
        lda nav_inv
        beq @nav_visible
        lda image
        and #%00000100          ; le clignotement des "i-frames"
        beq @nav_visible
@cacher_nav:
        lda #$F0
        sta $0200
        sta $0204
        jmp @tirs
@nav_visible:
        lda #NAV_Y
        sta $0200
        sta $0204
        lda #TUILE_NAV_G
        sta $0201
        lda #TUILE_NAV_D
        sta $0205
        lda #0
        sta $0202
        sta $0206
        lda nav_x
        sta $0203
        clc
        adc #8
        sta $0207

@tirs:
        ldx #2
@un_tir:
        txa                     ; sprite 2+X → adresse OAM 8 + X×4
        asl a
        asl a
        clc
        adc #8
        tay
        lda tir_actif, x
        beq @cacher_tir
        lda tir_y, x
        sta $0200, y
        lda #TUILE_TIR
        sta $0201, y
        lda #0
        sta $0202, y
        lda tir_x, x
        sta $0203, y
        jmp @tir_suivant
@cacher_tir:
        lda #$F0
        sta $0200, y
@tir_suivant:
        dex
        bpl @un_tir

        ; --- les 8 drones -----------------------------------------------------------
        ldx #7
@un_drone:
        txa                     ; sprite 5+X → adresse OAM 20 + X×4
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
        lda #$F0                ; mort ou pas encore là : en coulisses
        sta $0200, y
        jmp @drone_suivant
@drone_explose:
        lda enn_y, x
        sta $0200, y
        lda #TUILE_EXPLOSION
        sta $0201, y
        lda #2                  ; palette or/rouge
        sta $0202, y
        lda enn_x, x
        sta $0203, y
        jmp @drone_suivant
@drone_visible:
        lda enn_y, x
        sta $0200, y
        lda image
        and #%00000100          ; les rotors tournent
        beq @rotor_1
        lda #TUILE_DRONE_2
        bne @rotor_ok
@rotor_1:
        lda #TUILE_DRONE_1
@rotor_ok:
        sta $0201, y
        lda #1
        sta $0202, y
        lda enn_x, x
        sta $0203, y
@drone_suivant:
        dex
        bpl @un_drone

        ; --- le HUD : 3 chiffres de score + les vies (sprites 13-16) ----------------
        lda #16
        sta $0234
        sta $0238
        sta $023C
        sta $0240
        lda score_c
        clc
        adc #TUILE_CHIFFRE_0
        sta $0235
        lda score_d
        clc
        adc #TUILE_CHIFFRE_0
        sta $0239
        lda score_u
        clc
        adc #TUILE_CHIFFRE_0
        sta $023D
        lda vies
        clc
        adc #TUILE_CHIFFRE_0
        sta $0241
        lda #3                  ; palette blanche
        sta $0236
        sta $023A
        sta $023E
        sta $0242
        lda #16
        sta $0237
        lda #24
        sta $023B
        lda #32
        sta $023F
        lda #232
        sta $0243

        ; --- "GAME OVER", en sprites (le décor défile, pas eux !) --------------------
        ldx #8
@lettre:
        txa
        asl a
        asl a
        clc
        adc #$44                ; sprites 17-25 : OAM $0244 + X×4
        tay
        lda etat
        cmp #ETAT_FINI
        bne @cacher_lettre
        lda texte_gameover, x
        beq @cacher_lettre      ; l'espace : pas de sprite
        sta $0201, y
        lda #112
        sta $0200, y
        lda #3
        sta $0202, y
        txa
        asl a
        asl a
        asl a                   ; x = 92 + lettre × 8
        clc
        adc #92
        sta $0203, y
        jmp @lettre_suivante
@cacher_lettre:
        lda #$F0
        sta $0200, y
@lettre_suivante:
        dex
        bpl @lettre
        rts

texte_gameover:
        .byte L_G, L_A, L_M, L_E, ESPACE, L_O, L_V, L_E, L_R


; =============================================================================
;  NMI — la plus courte des trois jeux : DMA, défilement, et c'est tout !
; =============================================================================
;  Ce jeu ne modifie JAMAIS le décor en cours de partie : les étoiles sont
;  semées une fois, et tout le reste est sprite. Le VBlank est donc presque
;  vide — puissance du choix de conception. Comparez avec la nmi du runner !

nmi:
        pha
        txa
        pha
        tya
        pha

        lda #$00
        sta OAMADDR
        lda #$02
        sta OAMDMA

        bit PPUSTATUS
        lda #0
        sta PPUSCROLL           ; horizontal : jamais
        lda defil_y
        sta PPUSCROLL           ; vertical : les étoiles descendent
        lda defil_nt
        asl a                   ; bit 1 de PPUCTRL = nametable du haut/bas
        ora #%10000000
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
;  LES VAGUES — 8 tables de 8 drones : (type, colonne, délai d'entrée)
; =============================================================================
;  type 0 = plonge tout droit ; type 1 = zigzague. Le délai est en images :
;  0 = part immédiatement, 60 = une seconde plus tard. Composez les vôtres !

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
;  LES VECTEURS
; =============================================================================
.segment "VECTORS"
        .word nmi, reset, irq


; =============================================================================
;  LES GRAPHISMES
; =============================================================================
.macro TUILE_BLANCHE l0, l1, l2, l3, l4, l5, l6, l7
        .byte l0, l1, l2, l3, l4, l5, l6, l7
        .byte l0, l1, l2, l3, l4, l5, l6, l7
.endmacro

.segment "CHR"

; --- $00 : le vide spatial ------------------------------------------------------
        .res 16

; --- $01 : petite étoile (couleur 1, un pixel qui scintille presque) --------------
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00011000
        .byte %00011000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .res 8

; --- $02 : étoile brillante (couleur 3) --------------------------------------------
        TUILE_BLANCHE %00000000, %00010000, %00010000, %01111100, %00010000, %00010000, %00000000, %00000000

; --- $03/$04 : l'intercepteur NOVA (blanc, verrière cyan, réacteurs rouges) --------
        .byte %00000001         ; plan 0 : la carlingue (gauche)
        .byte %00000011
        .byte %00000111
        .byte %00001111
        .byte %00111111
        .byte %11111111
        .byte %11110111
        .byte %11000001
        .byte %00000000         ; plan 1 : verrière + réacteur
        .byte %00000010
        .byte %00000110
        .byte %00000110
        .byte %00000000
        .byte %00000000
        .byte %00001000
        .byte %00011000
        .byte %10000000         ; plan 0 : la carlingue (droite)
        .byte %11000000
        .byte %11100000
        .byte %11110000
        .byte %11111100
        .byte %11111111
        .byte %11101111
        .byte %10000011
        .byte %00000000         ; plan 1
        .byte %01000000
        .byte %01100000
        .byte %01100000
        .byte %00000000
        .byte %00000000
        .byte %00010000
        .byte %00011000

; --- $05 : le tir (couleur 1, un trait) ----------------------------------------------
        .byte %00010000
        .byte %00111000
        .byte %00111000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00000000
        .byte %00000000
        .res 8

; --- $06/$07 : le drone ennemi, 2 phases de rotors ------------------------------------
        .byte %01100110         ; plan 0, phase 1
        .byte %11111111
        .byte %01111110
        .byte %01100110
        .byte %01111110
        .byte %00111100
        .byte %00000000
        .byte %00000000
        .byte %00000000         ; plan 1 : l'œil
        .byte %00000000
        .byte %00000000
        .byte %00011000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %10011001         ; plan 0, phase 2
        .byte %11111111
        .byte %01111110
        .byte %01100110
        .byte %01111110
        .byte %00111100
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00011000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000

; --- $08 : l'explosion (couleurs mêlées : ça pète dans tous les sens) ------------------
        .byte %10010010         ; plan 0
        .byte %01000101
        .byte %00111100
        .byte %01111010
        .byte %01011110
        .byte %00111100
        .byte %10100010
        .byte %01001001
        .byte %00100100         ; plan 1
        .byte %00011000
        .byte %01011010
        .byte %00100110
        .byte %01100100
        .byte %01011010
        .byte %00011000
        .byte %00100100

; --- on saute jusqu'aux chiffres ($09-$0F libres) ---------------------------------------
        .res 7 * 16

; --- $10-$19 : les chiffres --------------------------------------------------------------
        TUILE_BLANCHE %01111100, %11000110, %11001110, %11010110, %11100110, %11000110, %01111100, %00000000
        TUILE_BLANCHE %00110000, %01110000, %00110000, %00110000, %00110000, %00110000, %11111100, %00000000
        TUILE_BLANCHE %01111000, %11001100, %00001100, %00111000, %01100000, %11001100, %11111100, %00000000
        TUILE_BLANCHE %01111000, %11001100, %00001100, %00111000, %00001100, %11001100, %01111000, %00000000
        TUILE_BLANCHE %00011100, %00111100, %01101100, %11001100, %11111110, %00001100, %00011110, %00000000
        TUILE_BLANCHE %11111100, %11000000, %11111000, %00001100, %00001100, %11001100, %01111000, %00000000
        TUILE_BLANCHE %00111000, %01100000, %11000000, %11111000, %11001100, %11001100, %01111000, %00000000
        TUILE_BLANCHE %11111100, %11001100, %00001100, %00011000, %00110000, %00110000, %00110000, %00000000
        TUILE_BLANCHE %01111000, %11001100, %11001100, %01111000, %11001100, %11001100, %01111000, %00000000
        TUILE_BLANCHE %01111000, %11001100, %11001100, %01111100, %00001100, %00011000, %01110000, %00000000

; --- $1A libre, $1B : le tiret --------------------------------------------------------------
        .res 16
        TUILE_BLANCHE %00000000, %00000000, %00000000, %01111110, %00000000, %00000000, %00000000, %00000000

; --- on saute jusqu'à $20 : l'alphabet (15 lettres) -------------------------------------------
        .res 4 * 16
        TUILE_BLANCHE %00110000, %01111000, %11001100, %11001100, %11111100, %11001100, %11001100, %00000000  ; A
        TUILE_BLANCHE %00111100, %01100110, %11000000, %11000000, %11000000, %01100110, %00111100, %00000000  ; C
        TUILE_BLANCHE %11111000, %01101100, %01100110, %01100110, %01100110, %01101100, %11111000, %00000000  ; D
        TUILE_BLANCHE %11111110, %01100010, %01101000, %01111000, %01101000, %01100010, %11111110, %00000000  ; E
        TUILE_BLANCHE %00111100, %01100110, %11000000, %11001110, %11000110, %01100110, %00111110, %00000000  ; G
        TUILE_BLANCHE %01111000, %00110000, %00110000, %00110000, %00110000, %00110000, %01111000, %00000000  ; I
        TUILE_BLANCHE %11000110, %11101110, %11111110, %11010110, %11000110, %11000110, %11000110, %00000000  ; M
        TUILE_BLANCHE %11000110, %11100110, %11110110, %11011110, %11001110, %11000110, %11000110, %00000000  ; N
        TUILE_BLANCHE %00111000, %01101100, %11000110, %11000110, %11000110, %01101100, %00111000, %00000000  ; O
        TUILE_BLANCHE %11111100, %01100110, %01100110, %01111100, %01100000, %01100000, %11110000, %00000000  ; P
        TUILE_BLANCHE %11111100, %01100110, %01100110, %01111100, %01101100, %01100110, %11100110, %00000000  ; R
        TUILE_BLANCHE %01111000, %11001100, %11100000, %01110000, %00011100, %11001100, %01111000, %00000000  ; S
        TUILE_BLANCHE %11111100, %10110100, %00110000, %00110000, %00110000, %00110000, %01111000, %00000000  ; T
        TUILE_BLANCHE %11001100, %11001100, %11001100, %11001100, %11001100, %11001100, %01111100, %00000000  ; U
        TUILE_BLANCHE %11001100, %11001100, %11001100, %11001100, %11001100, %01111000, %00110000, %00000000  ; V

; Fin — trois jeux, trois architectures : à vous d'inventer le quatrième !
