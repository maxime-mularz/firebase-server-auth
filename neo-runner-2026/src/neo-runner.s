; =============================================================================
;  NÉO-RUNNER 2026 — un jeu de plateforme NES en assembleur 6502
; =============================================================================
;
;  Nous sommes en 2026. Vous êtes R-2026, un petit robot livreur qui court
;  sur les toits d'une ville couverte de néons. Ramassez les puces de
;  données, écrasez (ou évitez !) les drones de livraison concurrents, et
;  rejoignez l'antenne-relais au bout du niveau.
;
;  Commandes : ←/→ courir · A sauter · Start commencer/rejouer
;  Sauter sur un drone le détruit ; le toucher de côté coûte une vie.
;
;  CE FICHIER EST LE "NIVEAU 2" DU COURS D'ASSEMBLEUR.
;  ---------------------------------------------------
;  Le casse-brique (../casse-brique-nes/) expliquait les bases : registres
;  A/X/Y, drapeaux, LDA/STA, la différence #valeur / adresse, le PPU, la
;  NMI... On ne ré-explique pas tout ici. Ce jeu introduit les techniques
;  d'un vrai jeu de plateforme à défilement :
;
;   1. LE DÉFILEMENT (scrolling). Le niveau fait 1024 pixels de large, mais
;      l'écran n'en montre que 256. Une "caméra" suit le joueur, et on
;      dessine les colonnes de décor juste avant qu'elles n'entrent à
;      l'écran — pendant que le jeu tourne ! (Comme Super Mario Bros.,
;      la caméra ne recule jamais.)
;
;   2. LES NOMBRES DE 16 BITS. Un octet s'arrête à 255, mais nos positions
;      vont jusqu'à 1023. On colle donc DEUX octets ensemble (bas + haut)
;      et on propage la retenue à la main. Le 6502 est une calculatrice
;      8 bits : les grands nombres, c'est nous qui les fabriquons.
;
;   3. LA VIRGULE FIXE. Une gravité de "0,25 pixel par image" ne tient pas
;      dans des entiers... alors on compte en 256e de pixel ! La vitesse
;      verticale occupe 2 octets : vy_hi = les pixels entiers, vy_lo = les
;      256e. $0040 = 0,25 ; $0400 = 4,0 ; $FA80 = −5,5. C'est la "virgule
;      fixe 8.8", le secret des sauts fluides sur 8 bits.
;
;   4. LES MÉTATUILES. Le niveau n'est pas stocké tuile par tuile mais en
;      blocs de 16×16 pixels (= 2×2 tuiles) : béton, plateforme néon,
;      puce, antenne... La carte entière tient en 1 Ko et se lit d'un coup
;      d'œil dans le code source (cherchez "LE NIVEAU" plus bas).
;
;  Le rythme reste le même qu'au casse-brique : la boucle principale
;  CALCULE, la routine nmi AFFICHE, 60 fois par seconde.
; =============================================================================


; -----------------------------------------------------------------------------
;  CONSTANTES matérielles (voir le casse-brique pour le détail)
; -----------------------------------------------------------------------------
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014
JOYPAD1   = $4016
APUFRAME  = $4017

BTN_A      = %10000000
BTN_B      = %01000000
BTN_SELECT = %00100000
BTN_START  = %00010000
BTN_HAUT   = %00001000
BTN_BAS    = %00000100
BTN_GAUCHE = %00000010
BTN_DROITE = %00000001

; --- Les tuiles (dessinées dans le segment CHR, tout en bas) ------------------
TUILE_VIDE       = $00
TUILE_BLOC       = $01   ; béton d'immeuble, fenêtres allumées
TUILE_NEON       = $02   ; bord néon des toits et plateformes
TUILE_ROBOT_HAUT = $08
TUILE_ROBOT_BAS  = $09
TUILE_DRONE      = $0A
TUILE_CHIFFRE_0  = $10

; --- Les types de métatuiles (les "blocs" de 16×16 dont est fait le niveau) ---
TYPE_VIDE    = 0
TYPE_BLOC    = 1   ; solide
TYPE_NEON    = 2   ; solide (dessus de toit/plateforme)
TYPE_PUCE    = 3   ; à ramasser !
TYPE_ANTENNE = 4   ; décor (haut de l'antenne d'arrivée)
TYPE_MAT     = 5   ; décor (mât de l'antenne)

; --- Les états du jeu ----------------------------------------------------------
ETAT_TITRE = 0     ; on attend Start (le robot clignote)
ETAT_JEU   = 1
ETAT_PERDU = 2
ETAT_GAGNE = 3

; --- Physique (en virgule fixe 8.8 : 256 = un pixel) ---------------------------
GRAVITE    = $40       ; +0,25 pixel/image² — ce qui nous tire vers le bas
SAUT_LO    = $80       ; vitesse initiale du saut : $FA80 = −5,5 pixels/image
SAUT_HI    = $FA
CHUTE_MAX  = 4         ; vitesse de chute maximale : 4 pixels/image

; --- Géométrie ------------------------------------------------------------------
NIVEAU_COLONNES = 64   ; le niveau fait 64 métatuiles (1024 pixels) de large
CAMERA_MAX_HI   = $03  ; la caméra s'arrête à 768 ($0300) : 1024 − 256
BUT_LO          = $C0  ; l'antenne est à x = 960 ($03C0) : la toucher = gagné
BUT_HI          = $03


; -----------------------------------------------------------------------------
;  VARIABLES en page zéro
; -----------------------------------------------------------------------------
.zeropage

boutons:       .res 1
anciens:       .res 1   ; boutons de l'image précédente...
presses:       .res 1   ; ...pour détecter les boutons qui VIENNENT d'être
                        ; pressés (sinon, tenir A ferait sauter en boucle)
image:         .res 1
etat:          .res 1

; Le joueur. Sa position X est un nombre de 16 BITS (0 à 1023) : deux octets,
; le bas et le haut, que l'on additionne toujours en propageant la retenue.
joueur_x_lo:   .res 1
joueur_x_hi:   .res 1
joueur_y:      .res 1   ; Y tient sur 8 bits (l'écran fait 240 pixels de haut)
joueur_ysub:   .res 1   ; les 256e de pixel de Y (virgule fixe !)
vy_lo:         .res 1   ; vitesse verticale en 8.8 : vy_hi,vy_lo
vy_hi:         .res 1   ; ($FA80 = −5,5 : le saut ; ça augmente de $0040/image)
au_sol:        .res 1   ; 1 = les pieds touchent le sol (on peut sauter)
regard:        .res 1   ; 0 = regarde à droite, 1 = à gauche (miroir du sprite)

camera_lo:     .res 1   ; position de la caméra dans le niveau (16 bits)
camera_hi:     .res 1
prochaine_col: .res 1   ; prochaine colonne de décor à dessiner (32..64)

vies:          .res 1
score_c:       .res 1   ; centaines et dizaines (une puce = 10 points,
score_d:       .res 1   ; les unités affichent toujours 0)

; File d'attente : une colonne de décor à écrire au prochain VBlank
col_actif:     .res 1
col_adr_hi:    .res 1
col_adr_lo:    .res 1

; File d'attente : une puce ramassée à effacer au prochain VBlank
puce_actif:    .res 1
puce_adr_hi:   .res 1
puce_adr_lo:   .res 1

; La "sonde" : le point (x, y) du monde que l'on veut examiner
sonde_x_lo:    .res 1
sonde_x_hi:    .res 1
sonde_y:       .res 1

carte_ptr:     .res 2   ; pointeur (16 bits) vers une case de la carte en RAM
src_ptr:       .res 2   ; pointeurs de copie ROM → RAM
dst_ptr:       .res 2

rang_tmp:      .res 1
meta_tmp:      .res 1
tmp_lo:        .res 1
tmp_hi:        .res 1
compteur:      .res 1

; Les 3 drones : de vrais petits tableaux ! drone_x_lo+X = le drone n° X.
drone_x_lo:    .res 3
drone_x_hi:    .res 3
drone_y:       .res 3
drone_dir:     .res 3   ; +1 ou $FF (−1)
drone_actif:   .res 3   ; 0 = détruit


; -----------------------------------------------------------------------------
;  VARIABLES en RAM ordinaire
; -----------------------------------------------------------------------------
;  `carte` DOIT être la première : elle est alors pile à l'adresse $0300, et
;  la case (colonne, rangée) se trouve à l'adresse $0300 + colonne×16 + rangée.
;  Ce choix rend le calcul d'adresse presque gratuit (voir type_carte).

.bss

carte:          .res 1024  ; 64 colonnes × 16 (15 rangées + 1 de bourrage)
tampon_colonne: .res 60    ; les 60 tuiles d'une colonne de décor à écrire


; =============================================================================
;  EN-TÊTE iNES
; =============================================================================
.segment "HEADER"
        .byte 'N', 'E', 'S', $1A
        .byte 2                    ; 2 × 16 Ko de code
        .byte 1                    ; 8 Ko de graphismes
        .byte $01                  ; miroir VERTICAL : indispensable ici ! Il
        .byte $00                  ; place les 2 écrans internes CÔTE À CÔTE,
        .byte 0,0,0,0,0,0,0,0      ; ce qui permet le défilement horizontal.


.segment "CODE"

; =============================================================================
;  RESET — le rituel d'initialisation (détaillé dans le casse-brique)
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
        sta $0200, x            ; sprites hors écran
        lda #0
        inx
        bne @vider_ram
@attente_vblank_2:
        bit PPUSTATUS
        bpl @attente_vblank_2

        jsr charger_palettes

        lda #3
        sta vies
        lda #0
        sta score_c
        sta score_d
        sta image
        lda #ETAT_TITRE
        sta etat

        jsr charger_niveau      ; copie la carte et dessine les 2 premiers écrans
        jsr allumer_ecran
        jmp principale


; -----------------------------------------------------------------------------
;  charger_palettes
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
        ; --- fond ---
        .byte $0F, $00, $2C, $28   ; nuit, béton gris, néon cyan, or des puces
        .byte $0F, $0F, $0F, $0F
        .byte $0F, $0F, $0F, $0F
        .byte $0F, $0F, $0F, $0F
        ; --- sprites ---
        .byte $0F, $30, $16, $0F   ; palette 0 : robot blanc, visière rouge
        .byte $0F, $2C, $15, $0F   ; palette 1 : drone cyan, œil rouge
        .byte $0F, $00, $00, $30   ; palette 2 : chiffres du score (blanc)
        .byte $0F, $0F, $0F, $0F


; =============================================================================
;  charger_niveau — (re)prépare tout un niveau. À appeler ÉCRAN ÉTEINT !
; =============================================================================
;  1. copie la carte du niveau de la ROM vers la RAM (pour pouvoir y effacer
;     les puces ramassées) ;
;  2. dessine les 2 premiers écrans dans les 2 nametables ;
;  3. replace le joueur, la caméra et les drones au départ.

charger_niveau:
        ; --- 1) Copier la carte : 64 colonnes de 15 cases (+1 de bourrage) ---
        lda #<niveau            ; <  et  >  extraient l'octet bas et l'octet
        sta src_ptr             ; haut d'une adresse : c'est ainsi qu'on met
        lda #>niveau            ; une adresse de 16 bits dans deux octets.
        sta src_ptr+1
        lda #$00
        sta dst_ptr
        lda #$03                ; destination : $0300 (le tableau `carte`)
        sta dst_ptr+1
        ldx #NIVEAU_COLONNES
@colonne:
        ldy #0
@copie:
        lda (src_ptr), y        ; "(pointeur), y" : lit à l'adresse contenue
        sta (dst_ptr), y        ; dans le pointeur, plus Y. C'est LE mode
        iny                     ; d'adressage à tout faire du 6502.
        cpy #15
        bne @copie
        lda #0
        sta (dst_ptr), y        ; la 16e case (bourrage) reste vide
        lda src_ptr             ; source += 15 (sur 16 bits)
        clc
        adc #15
        sta src_ptr
        bcc @src_ok
        inc src_ptr+1           ; la retenue déborde dans l'octet haut
@src_ok:
        lda dst_ptr             ; destination += 16
        clc
        adc #16
        sta dst_ptr
        bcc @dst_ok
        inc dst_ptr+1
@dst_ok:
        dex
        bne @colonne

        ; --- 2) Dessiner les 32 premières colonnes (écrans 1 et 2) ----------
        lda #0
        sta compteur
@dessiner:
        lda compteur
        jsr construire_colonne
        jsr ecrire_colonne
        inc compteur
        lda compteur
        cmp #32
        bne @dessiner

        ; --- 3) Tout le monde au départ --------------------------------------
        lda #0
        sta camera_lo
        sta camera_hi
        sta col_actif
        sta puce_actif
        sta vy_lo
        sta vy_hi
        sta joueur_ysub
        sta au_sol
        sta regard
        sta joueur_x_hi
        lda #32                 ; le joueur à x=32...
        sta joueur_x_lo
        sta prochaine_col       ; ...et 32 colonnes déjà dessinées
        lda #192                ; debout sur le sol (les pieds à 192+16=208)
        sta joueur_y

        ldx #2                  ; les 3 drones : X = 2, puis 1, puis 0
@drone:
        lda drones_debut_lo, x
        sta drone_x_lo, x
        lda drones_debut_hi, x
        sta drone_x_hi, x
        lda #200                ; tous volent au ras du sol
        sta drone_y, x
        lda #1
        sta drone_dir, x
        sta drone_actif, x
        dex
        bpl @drone
        rts

; Position de départ de chaque drone dans le niveau (16 bits, donc 2 tables)
drones_debut_lo: .byte $A0, $C0, $A0   ; 160, 448, 672
drones_debut_hi: .byte $00, $01, $02
; Bornes de leur va-et-vient
drones_min_lo:   .byte $A0, $C0, $A0   ; 160, 448, 672
drones_min_hi:   .byte $00, $01, $02
drones_max_lo:   .byte $E8, $28, $E8   ; 232, 552, 744
drones_max_hi:   .byte $00, $02, $02


; -----------------------------------------------------------------------------
;  allumer_ecran : attend un VBlank, règle le défilement, allume l'affichage
; -----------------------------------------------------------------------------
allumer_ecran:
        bit PPUSTATUS
@attendre:
        bit PPUSTATUS
        bpl @attendre
        lda camera_lo
        sta PPUSCROLL
        lda #0
        sta PPUSCROLL
        lda camera_hi
        and #1
        ora #%10000000          ; NMI activée + nametable de départ
        sta PPUCTRL
        lda #%00011110
        sta PPUMASK
        rts


; =============================================================================
;  construire_colonne — fabrique en RAM les 60 tuiles d'une colonne de décor
; =============================================================================
;  Entrée : A = numéro de métacolonne (0 à 63).
;
;  Une métacolonne = 15 métatuiles de 16×16 = 2 colonnes de 30 tuiles de 8×8.
;  On remplit `tampon_colonne` : les octets 0-29 sont la colonne de tuiles de
;  gauche (de haut en bas), les octets 30-59 celle de droite. On calcule
;  aussi l'adresse vidéo où tout cela devra être écrit.
;
;  Où, justement ? Les métacolonnes 0-15 vont dans la nametable A ($2000),
;  les 16-31 dans la B ($2400), puis A de nouveau, etc. : le niveau s'enroule
;  sur les deux écrans comme un tapis roulant.

construire_colonne:
        sta meta_tmp

        ; --- adresse vidéo de la colonne -------------------------------------
        ldx #$20                ; nametable A...
        lda meta_tmp
        and #%00010000          ; ...sauf si le bit 4 du numéro est allumé
        beq @nametable_ok       ;    (colonnes 16-31, 48-63)
        ldx #$24                ; → nametable B
@nametable_ok:
        stx col_adr_hi
        lda meta_tmp
        and #%00001111          ; position dans l'écran (0-15)...
        asl a                   ; ...×2 tuiles par métatuile
        sta col_adr_lo

        ; --- pointeur vers la colonne dans la carte ---------------------------
        ;  adresse = $0300 + colonne × 16. Or colonne×16, c'est juste ses bits
        ;  décalés : l'octet haut reçoit colonne÷16, l'octet bas colonne×16 !
        lda meta_tmp
        lsr a
        lsr a
        lsr a
        lsr a
        clc
        adc #$03
        sta carte_ptr+1
        lda meta_tmp
        asl a
        asl a
        asl a
        asl a
        sta carte_ptr

        ; --- traduire les 15 métatuiles en 60 tuiles --------------------------
        ldy #0                  ; Y = rangée (0-14)
@rangee:
        sty rang_tmp
        lda (carte_ptr), y      ; le TYPE de la métatuile
        tax                     ; → X, pour indexer les tables de tuiles
        lda rang_tmp
        asl a
        tay                     ; Y = rangée × 2 = position dans le tampon
        lda metatuile_hg, x     ; les 4 coins de la métatuile :
        sta tampon_colonne, y   ;   haut-gauche
        lda metatuile_bg, x
        sta tampon_colonne+1, y ;   bas-gauche
        lda metatuile_hd, x
        sta tampon_colonne+30, y ;  haut-droit
        lda metatuile_bd, x
        sta tampon_colonne+31, y ;  bas-droit
        ldy rang_tmp
        iny
        cpy #15
        bne @rangee
        rts

; L'apparence de chaque type de métatuile : ses 4 tuiles de 8×8.
;                 vide   bloc        néon        puce  antenne mât
metatuile_hg: .byte $00, TUILE_BLOC, TUILE_NEON, $04,  $0B,    $0D
metatuile_hd: .byte $00, TUILE_BLOC, TUILE_NEON, $05,  $0C,    $0E
metatuile_bg: .byte $00, TUILE_BLOC, TUILE_BLOC, $06,  $0D,    $0D
metatuile_bd: .byte $00, TUILE_BLOC, TUILE_BLOC, $07,  $0E,    $0E

; Quels types sont SOLIDES (arrêtent le joueur) ?
table_solide: .byte 0, 1, 1, 0, 0, 0


; -----------------------------------------------------------------------------
;  ecrire_colonne — envoie le tampon vers la mémoire vidéo
; -----------------------------------------------------------------------------
;  L'astuce du jour : le bit 2 de PPUCTRL. À 1, chaque écriture dans PPUDATA
;  avance de 32 cases au lieu d'une — c'est-à-dire d'UNE LIGNE VERS LE BAS.
;  Écrire une colonne verticale devient aussi simple qu'une ligne !
;  (Appelée écran éteint au chargement, ou pendant le VBlank par la nmi.)

ecrire_colonne:
        lda #%00000100          ; mode "descendre d'une ligne"
        sta PPUCTRL
        bit PPUSTATUS
        lda col_adr_hi
        sta PPUADDR
        lda col_adr_lo
        sta PPUADDR
        ldx #0
@gauche:
        lda tampon_colonne, x
        sta PPUDATA
        inx
        cpx #30
        bne @gauche
        lda col_adr_hi          ; seconde colonne de tuiles, une case à droite
        sta PPUADDR
        lda col_adr_lo
        clc
        adc #1
        sta PPUADDR
@droite:
        lda tampon_colonne, x
        sta PPUDATA
        inx
        cpx #60
        bne @droite
        rts


; =============================================================================
;  LA BOUCLE PRINCIPALE
; =============================================================================
principale:
        jsr attendre_nmi
        jsr lire_manette

        lda etat
        cmp #ETAT_JEU
        beq @en_jeu
        cmp #ETAT_TITRE
        beq @au_titre

        ; --- PERDU ou GAGNÉ : Start pour rejouer -----------------------------
        lda presses
        and #BTN_START
        beq @dessiner
        jmp reset

@au_titre:
        lda presses
        and #BTN_START
        beq @dessiner
        lda #ETAT_JEU
        sta etat
        jmp @dessiner

@en_jeu:
        jsr maj_joueur
        lda etat                ; mort ou victoire pendant la mise à jour ?
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


; -----------------------------------------------------------------------------
;  lire_manette — avec détection des boutons "qui viennent d'être pressés"
; -----------------------------------------------------------------------------
;  Nouveauté par rapport au casse-brique : on garde l'état de l'image
;  précédente, et presses = (PAS anciens) ET boutons. Un bit de `presses`
;  ne vaut 1 que l'image exacte où le bouton s'enfonce — indispensable pour
;  le saut, sinon rester appuyé sur A ferait rebondir sans fin.

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
        eor #$FF                ; inverse tous les bits : "PAS anciens"
        and boutons
        sta presses
        rts


; =============================================================================
;  maj_joueur — course, gravité, saut, collisions avec le décor
; =============================================================================
;  Le principe des collisions : APRÈS avoir bougé, on "sonde" la carte aux
;  points sensibles (les pieds, la tête, les flancs). Si la sonde tombe sur
;  une case solide, on repousse le joueur au bord de la case. La carte étant
;  rangée astucieusement en RAM, sonder = fabriquer une adresse (type_carte).

maj_joueur:
        ; ============== MOUVEMENT HORIZONTAL ==============
        lda boutons
        and #BTN_DROITE
        beq @pas_droite
        lda joueur_x_lo         ; x += 2, sur 16 bits : d'abord l'octet bas...
        clc
        adc #2
        sta joueur_x_lo
        lda joueur_x_hi         ; ...puis l'octet haut + la retenue (adc #0)
        adc #0
        sta joueur_x_hi
        lda #0
        sta regard              ; on regarde à droite

        ; sonde du flanc droit, à hauteur d'épaules puis de genoux
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
        ; on recolle le joueur au bord gauche du bloc : le bloc commence au
        ; multiple de 16 de la sonde (AND $F0 arrondit !), et le joueur fait
        ; 8 pixels de large → x = bord − 8.
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
        lda joueur_x_lo         ; x −= 2 (16 bits, l'emprunt via sbc #0)
        sec
        sbc #2
        sta joueur_x_lo
        lda joueur_x_hi
        sbc #0
        sta joueur_x_hi
        lda #1
        sta regard              ; on regarde à gauche

        lda joueur_x_lo         ; sonde du flanc gauche
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
        lda sonde_x_lo          ; on recolle au bord droit du bloc : +16
        and #$F0
        clc
        adc #16
        sta joueur_x_lo
        lda sonde_x_hi
        adc #0
        sta joueur_x_hi
@pas_gauche:

        ; --- interdit de sortir de l'écran par la gauche (la caméra ne
        ;     recule JAMAIS — exactement comme dans Super Mario Bros.) -------
        lda joueur_x_hi
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
        lda joueur_x_hi         ; ...ni de dépasser la fin du niveau
        cmp #$03
        bcc @borne_ok
        lda joueur_x_lo
        cmp #$F0
        bcc @borne_ok
        lda #$F0
        sta joueur_x_lo
@borne_ok:

        ; ============== MOUVEMENT VERTICAL ==============
        ; y += vitesse, en virgule fixe : les 256e d'abord, puis les pixels
        ; entiers — la retenue des 256e passe toute seule dans les pixels.
        lda joueur_ysub
        clc
        adc vy_lo
        sta joueur_ysub
        lda joueur_y
        adc vy_hi
        sta joueur_y

        lda vy_lo               ; la gravité tire : vitesse += 0,25
        clc
        adc #GRAVITE
        sta vy_lo
        lda vy_hi
        adc #0
        sta vy_hi

        bmi @monte              ; vitesse négative = on monte
        cmp #CHUTE_MAX          ; on tombe : plafonner la vitesse de chute
        bcc @chute_ok
        lda #CHUTE_MAX
        sta vy_hi
        lda #0
        sta vy_lo
@chute_ok:
        ; --- ON DESCEND : tombé dans un trou ? -------------------------------
        lda joueur_y
        cmp #232
        bcc @pas_tombe
        jmp mourir              ; adieu, petit robot
@pas_tombe:
        ; sondes sous les deux pieds (x+1 et x+6, à y+16)
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
        lda #0                  ; rien sous les pieds : on est en l'air
        sta au_sol
        jmp @fin_vertical
@atterrir:
        lda sonde_y             ; poser les pieds SUR la case : le haut de la
        and #$F0                ; case est son multiple de 16, et le joueur
        sec                     ; fait 16 pixels de haut
        sbc #16
        sta joueur_y
        lda #0
        sta joueur_ysub
        sta vy_lo
        sta vy_hi
        lda #1
        sta au_sol
        jmp @fin_vertical

@monte:
        lda #0
        sta au_sol
        lda joueur_y            ; sonde au-dessus de la tête (y−1)
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
        lda sonde_y             ; aïe : on repart sous la case cognée
        and #$F0
        clc
        adc #16
        sta joueur_y
        lda #0
        sta joueur_ysub
        sta vy_lo
        sta vy_hi
@fin_vertical:

        ; ============== LE SAUT ==============
        lda au_sol
        beq @pas_de_saut        ; pas de sol sous les pieds, pas de saut !
        lda presses
        and #BTN_A
        beq @pas_de_saut
        lda #SAUT_LO            ; vitesse verticale = −5,5 pixels/image :
        sta vy_lo               ; la gravité la grignotera de 0,25 par image,
        lda #SAUT_HI            ; l'apogée sera à 22 images (~60 px), puis
        sta vy_hi               ; la chute — une jolie parabole, sans sinus
        lda #0                  ; ni multiplication !
        sta au_sol
@pas_de_saut:

        ; ============== UNE PUCE ? ==============
        ; on sonde le centre du robot (x+4, y+8)
        lda joueur_x_lo
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

        ; ============== L'ANTENNE ? ==============
        lda joueur_x_hi
        cmp #BUT_HI
        bcc @fin
        lda joueur_x_lo
        cmp #BUT_LO
        bcc @fin
        lda #ETAT_GAGNE         ; livraison accomplie !
        sta etat
@fin:
        rts


; -----------------------------------------------------------------------------
;  type_carte — QUE contient le niveau au point (sonde_x, sonde_y) ?
; -----------------------------------------------------------------------------
;  Voici pourquoi la carte est rangée à $0300 par colonnes de 16 : l'adresse
;  de la case se DÉDUIT des coordonnées, sans une seule multiplication !
;     octet haut = $03 + x_haut            (chaque écran = une page de 256 o.)
;     octet bas  = (x_bas ET $F0) OU (y÷16)
;  Quatre opérations, et le pointeur est prêt. En assembleur, bien RANGER ses
;  données vaut mieux que bien calculer.

type_carte:
        lda sonde_x_hi
        clc
        adc #$03
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
        lda (carte_ptr), y      ; A = le type de métatuile à cet endroit
        rts

; est_solide : traduit un type (dans A) en 0 (traverse) ou 1 (bloque).
; Le Z-flag est positionné par le LDA final : BNE = solide, BEQ = traverse.
est_solide:
        tax
        lda table_solide, x
        rts


; -----------------------------------------------------------------------------
;  ramasser_puce — +10 points, la puce disparaît de la carte ET de l'écran
; -----------------------------------------------------------------------------
ramasser_puce:
        lda #0                  ; effacer de la carte (type_carte vient de
        tay                     ; laisser carte_ptr pile sur la bonne case)
        sta (carte_ptr), y

        inc score_d             ; +10 points, chiffre par chiffre
        lda score_d
        cmp #10
        bne @score_fait
        lda #0
        sta score_d
        inc score_c
@score_fait:

        ; --- adresse vidéo de la métatuile, pour l'effacement par la nmi ----
        ;  nametable : $20xx ou $24xx selon le bit 4 de la colonne ;
        ;  puis + rangée×64 + (colonne dans l'écran)×2.
        lda sonde_y
        lsr a
        lsr a
        lsr a
        lsr a
        sta rang_tmp            ; la rangée (0-14)

        lda sonde_x_hi
        and #1                  ; écran A ou B ?
        asl a
        asl a                   ; ×4 : $20 → $24
        sta tmp_lo
        lda rang_tmp
        lsr a
        lsr a                   ; rangée×64, octet haut = rangée÷4
        clc
        adc tmp_lo
        adc #$20
        sta puce_adr_hi

        lda sonde_x_lo
        and #$F0                ; colonne de la métatuile dans l'écran...
        lsr a
        lsr a
        lsr a                   ; ...convertie en colonne de tuile (×2/16)
        sta tmp_lo
        lda rang_tmp
        asl a
        asl a
        asl a
        asl a
        asl a
        asl a                   ; rangée×64, octet bas (déborde sans gravité)
        clc
        adc tmp_lo
        sta puce_adr_lo
        lda #1
        sta puce_actif          ; la nmi effacera au prochain VBlank
        rts


; =============================================================================
;  mourir — une vie de moins, et tout le monde au départ
; =============================================================================
mourir:
        dec vies
        bne @rejouer
        lda #ETAT_PERDU         ; plus de vies. GAME OVER, comme on disait
        sta etat                ; au siècle dernier.
        rts
@rejouer:
        lda #0                  ; on éteint TOUT (affichage et NMI) : on va
        sta PPUMASK             ; redessiner les nametables hors VBlank, ce
        sta PPUCTRL             ; qui est interdit écran allumé
        jsr charger_niveau
        jsr allumer_ecran
        rts


; =============================================================================
;  maj_camera — la caméra suit le joueur (et ne recule jamais)
; =============================================================================
maj_camera:
        lda joueur_x_lo         ; cible = joueur − 112 (le joueur reste au
        sec                     ; premier tiers de l'écran, pour voir devant)
        sbc #112
        sta tmp_lo
        lda joueur_x_hi
        sbc #0
        sta tmp_hi
        bmi @fin                ; début de niveau : cible négative, on reste

        lda tmp_hi              ; la caméra n'avance que si cible > caméra
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
        lda camera_hi           ; butée : la caméra s'arrête à 768
        cmp #CAMERA_MAX_HI
        bcc @fin
        lda camera_lo
        beq @fin
        lda #0
        sta camera_lo
        lda #CAMERA_MAX_HI
        sta camera_hi
@fin:
        rts


; -----------------------------------------------------------------------------
;  maj_defilement — prépare la prochaine colonne de décor si besoin
; -----------------------------------------------------------------------------
;  Dès que la colonne `prochaine_col` approche du bord droit de l'écran
;  (à moins de 16 pixels d'être visible), on la fabrique dans le tampon.
;  La nmi l'écrira pendant le VBlank. Une colonne par image suffit largement :
;  la caméra avance de 2 pixels/image, une colonne en fait 16.

maj_defilement:
        lda col_actif           ; le tampon précédent n'est pas encore parti ?
        bne @fin
        lda prochaine_col
        cmp #NIVEAU_COLONNES    ; tout le niveau est déjà dessiné ?
        bcs @fin

        lda camera_lo           ; seuil = caméra + 272 (un écran + une marge)
        clc
        adc #$10
        sta tmp_lo
        lda camera_hi
        adc #$01
        sta tmp_hi

        lda prochaine_col       ; position de la colonne = numéro × 16,
        lsr a                   ; c'est-à-dire... ses bits décalés, encore !
        lsr a                   ; octet haut = numéro ÷ 16
        lsr a
        lsr a
        cmp tmp_hi
        bcc @construire
        bne @fin
        lda prochaine_col
        asl a                   ; octet bas = numéro × 16
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
        sta col_actif           ; à toi de jouer, nmi !
@fin:
        rts


; =============================================================================
;  maj_drones — patrouilles et collisions
; =============================================================================
maj_drones:
        ldx #2                  ; pour chaque drone (X = 2, 1, 0)...
@drone:
        lda drone_actif, x
        bne @vivant
        jmp @suivant
@vivant:
        ; --- avancer d'un pixel dans sa direction ----------------------------
        lda drone_dir, x
        bmi @va_a_gauche
        inc drone_x_lo, x       ; +1 sur 16 bits : si l'octet bas reboucle
        bne @borne_droite       ; à zéro, incrémenter l'octet haut
        inc drone_x_hi, x
@borne_droite:
        lda drone_x_hi, x       ; comparaison 16 bits avec la borne droite :
        cmp drones_max_hi, x    ; octets hauts d'abord, octets bas ensuite
        bcc @collision
        lda drone_x_lo, x
        cmp drones_max_lo, x
        bcc @collision
        lda #$FF                ; demi-tour !
        sta drone_dir, x
        jmp @collision
@va_a_gauche:
        lda drone_x_lo, x       ; −1 sur 16 bits
        bne @dec_bas
        dec drone_x_hi, x
@dec_bas:
        dec drone_x_lo, x
        lda drone_x_hi, x
        cmp drones_min_hi, x
        bcc @demi_tour
        bne @collision
        lda drone_x_lo, x
        cmp drones_min_lo, x
        bcc @demi_tour
        beq @demi_tour
        bne @collision
@demi_tour:
        lda #1
        sta drone_dir, x

@collision:
        ; --- le drone touche-t-il le joueur ? --------------------------------
        ; écart = drone_x − joueur_x (16 bits). Contact horizontal si l'écart
        ; est entre −7 et +7 : soit haut=0 et bas≤7, soit haut=$FF et bas≥$F9
        ; (souvenez-vous : −7 s'écrit $FFF9 en complément à deux).
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
        ; contact vertical si : pieds du joueur > haut du drone
        ;                  ET   tête du joueur  < bas du drone
        lda joueur_y
        clc
        adc #16                 ; les pieds
        cmp drone_y, x
        bcc @suivant
        beq @suivant
        lda drone_y, x
        clc
        adc #8                  ; le bas du drone
        cmp joueur_y
        bcc @suivant
        beq @suivant

        ; --- CONTACT ! Écrasé ou fatal ? --------------------------------------
        ; Un vrai saut sur la tête = on descendait, et les pieds dépassent à
        ; peine le haut du drone. Tout le reste fait mal.
        lda vy_hi
        bmi @fatal              ; on montait : c'est la tête qui a tapé
        lda joueur_y
        clc
        adc #16
        sec
        sbc drone_y, x          ; enfoncement des pieds dans le drone
        cmp #7
        bcs @fatal
        lda #0                  ; ÉCRASÉ ! le drone disparaît...
        sta drone_actif, x
        sta vy_lo
        lda #$FD                ; ...et le robot rebondit (vitesse −3)
        sta vy_hi
        jmp @suivant
@fatal:
        jmp mourir              ; le rts de mourir renverra à la boucle
                                ; principale, qui verra le nouvel etat
@suivant:
        dex
        bmi @fin
        jmp @drone
@fin:
        rts


; =============================================================================
;  maj_sprites — le brouillon des sprites ($0200), envoyé par la nmi
; =============================================================================
maj_sprites:
        ; --- le robot (2 sprites empilés : tête + corps) ----------------------
        ; Hors jeu (titre, perdu, gagné), il clignote : on le cache une
        ; image sur 32, selon un bit du compteur d'images.
        lda etat
        cmp #ETAT_JEU
        beq @robot_visible
        lda image
        and #%00010000
        beq @robot_visible
        lda #$F0                ; hop, hors écran
        sta $0200
        sta $0204
        jmp @drones
@robot_visible:
        lda joueur_y
        sta $0200               ; Y de la tête
        clc
        adc #8
        sta $0204               ; Y du corps, 8 pixels plus bas
        lda #TUILE_ROBOT_HAUT
        sta $0201
        lda #TUILE_ROBOT_BAS
        sta $0205
        ldx #%00000000          ; attributs : palette 0...
        lda regard
        beq @attributs
        ldx #%01000000          ; ...plus le miroir horizontal si on regarde
@attributs:                     ;    à gauche (bit 6 : le PPU retourne la
        stx $0202               ;    tuile tout seul, gratuitement !)
        stx $0206
        lda joueur_x_lo         ; position À L'ÉCRAN = monde − caméra.
        sec                     ; Le joueur est toujours à moins de 256 px de
        sbc camera_lo           ; la caméra : l'octet bas suffit, le reste
        sta $0203               ; de la soustraction s'annule tout seul.
        sta $0207

@drones:
        ldx #2
@un_drone:
        txa                     ; adresse OAM du sprite 2+X : 8 + X×4
        asl a
        asl a
        clc
        adc #8
        tay                     ; Y = décalage dans la page des sprites
        lda drone_actif, x
        beq @cacher
        lda drone_x_lo, x       ; écart = drone − caméra (16 bits) : l'octet
        sec                     ; haut doit tomber à 0, sinon le drone est
        sbc camera_lo           ; hors de l'écran
        sta tmp_lo
        lda drone_x_hi, x
        sbc camera_hi
        bne @cacher
        lda drone_y, x
        sta $0200, y
        lda #TUILE_DRONE
        sta $0201, y
        lda drone_dir, x        ; le drone regarde là où il va
        bmi @vers_gauche
        lda #%01000001          ; palette 1 + miroir
        bne @attr_drone
@vers_gauche:
        lda #%00000001          ; palette 1
@attr_drone:
        sta $0202, y
        lda tmp_lo
        sta $0203, y
        jmp @drone_suivant
@cacher:
        lda #$F0
        sta $0200, y
@drone_suivant:
        dex
        bpl @un_drone

        ; --- le tableau de bord (des sprites, eux ne défilent pas !) ----------
        lda #23
        sta $0214               ; Y des 3 chiffres du score et du chiffre
        sta $0218               ; des vies
        sta $021C
        sta $0220
        lda score_c
        clc
        adc #TUILE_CHIFFRE_0
        sta $0215
        lda score_d
        clc
        adc #TUILE_CHIFFRE_0
        sta $0219
        lda #TUILE_CHIFFRE_0    ; les unités : toujours "0" (10 pts la puce)
        sta $021D
        lda vies
        clc
        adc #TUILE_CHIFFRE_0
        sta $0221
        lda #%00000010          ; palette 2 (blanc)
        sta $0216
        sta $021A
        sta $021E
        sta $0222
        lda #16
        sta $0217
        lda #24
        sta $021B
        lda #32
        sta $021F
        lda #232
        sta $0223
        rts


; =============================================================================
;  NMI — à chaque VBlank : sprites, décor en attente, et le DÉFILEMENT
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

        lda col_actif           ; 2) une colonne de décor en attente ?
        beq @pas_de_colonne
        jsr ecrire_colonne
        lda #0
        sta col_actif
@pas_de_colonne:

        lda puce_actif          ; 3) une puce à effacer ? (4 tuiles : deux en
        beq @pas_de_puce        ;    haut, deux en bas, 32 cases plus loin)
        lda #%00000000          ; retour au mode "avancer d'une case"
        sta PPUCTRL
        bit PPUSTATUS
        lda puce_adr_hi
        sta PPUADDR
        lda puce_adr_lo
        sta PPUADDR
        lda #TUILE_VIDE
        sta PPUDATA
        sta PPUDATA
        lda puce_adr_lo
        clc
        adc #32
        tax
        lda puce_adr_hi
        adc #0
        sta PPUADDR
        stx PPUADDR
        lda #TUILE_VIDE
        sta PPUDATA
        sta PPUDATA
        lda #0
        sta puce_actif
@pas_de_puce:

        ; 4) LE DÉFILEMENT — deux octets qui font tout le travail :
        ;    PPUSCROLL reçoit le décalage horizontal (0-255), et le bit 0 de
        ;    PPUCTRL choisit la nametable de départ (A ou B). À eux deux, ils
        ;    couvrent 512 pixels ; nos colonnes fraîchement écrites font le
        ;    reste. C'est TOUT le secret du défilement à la Mario.
        bit PPUSTATUS
        lda camera_lo
        sta PPUSCROLL
        lda #0
        sta PPUSCROLL           ; pas de défilement vertical
        lda camera_hi
        and #1
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
;  LE NIVEAU — 64 colonnes de 15 métatuiles, à lire... la tête penchée !
; =============================================================================
;  Chaque ligne ci-dessous est UNE COLONNE du niveau, écrite du CIEL (à
;  gauche) au SOL (à droite). Tournez la tête de 90° vers la gauche et vous
;  verrez le niveau. Les lettres :
;     V = vide      B = bloc de béton (solide)   N = plateforme néon (solide)
;     P = puce à ramasser                        T/M = l'antenne d'arrivée
;  Modifier le niveau = changer des lettres. Amusez-vous !

V = TYPE_VIDE
B = TYPE_BLOC
N = TYPE_NEON
P = TYPE_PUCE
T = TYPE_ANTENNE
M = TYPE_MAT

niveau:
        ;     ciel ................................. sol
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 0   départ
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 1
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 2   ← le robot naît ici
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 3
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 4
        .byte V,V,V,V,V,V,V,V,V,V,V,P,V,N,B   ; col 5   première puce
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 6
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 7
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 8   ── le vide ! sautez !
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 9
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 10  zone du drone 1
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 11
        .byte V,V,V,V,V,V,V,V,V,V,N,V,V,N,B   ; col 12  plateforme...
        .byte V,V,V,V,V,V,V,V,V,P,N,V,V,N,B   ; col 13  ...avec puce dessus
        .byte V,V,V,V,V,V,V,V,V,V,N,V,V,N,B   ; col 14
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 15
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 16  ── le vide !
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 17
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 18
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 19
        .byte V,V,V,V,V,V,V,V,V,V,P,V,B,N,B   ; col 20  l'escalier commence
        .byte V,V,V,V,V,V,V,V,V,V,V,B,B,N,B   ; col 21
        .byte V,V,V,V,V,V,V,V,P,V,B,B,B,N,B   ; col 22  (puce au sommet)
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 23
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 24
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 25
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 26  ── le vide !
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 27
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 28  zone du drone 2
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 29
        .byte V,V,V,V,V,V,V,V,P,V,N,V,V,N,B   ; col 30  plateforme à 3 puces
        .byte V,V,V,V,V,V,V,V,P,V,N,V,V,N,B   ; col 31
        .byte V,V,V,V,V,V,V,V,P,V,N,V,V,N,B   ; col 32
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 33
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 34
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 35
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 36  ── le vide !
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 37
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 38
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 39
        .byte V,V,V,V,V,V,V,V,V,V,N,V,V,N,B   ; col 40  premier étage...
        .byte V,V,V,V,V,V,V,V,V,V,N,V,V,N,B   ; col 41
        .byte V,V,V,V,V,V,V,V,V,V,N,V,V,N,B   ; col 42
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 43  zone du drone 3
        .byte V,V,V,V,V,V,V,N,V,V,V,V,V,N,B   ; col 44  ...deuxième étage !
        .byte V,V,V,V,V,V,P,N,V,V,V,V,V,N,B   ; col 45  (la puce du courage)
        .byte V,V,V,V,V,V,V,N,V,V,V,V,V,N,B   ; col 46
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 47
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 48  ── le grand vide !
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 49
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 50  dernière ligne droite
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 51
        .byte V,V,V,V,V,V,V,V,V,V,V,P,V,N,B   ; col 52
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 53
        .byte V,V,V,V,V,V,V,V,V,V,V,P,V,N,B   ; col 54
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 55
        .byte V,V,V,V,V,V,V,V,V,V,V,P,V,N,B   ; col 56
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 57
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 58
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 59
        .byte V,V,V,V,V,V,V,V,V,V,V,T,M,N,B   ; col 60  ★ L'ANTENNE-RELAIS ★
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 61
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 62
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 63


; =============================================================================
;  LES VECTEURS
; =============================================================================
.segment "VECTORS"
        .word nmi, reset, irq


; =============================================================================
;  LES GRAPHISMES (voir le casse-brique pour la mécanique des 2 plans)
; =============================================================================
;  Rappel : couleur 1 = plan 0 seul, couleur 2 = plan 1 seul,
;           couleur 3 = les deux plans (utilisée via le macro ci-dessous).

.macro TUILE_UNIE l0, l1, l2, l3, l4, l5, l6, l7
        .byte l0, l1, l2, l3, l4, l5, l6, l7   ; plan 0
        .byte l0, l1, l2, l3, l4, l5, l6, l7   ; plan 1
.endmacro

.segment "CHR"

; --- $00 : vide ----------------------------------------------------------------
        .res 16

; --- $01 : béton d'immeuble, fenêtres allumées (couleur 1 + touches de 3) ------
        .byte %11111111         ; plan 0 : tout le bloc
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %00000000         ; plan 1 : là où il est AUSSI allumé, la
        .byte %00000000         ; couleur passe de 1 (gris) à 3 (or) :
        .byte %01100110         ; ces bits-là sont les fenêtres éclairées
        .byte %00000000         ; de la ville, la nuit
        .byte %00000000
        .byte %01100110
        .byte %00000000
        .byte %00000000

; --- $02 : dessus de toit, liseré néon (couleur 2) sur béton (couleur 1) --------
        .byte %00000000         ; plan 0
        .byte %00000000
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111
        .byte %11111111         ; plan 1 : les 2 lignes du haut brillent
        .byte %11111111
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000

; --- $03 : libre (vide) ---------------------------------------------------------
        .res 16

; --- $04-$07 : la puce de données, en 4 quarts de 16×16, dorée (couleur 3) ------
;  La puce est un petit carré à pattes, centré dans sa métatuile : chaque
;  tuile n'en dessine qu'un quart, dans son coin intérieur.
        TUILE_UNIE %00000000, %00000000, %00000000, %00000000, %00000101, %00001111, %00001111, %00000111  ; $04 haut-gauche
        TUILE_UNIE %00000000, %00000000, %00000000, %00000000, %10100000, %11110000, %11110000, %11100000  ; $05 haut-droit
        TUILE_UNIE %00000111, %00001111, %00001111, %00000101, %00000000, %00000000, %00000000, %00000000  ; $06 bas-gauche
        TUILE_UNIE %11100000, %11110000, %11110000, %10100000, %00000000, %00000000, %00000000, %00000000  ; $07 bas-droit

; --- $08 : le robot R-2026, la tête (corps couleur 1, visière couleur 2) --------
        .byte %00011000         ; plan 0 : l'antenne...
        .byte %00011000
        .byte %01111110         ; ...et la tête
        .byte %11111111
        .byte %10000001         ; (au milieu, la visière est sur l'autre plan)
        .byte %11111111
        .byte %01111110
        .byte %00100100
        .byte %00000000         ; plan 1 : la visière rouge
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %01111110
        .byte %00000000
        .byte %00000000
        .byte %00000000

; --- $09 : le robot, le corps (avec voyant de livraison couleur 2) --------------
        .byte %01111110         ; plan 0
        .byte %11100111
        .byte %11111111
        .byte %01111110
        .byte %00100100
        .byte %00100100
        .byte %01100110
        .byte %00000000
        .byte %00000000         ; plan 1 : le voyant sur la poitrine
        .byte %00011000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000

; --- $0A : le drone de livraison (coque couleur 1, œil couleur 2) ---------------
        .byte %01100110         ; plan 0 : les rotors...
        .byte %11111111         ; ...les bras...
        .byte %01111110         ; ...la coque
        .byte %01100110
        .byte %01111110
        .byte %00111100
        .byte %00000000
        .byte %00000000
        .byte %00000000         ; plan 1 : l'œil-caméra rouge
        .byte %00000000
        .byte %00000000
        .byte %00011000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000

; --- $0B-$0E : l'antenne-relais (balise couleur 3 en haut, mât couleur 2) -------
        .byte %00000000, %00000011, %00000011, %00000001, %00000001, %00000001, %00000001, %00000001  ; $0B plan 0
        .byte %00000011, %00000011, %00000011, %00000001, %00000001, %00000001, %00000001, %00000001  ; $0B plan 1
        .byte %00000000, %11000000, %11000000, %10000000, %10000000, %10000000, %10000000, %10000000  ; $0C plan 0
        .byte %11000000, %11000000, %11000000, %10000000, %10000000, %10000000, %10000000, %10000000  ; $0C plan 1
        .byte %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000011, %00001111  ; $0D plan 0 (pied)
        .byte %00000001, %00000001, %00000001, %00000001, %00000001, %00000001, %00000011, %00001111  ; $0D plan 1
        .byte %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %11000000, %11110000  ; $0E plan 0
        .byte %10000000, %10000000, %10000000, %10000000, %10000000, %10000000, %11000000, %11110000  ; $0E plan 1

; --- On saute jusqu'à la tuile $10 : 15 tuiles écrites × 16 octets = $F0 --------
        .res $100 - $F0

; --- $10-$19 : les chiffres (la même fonte que le casse-brique) ------------------
        TUILE_UNIE %01111100, %11000110, %11001110, %11010110, %11100110, %11000110, %01111100, %00000000  ; 0
        TUILE_UNIE %00110000, %01110000, %00110000, %00110000, %00110000, %00110000, %11111100, %00000000  ; 1
        TUILE_UNIE %01111000, %11001100, %00001100, %00111000, %01100000, %11001100, %11111100, %00000000  ; 2
        TUILE_UNIE %01111000, %11001100, %00001100, %00111000, %00001100, %11001100, %01111000, %00000000  ; 3
        TUILE_UNIE %00011100, %00111100, %01101100, %11001100, %11111110, %00001100, %00011110, %00000000  ; 4
        TUILE_UNIE %11111100, %11000000, %11111000, %00001100, %00001100, %11001100, %01111000, %00000000  ; 5
        TUILE_UNIE %00111000, %01100000, %11000000, %11111000, %11001100, %11001100, %01111000, %00000000  ; 6
        TUILE_UNIE %11111100, %11001100, %00001100, %00011000, %00110000, %00110000, %00110000, %00000000  ; 7
        TUILE_UNIE %01111000, %11001100, %11001100, %01111000, %11001100, %11001100, %01111000, %00000000  ; 8
        TUILE_UNIE %01111000, %11001100, %11001100, %01111100, %00001100, %00011000, %01110000, %00000000  ; 9

; Le reste des 8 Ko de graphismes est rempli de zéros par l'éditeur de liens.
; Fin du voyage — vous savez maintenant faire défiler un monde. 🤖
