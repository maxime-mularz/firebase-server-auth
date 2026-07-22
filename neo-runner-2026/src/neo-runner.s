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
APUSTATUS = $4015
JOYPAD1   = $4016
APUFRAME  = $4017

; --- Les registres du son (voir le casse-brique pour le cours complet) --------
CARRE1_VOL  = $4000 ; canal carré 1 : les bruitages
CARRE1_BAL  = $4001
CARRE1_BAS  = $4002
CARRE1_HAUT = $4003
CARRE2_VOL  = $4004 ; canal carré 2 : la mélodie
CARRE2_BAL  = $4005
CARRE2_BAS  = $4006
CARRE2_HAUT = $4007
TRI_LIN     = $4008 ; canal triangle : la basse
TRI_BAS     = $400A
TRI_HAUT    = $400B
BRUIT_VOL   = $400C ; canal de bruit : chocs et catastrophes
BRUIT_PER   = $400E
BRUIT_LON   = $400F

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
TUILE_ROBOT_BAS  = $09   ; jambes serrées (pose 1)
TUILE_DRONE      = $0A   ; rotors, phase 1
TUILE_ROBOT_BAS2 = $0F   ; jambes écartées (pose 2 : la course !)
TUILE_CHIFFRE_0  = $10
TUILE_DRONE2     = $1A   ; rotors, phase 2
TUILE_ICONE_PUCE = $1B   ; le petit losange du bandeau de score
TIRET            = $1C
; L'alphabet (les 10 lettres de nos deux phrases), tuiles $20+ :
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

; --- Les notes de musique (mêmes tables que le casse-brique) --------------------
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

; Le moteur de musique et les bruitages (voir le casse-brique)
mus_active:    .res 1
mel_pos:       .res 1
mel_cpt:       .res 1
bas_pos:       .res 1
bas_cpt:       .res 1
bip_cpt:       .res 1
bruit_cpt:     .res 1

; v2 : les deux mondes et les jingles
monde:         .res 1   ; 1 ou 2 : le monde en cours
jingle_actif:  .res 1   ; un jingle (mini-partition sur le carré 1) joue
jingle_pos:    .res 1
jingle_cpt:    .res 1
jingle_ptr:    .res 2   ; pointeur vers la partition du jingle


; -----------------------------------------------------------------------------
;  VARIABLES en RAM ordinaire
; -----------------------------------------------------------------------------
;  `carte` DOIT être la première : elle est alors pile à l'adresse $0300, et
;  la case (colonne, rangée) se trouve à l'adresse $0300 + colonne×16 + rangée.
;  Ce choix rend le calcul d'adresse presque gratuit (voir type_carte).

.bss

carte:          .res 1024  ; 64 colonnes × 16 (15 rangées + 1 de bourrage)
tampon_colonne: .res 52    ; les 52 tuiles d'une colonne de décor à écrire
                           ; (26 par colonne de tuiles : les rangées 0-3 de
                           ;  l'écran appartiennent au bandeau de score !)


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
        lda #1                  ; on commence au monde 1
        sta monde

        jsr charger_niveau      ; copie la carte et dessine les 2 premiers écrans
        jsr dessiner_titre_texte

        lda #%00001111          ; ouvre les 4 canaux du son...
        sta APUSTATUS
        jsr demarrer_musique    ; ...et en musique !

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
        ; --- fond : cette fois, PLUSIEURS palettes, choisies par la table
        ;     d'attributs (voir dessiner_hud) ! -------------------------------
        .byte $0F, $00, $2C, $28   ; palette 0 : quartier au néon CYAN
        .byte $0F, $00, $25, $28   ; palette 1 : quartier au néon ROSE
        .byte $0F, $28, $2C, $30   ; palette 2 : le bandeau (or, cyan, blanc)
        .byte $0F, $0F, $0F, $0F
        ; --- sprites ---
        .byte $0F, $30, $16, $0F   ; palette 0 : robot blanc, visière rouge
        .byte $0F, $2C, $15, $0F   ; palette 1 : drone cyan, œil rouge
        .byte $0F, $0F, $0F, $0F
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
        ;  v2 : DEUX mondes ! Le pointeur source vient d'une table indexée
        ;  par le monde en cours — ajouter un monde = ajouter une carte.
        ldx monde
        dex                     ; monde 1 → index 0
        lda mondes_lo, x        ; (les tables mondes_lo/hi contiennent les
        sta src_ptr             ;  octets bas et haut de l'adresse de chaque
        lda mondes_hi, x        ;  carte : une adresse 16 bits en 2 octets)
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

        ; --- 2) Le bandeau de score et les tables d'attributs ----------------
        jsr dessiner_hud

        ; --- 3) Dessiner les 32 premières colonnes (écrans 1 et 2) ----------
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

        ; --- 4) Tout le monde au départ --------------------------------------
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

        ; les 3 drones du monde en cours : leurs tables font 6 entrées
        ; (3 par monde), l'index est donc drone + (monde−1)×3
        lda monde
        sec
        sbc #1
        sta tmp_lo
        asl a
        clc
        adc tmp_lo              ; (monde−1) × 3
        sta tmp_lo
        ldx #2                  ; X = le drone, Y = sa ligne dans les tables
@drone:
        txa
        clc
        adc tmp_lo
        tay
        lda drones_debut_lo, y
        sta drone_x_lo, x
        lda drones_debut_hi, y
        sta drone_x_hi, x
        lda #200                ; tous volent au ras du sol
        sta drone_y, x
        lda #1
        sta drone_dir, x
        sta drone_actif, x
        dex
        bpl @drone
        rts

; Où trouver la carte de chaque monde
mondes_lo: .byte <niveau, <niveau_2
mondes_hi: .byte >niveau, >niveau_2

; Position de départ des drones : 3 lignes par monde (16 bits, donc 2 tables)
drones_debut_lo: .byte $A0, $C0, $A0,  $90, $80, $70   ; monde 1 puis monde 2
drones_debut_hi: .byte $00, $01, $02,  $00, $01, $02
; Bornes de leur va-et-vient
drones_min_lo:   .byte $A0, $C0, $A0,  $90, $80, $70
drones_min_hi:   .byte $00, $01, $02,  $00, $01, $02
drones_max_lo:   .byte $E8, $28, $E8,  $C8, $C0, $B8
drones_max_hi:   .byte $00, $02, $02,  $00, $01, $02


; -----------------------------------------------------------------------------
;  eteindre_ecran / allumer_ecran
; -----------------------------------------------------------------------------
eteindre_ecran:
        lda #0
        sta PPUCTRL             ; NMI coupée...
        sta PPUMASK             ; ...affichage coupé : on peut redessiner
        rts

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
;  dessiner_hud — le bandeau de score et les TABLES D'ATTRIBUTS
; =============================================================================
;  Le bandeau occupe les rangées de tuiles 0 à 3 de la nametable A : une
;  icône de puce, le score, une tête de robot, les vies, et une barre néon
;  en rangée 3. C'est du DÉCOR, pas des sprites — l'astuce du "sprite 0"
;  dans la nmi le maintiendra immobile pendant que le monde défile dessous.
;
;  On règle aussi enfin les TABLES D'ATTRIBUTS (les 64 derniers octets de
;  chaque nametable), ignorées jusqu'ici. Chaque octet y choisit la palette
;  de fond d'un carré de 4×4 tuiles, à raison de 2 bits par quart de carré :
;  %10101010 = "palette 2 partout", %01010101 = "palette 1 partout".
;  Résultat : le bandeau a ses couleurs, et chaque écran du niveau devient
;  un "quartier" à la couleur de néon différente — cyan (A), rose (B) !

dessiner_hud:
        ; --- nametable A, rangées 0-3 : le bandeau ---------------------------
        bit PPUSTATUS
        lda #$20
        sta PPUADDR
        lda #$00
        sta PPUADDR
        lda #TUILE_VIDE         ; rangée 0 : vide
        ldx #32
@rangee0:
        sta PPUDATA
        dex
        bne @rangee0
        ldx #4                  ; rangée 1 : 4 cases vides...
@rangee1a:
        sta PPUDATA
        dex
        bne @rangee1a
        lda #TUILE_ICONE_PUCE   ; ...l'icône des puces...
        sta PPUDATA
        lda #TUILE_CHIFFRE_0    ; ...le score "000"...
        sta PPUDATA
        sta PPUDATA
        sta PPUDATA
        lda #TUILE_VIDE
        ldx #16
@rangee1b:
        sta PPUDATA
        dex
        bne @rangee1b
        lda #TUILE_ROBOT_HAUT   ; ...la tête du robot...
        sta PPUDATA
        lda vies                ; ...et le nombre de vies
        clc
        adc #TUILE_CHIFFRE_0
        sta PPUDATA
        lda #TUILE_VIDE
        ldx #6
@rangee1c:
        sta PPUDATA
        dex
        bne @rangee1c
        ldx #32                 ; rangée 2 : vide
@rangee2:
        sta PPUDATA
        dex
        bne @rangee2
        lda #TUILE_NEON         ; rangée 3 : la barre lumineuse
        ldx #32
@rangee3:
        sta PPUDATA
        dex
        bne @rangee3

        ; --- nametable B, rangées 0-3 : jamais visibles... sauf la barre -----
        ;  (en fin de bandeau le défilement a déjà basculé : sans cette
        ;   copie de la rangée 3, la barre serait rognée un écran sur deux)
        lda #$24
        sta PPUADDR
        lda #$00
        sta PPUADDR
        lda #TUILE_VIDE
        ldx #96                 ; rangées 0-2
@rangees_b:
        sta PPUDATA
        dex
        bne @rangees_b
        lda #TUILE_NEON
        ldx #32
@rangee3_b:
        sta PPUDATA
        dex
        bne @rangee3_b

        ; --- attributs de la nametable A : bandeau pal.2, quartier pal.0 -----
        lda #$23
        sta PPUADDR
        lda #$C0
        sta PPUADDR
        lda #%10101010          ; 1re rangée d'attributs = les tuiles 0-3 :
        ldx #8                  ; pile la hauteur du bandeau. Bien joué, non ?
@attr_a1:
        sta PPUDATA
        dex
        bne @attr_a1
        lda #%00000000          ; le reste : palette 0 (quartier cyan)
        ldx #56
@attr_a2:
        sta PPUDATA
        dex
        bne @attr_a2
        ; --- attributs de la nametable B : bandeau pal.2, quartier pal.1 -----
        lda #$27
        sta PPUADDR
        lda #$C0
        sta PPUADDR
        lda #%10101010
        ldx #8
@attr_b1:
        sta PPUDATA
        dex
        bne @attr_b1
        lda #%01010101          ; palette 1 (quartier rose)
        ldx #56
@attr_b2:
        sta PPUDATA
        dex
        bne @attr_b2
        rts


; =============================================================================
;  L'ÉCRAN TITRE — du texte dans le ciel (à dessiner/effacer écran éteint)
; =============================================================================
dessiner_titre_texte:
        lda #%00000000          ; ATTENTION : charger_niveau laisse le PPU en
        sta PPUCTRL             ; mode "colonne" (+32) ! Sans cette remise en
        bit PPUSTATUS           ; mode "+1", le titre s'écrirait... à la
        lda #$20                ; verticale. (Vécu aussi.)
                                ; rangée de tuiles 7, colonne 8 (le ciel)
        sta PPUADDR
        lda #$E8
        sta PPUADDR
        ldx #0
@nom:
        lda texte_nom, x
        sta PPUDATA
        inx
        cpx #15
        bne @nom
        lda #$21                ; rangée 10, colonne 8
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

; La même chose, à l'encre invisible : Start efface le titre du ciel.
effacer_titre_texte:
        lda #%00000000          ; même prudence : mode "+1" d'abord
        sta PPUCTRL
        bit PPUSTATUS
        lda #$20
        sta PPUADDR
        lda #$E8
        sta PPUADDR
        lda #TUILE_VIDE
        ldx #15
@nom:
        sta PPUDATA
        dex
        bne @nom
        lda #$21
        sta PPUADDR
        lda #$48
        sta PPUADDR
        lda #TUILE_VIDE
        ldx #16
@appuie:
        sta PPUDATA
        dex
        bne @appuie
        rts

texte_nom:
        .byte L_N, L_E, L_O, TIRET, L_R, L_U, L_N, L_N, L_E, L_R, ESPACE
        .byte TUILE_CHIFFRE_0+2, TUILE_CHIFFRE_0, TUILE_CHIFFRE_0+2, TUILE_CHIFFRE_0+6
texte_appuie:
        .byte L_A, L_P, L_P, L_U, L_I, L_E, ESPACE, L_S, L_U, L_R, ESPACE
        .byte L_S, L_T, L_A, L_R, L_T


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
        asl a                   ; ...×2 tuiles par métatuile...
        clc
        adc #$80                ; ...+ 4 rangées × 32 : on écrit SOUS le
        sta col_adr_lo          ;    bandeau (rangées 4 à 29)

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

        ; --- traduire les métatuiles en tuiles ---------------------------------
        ;  Les rangées 0 et 1 de la carte (tuiles 0-3 de l'écran) sont
        ;  cachées derrière le bandeau : on ne dessine que les rangées 2-14.
        ldy #2                  ; Y = rangée (2-14)
@rangee:
        sty rang_tmp
        lda (carte_ptr), y      ; le TYPE de la métatuile
        tax                     ; → X, pour indexer les tables de tuiles
        lda rang_tmp
        sec
        sbc #2                  ; position dans le tampon = (rangée−2)×2
        asl a
        tay
        lda metatuile_hg, x     ; les 4 coins de la métatuile :
        sta tampon_colonne, y   ;   haut-gauche
        lda metatuile_bg, x
        sta tampon_colonne+1, y ;   bas-gauche
        lda metatuile_hd, x
        sta tampon_colonne+26, y ;  haut-droit
        lda metatuile_bd, x
        sta tampon_colonne+27, y ;  bas-droit
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
        cpx #26
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
        cpx #52
        bne @droite
        rts


; =============================================================================
;  LA BOUCLE PRINCIPALE
; =============================================================================
principale:
        jsr attendre_nmi
        jsr maj_musique
        jsr maj_bruitages
        jsr maj_jingle
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
        jsr eteindre_ecran      ; on retire le titre du ciel...
        jsr effacer_titre_texte
        jsr allumer_ecran       ; ...et que la course commence !
        lda #ETAT_JEU
        sta etat
        jsr bip_depart
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
        jsr bip_saut
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
        ; v2 : première antenne = direction le MONDE 2. La seconde = gagné !
        lda monde
        cmp #2
        beq @victoire_finale
        inc monde
        jsr jouer_jingle_victoire
        lda #0                  ; écran éteint, nouveau monde, et on repart
        sta PPUMASK             ; (exactement le même rituel que mourir)
        sta PPUCTRL
        jsr charger_niveau
        jsr allumer_ecran
        rts
@victoire_finale:
        lda #ETAT_GAGNE         ; les DEUX livraisons accomplies !
        sta etat
        jsr arreter_musique
        jsr jouer_jingle_victoire
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
        jsr bip_puce            ; cling !

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
        jsr arreter_musique
        jsr jouer_jingle_defaite
        jmp bruit_fin           ; long grondement (son rts conclura)
@rejouer:
        jsr bruit_vie           ; "pshh"
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
        jsr bruit_ecrase        ; "crounch" (X n'est pas abîmé, ouf)
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
;  LE SON — même moteur que le casse-brique (le cours détaillé est là-bas)
; =============================================================================
;  Carré 2 = mélodie, triangle = basse, carré 1 = bips, bruit = chocs.

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
        ldx #0                  ; ...alors on reboucle
        lda melodie, x
@note_lue:
        beq @soupir             ; note 0 = un silence
        tay
        lda #%10110110          ; onde carrée 50 %, volume 6
        sta CARRE2_VOL
        lda #$08
        sta CARRE2_BAL          ; neutralise le balayage automatique
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

; -----------------------------------------------------------------------------
;  LA PARTITION — des arpèges qui descendent : l'ambiance nocturne de 2026.
;  Quatre mesures sur la mineur / fa / do / sol. À vous de la remixer !
; -----------------------------------------------------------------------------
melodie:
        .byte NOTE_MI5, 12, NOTE_DO5,  12, NOTE_LA4, 12, NOTE_DO5, 12
        .byte NOTE_DO5, 12, NOTE_LA4,  12, NOTE_FA4, 12, NOTE_LA4, 12
        .byte NOTE_MI5, 12, NOTE_SOL5, 12, NOTE_MI5, 12, NOTE_DO5, 12
        .byte NOTE_RE5, 12, NOTE_SI4,  12, NOTE_SOL4, 12, NOTE_SI4, 12
        .byte $FF

basse:
        .byte NOTE_LA2, 48, NOTE_FA2, 48, NOTE_DO3, 48, NOTE_SOL2, 48
        .byte $FF

; Les périodes des notes : période = 1 789 773 ÷ (16 × Hz) − 1.
;                 sil  fa2  sol2 la2  do3  fa4  sol4 la4  si4  do5  ré5  mi5  fa5  sol5 la5
notes_bas:  .byte $00, $00, $74, $F8, $56, $3F, $1C, $FD, $E1, $D5, $BD, $A9, $9F, $8E, $7E
notes_haut: .byte $00, $05, $04, $03, $03, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00

; -----------------------------------------------------------------------------
;  LES BRUITAGES
; -----------------------------------------------------------------------------
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
        sta BRUIT_LON
        sty bruit_cpt
        rts

maj_bruitages:
        lda jingle_actif        ; un jingle occupe le canal des bips :
        bne @bruit              ; on ne lui coupe pas le sifflet !
        lda bip_cpt
        beq @bruit
        dec bip_cpt
        bne @bruit
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

; -----------------------------------------------------------------------------
;  LES JINGLES — de vraies petites phrases musicales pour les grands moments
; -----------------------------------------------------------------------------
;  Un jingle est une mini-partition (note, durée, ..., $FF) jouée sur le
;  canal des bips : le même moteur que la musique, en 20 lignes. La fanfare
;  du monde suivant monte, celle du game over descend — l'oreille comprend
;  avant même de lire l'écran.

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
        lda #0
        sta jingle_pos
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
        lda #0                  ; partition terminée : silence et rideau
        sta jingle_actif
        lda #%00110000
        sta CARRE1_VOL
        rts
@jouer:
        tax
        lda notes_bas, x
        sta CARRE1_BAS
        lda notes_haut, x
        ora #%11111000
        sta CARRE1_HAUT
        lda #%10111010
        sta CARRE1_VOL
        lda #$08
        sta CARRE1_BAL
        iny
        lda (jingle_ptr), y
        sta jingle_cpt
        iny
        sty jingle_pos
        rts

jingle_victoire: .byte NOTE_DO5, 8,  NOTE_MI5, 8,  NOTE_SOL5, 8,  NOTE_LA5, 24, $FF
jingle_defaite:  .byte NOTE_MI5, 10, NOTE_DO5, 10, NOTE_LA4, 10, NOTE_FA4, 28, $FF

; Le catalogue des sons du jeu :
bip_depart:                     ; Start pressé
        lda #$FD
        ldx #$00                ; la4
        ldy #4
        jmp jouer_bip
bip_saut:                       ; hop !
        lda #$1C
        ldx #$01                ; sol4, bref
        ldy #3
        jmp jouer_bip
bip_puce:                       ; cling ! aigu
        lda #$6A
        ldx #$00                ; ≈ do6
        ldy #4
        jmp jouer_bip
bip_victoire:                   ; la grande note de la livraison accomplie
        lda #$7E
        ldx #$00                ; la5
        ldy #40
        jmp jouer_bip
bruit_ecrase:                   ; "crounch" : un drone de moins
        lda #$04
        ldy #8
        jmp jouer_bruit
bruit_vie:                      ; "pshh" : une vie s'envole
        lda #$0A
        ldy #20
        jmp jouer_bruit
bruit_fin:                      ; long grondement de game over
        lda #$0C
        ldy #45
        jmp jouer_bruit


; =============================================================================
;  maj_sprites — le brouillon des sprites ($0200), envoyé par la nmi
; =============================================================================
maj_sprites:
        ; --- Sprite 0 : "l'espion" du bandeau ---------------------------------
        ;  Un sprite opaque, glissé DERRIÈRE le décor (bit 5 des attributs) :
        ;  invisible, mais le PPU signale l'instant précis où l'un de ses
        ;  pixels croise un pixel du fond — pile au bas du bandeau. La nmi
        ;  guette ce signal pour changer le défilement en pleine image !
        lda #23                 ; dernière ligne du bandeau
        sta $0200
        lda #TUILE_BLOC         ; opaque de bord en bord
        sta $0201
        lda #%00100000          ; priorité : derrière le décor
        sta $0202
        lda #120
        sta $0203

        ; --- Le robot (2 sprites empilés : tête + corps) ----------------------
        ; Hors jeu (titre, perdu, gagné), il clignote : on le cache une
        ; image sur 32, selon un bit du compteur d'images.
        lda etat
        cmp #ETAT_JEU
        beq @robot_visible
        lda image
        and #%00010000
        beq @robot_visible
        lda #$F0                ; hop, hors écran
        sta $0204
        sta $0208
        jmp @drones
@robot_visible:
        lda joueur_y
        sta $0204               ; Y de la tête
        clc
        adc #8
        sta $0208               ; Y du corps, 8 pixels plus bas
        lda #TUILE_ROBOT_HAUT
        sta $0205

        ; L'ANIMATION : en l'air, jambes écartées ; au sol, on alterne les
        ; deux poses toutes les 8 images quand on court. Une animation, ce
        ; n'est QUE ça : changer un numéro de tuile au bon rythme !
        lda au_sol
        beq @jambes_ecartees    ; en plein saut
        lda boutons
        and #BTN_GAUCHE|BTN_DROITE
        beq @jambes_serrees     ; immobile
        lda image
        and #%00001000          ; le bit 3 du compteur d'images bat la mesure
        beq @jambes_serrees
@jambes_ecartees:
        lda #TUILE_ROBOT_BAS2
        bne @poser_jambes       ; (toujours pris : A n'est jamais nul ici)
@jambes_serrees:
        lda #TUILE_ROBOT_BAS
@poser_jambes:
        sta $0209

        ldx #%00000000          ; attributs : palette 0...
        lda regard
        beq @attributs
        ldx #%01000000          ; ...plus le miroir horizontal si on regarde
@attributs:                     ;    à gauche (bit 6 : le PPU retourne la
        stx $0206               ;    tuile tout seul, gratuitement !)
        stx $020A
        lda joueur_x_lo         ; position À L'ÉCRAN = monde − caméra.
        sec                     ; Le joueur est toujours à moins de 256 px de
        sbc camera_lo           ; la caméra : l'octet bas suffit, le reste
        sta $0207               ; de la soustraction s'annule tout seul.
        sta $020B

@drones:
        ldx #2
@un_drone:
        txa                     ; adresse OAM du sprite 3+X : 12 + X×4
        asl a
        asl a
        clc
        adc #12
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
        lda image               ; les rotors tournent : deux tuiles
        and #%00000100          ; alternées toutes les 4 images
        beq @rotors_1
        lda #TUILE_DRONE2
        bne @rotors_ok
@rotors_1:
        lda #TUILE_DRONE
@rotors_ok:
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
        rts
        ; (le score et les vies ne sont plus des sprites : ce sont de vraies
        ;  tuiles du bandeau — voir dessiner_hud, et leur mise à jour dans nmi)


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
        lda #%10000000          ; retour au mode "avancer d'une case"
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

        ; 4) Les compteurs du bandeau (score et vies, en tuiles de décor)
        lda #%10000000          ; mode "avancer d'une case"
        sta PPUCTRL
        bit PPUSTATUS
        lda #$20
        sta PPUADDR
        lda #$25                ; $2025 = rangée 1, colonnes 5-7 : le score
        sta PPUADDR
        lda score_c
        clc
        adc #TUILE_CHIFFRE_0
        sta PPUDATA
        lda score_d
        clc
        adc #TUILE_CHIFFRE_0
        sta PPUDATA
        lda #TUILE_CHIFFRE_0    ; unités : toujours "0" (10 points la puce)
        sta PPUDATA
        lda #$20
        sta PPUADDR
        lda #$39                ; $2039 = rangée 1, colonne 25 : les vies
        sta PPUADDR
        lda vies
        clc
        adc #TUILE_CHIFFRE_0
        sta PPUDATA

        ; 5) LE DÉFILEMENT EN DEUX TEMPS — l'astuce du SPRITE 0.
        ;    Problème : si on décale toute l'image, le bandeau de score
        ;    défile aussi ! La solution, celle de Super Mario Bros. :
        ;      a) on commence l'image SANS défilement → le PPU dessine le
        ;         bandeau (rangées 0-3 de la nametable A) bien droit ;
        ;      b) le sprite 0 est posé sur la dernière ligne du bandeau ;
        ;         quand le PPU l'y dessine, il lève un drapeau (bit 6 de
        ;         PPUSTATUS) : "je suis en train de peindre la ligne 24 !" ;
        ;      c) on change ALORS le défilement, en pleine image : tout ce
        ;         qui reste à peindre en dessous, c'est le monde, décalé.
        bit PPUSTATUS           ; a) bandeau : défilement (0,0), nametable A
        lda #0
        sta PPUSCROLL
        sta PPUSCROLL
        lda #%10000000
        sta PPUCTRL
        ; b) attendre... D'abord que le drapeau de l'image PRÉCÉDENTE
        ;    retombe (il ne se baisse qu'à la toute fin du VBlank) :
@drapeau_retombe:
        bit PPUSTATUS           ; BIT copie le bit 6 dans l'indicateur V...
        bvs @drapeau_retombe    ; ...testable par BVS/BVC. Sur mesure !
        ; ...puis que le sprite 0 soit touché sur CETTE image :
@drapeau_leve:
        bit PPUSTATUS
        bvc @drapeau_leve
        ; c) et hop : le reste de l'image défile avec la caméra
        lda camera_lo
        sta PPUSCROLL
        lda #0
        sta PPUSCROLL
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

; -----------------------------------------------------------------------------
;  LE MONDE 2 — les hauts quartiers. Trous plus larges, tours plus hautes,
;  drones aux aguets. Même format : à vous d'en dessiner un 3e !
; -----------------------------------------------------------------------------
niveau_2:
        ;     ciel ................................. sol
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 0   départ
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 1
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 2
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 3
        .byte V,V,V,V,V,V,V,V,V,V,V,P,V,N,B   ; col 4
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 5
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 6   ── un GRAND vide !
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 7
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 8
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 9   zone du drone 1
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 10
        .byte V,V,V,V,V,V,V,V,V,P,N,V,V,N,B   ; col 11  perchoir à puce
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 12
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 13
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 14  ── le vide
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 15
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 16
        .byte V,V,V,V,V,V,V,V,V,V,V,V,B,N,B   ; col 17  le grand escalier...
        .byte V,V,V,V,V,V,V,V,V,V,V,B,B,N,B   ; col 18
        .byte V,V,V,V,V,V,V,V,P,V,B,B,B,N,B   ; col 19  ...et sa puce
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 20  le palier d'atterrissage
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 21  (souffler avant de sauter)
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 22  ── le vide
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 23
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 24  zone du drone 2
        .byte V,V,V,V,V,V,V,V,P,V,N,V,V,N,B   ; col 25  le balcon aux 3 puces
        .byte V,V,V,V,V,V,V,V,P,V,N,V,V,N,B   ; col 26
        .byte V,V,V,V,V,V,V,V,P,V,N,V,V,N,B   ; col 27
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 28
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 29  ── le vide
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 30
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 31
        .byte V,V,V,V,V,V,V,V,V,V,V,V,B,N,B   ; col 32  la double tour...
        .byte V,V,V,V,V,V,V,V,V,V,B,B,B,N,B   ; col 33
        .byte V,V,V,V,V,V,P,V,B,B,B,B,B,N,B   ; col 34  ...à la puce du sommet
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 35
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 36
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 37
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 38
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 39  ── le vide
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 40
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 41  zone du drone 3
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 42
        .byte V,V,V,V,V,V,V,V,V,P,N,V,V,N,B   ; col 43
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 44
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 45
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 46
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 47  ── le vide
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,V,V   ; col 48
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 49
        .byte V,V,V,V,V,V,V,V,V,V,V,P,V,N,B   ; col 50
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 51
        .byte V,V,V,V,V,V,V,V,V,V,V,P,V,N,B   ; col 52
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 53
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 54
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 55
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 56
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 57
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 58
        .byte V,V,V,V,V,V,V,V,V,V,V,V,V,N,B   ; col 59
        .byte V,V,V,V,V,V,V,V,V,V,V,T,M,N,B   ; col 60  ★ LA DERNIÈRE ANTENNE ★
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

; --- $0F : le robot, le corps, 2e pose : jambes écartées (la course !) ----------
        .byte %01111110         ; plan 0 : même buste que la tuile $09...
        .byte %11100111
        .byte %11111111
        .byte %01111110
        .byte %01000010         ; ...mais les jambes s'ouvrent
        .byte %01000010
        .byte %11000011
        .byte %00000000
        .byte %00000000         ; plan 1 : le voyant sur la poitrine
        .byte %00011000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000

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

; --- $1A : le drone, rotors phase 2 (l'hélice "a tourné") -----------------------
        .byte %10011001         ; plan 0 : seule la 1re ligne change par
        .byte %11111111         ; rapport à la tuile $0A — et à 15 images
        .byte %01111110         ; par seconde, l'œil y croit !
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

; --- $1B : l'icône "puce" du bandeau (couleur 1 = or, dans la palette 2) --------
        .byte %00000000
        .byte %00011000
        .byte %00111100
        .byte %01111110
        .byte %01111110
        .byte %00111100
        .byte %00011000
        .byte %00000000
        .res 8                  ; plan 1 vide

; --- $1C : le tiret (couleur 3 : les deux plans) ---------------------------------
        TUILE_UNIE %00000000, %00000000, %00000000, %01111110, %00000000, %00000000, %00000000, %00000000

; --- on saute jusqu'à $20 : l'alphabet du titre ($1D-$1F libres) ------------------
        .res 3 * 16

; --- $20-$29 : les 10 lettres de nos deux phrases (couleur 3) ---------------------
        TUILE_UNIE %00110000, %01111000, %11001100, %11001100, %11111100, %11001100, %11001100, %00000000  ; A
        TUILE_UNIE %11111110, %01100010, %01101000, %01111000, %01101000, %01100010, %11111110, %00000000  ; E
        TUILE_UNIE %01111000, %00110000, %00110000, %00110000, %00110000, %00110000, %01111000, %00000000  ; I
        TUILE_UNIE %11000110, %11100110, %11110110, %11011110, %11001110, %11000110, %11000110, %00000000  ; N
        TUILE_UNIE %00111000, %01101100, %11000110, %11000110, %11000110, %01101100, %00111000, %00000000  ; O
        TUILE_UNIE %11111100, %01100110, %01100110, %01111100, %01100000, %01100000, %11110000, %00000000  ; P
        TUILE_UNIE %11111100, %01100110, %01100110, %01111100, %01101100, %01100110, %11100110, %00000000  ; R
        TUILE_UNIE %01111000, %11001100, %11100000, %01110000, %00011100, %11001100, %01111000, %00000000  ; S
        TUILE_UNIE %11111100, %10110100, %00110000, %00110000, %00110000, %00110000, %01111000, %00000000  ; T
        TUILE_UNIE %11001100, %11001100, %11001100, %11001100, %11001100, %11001100, %01111100, %00000000  ; U

; Le reste des 8 Ko de graphismes est rempli de zéros par l'éditeur de liens.
; Fin du voyage — vous savez maintenant faire défiler DEUX mondes. 🤖
