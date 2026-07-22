; =============================================================================
;  son.s — LE SON SNES : apprivoiser le SPC700 (module commun aux trois jeux)
; =============================================================================
;
;  La SNES ne fait pas de son. Elle héberge un SECOND ORDINATEUR complet —
;  le SPC700 : son propre processeur, ses 64 Ko de RAM, sa puce de synthèse
;  (le S-DSP, 8 voix d'échantillons). Le 65816 ne peut RIEN y toucher
;  directement : il ne dispose que de 4 boîtes aux lettres ($2140-$2143).
;
;  Pour jouer une note, il faut donc :
;   1. ÉCRIRE UN PROGRAMME POUR LE SPC700 (le "pilote"). Son processeur a
;      son propre langage — ca65 ne l'assemble pas, alors le nôtre est
;      assemblé À LA MAIN, octet par octet, mnémoniques en commentaires.
;      Il tient en 115 octets : lire les boîtes aux lettres, piloter le DSP.
;   2. LE TÉLÉVERSER au démarrage, par le protocole de poignée de main de
;      la ROM d'amorçage du SPC700 (initialiser_son).
;   3. LUI PARLER : voix + hauteur dans les boîtes 0-2, et un compteur
;      dans la boîte 3 pour dire "nouvelle commande". Il accuse réception.
;
;  Nos instruments : une onde CARRÉE (mélodie, bips) et un TRIANGLE
;  (basse), fabriqués comme échantillons BRR d'un seul cycle, bouclés à
;  l'infini — le chiptune par échantillonnage. La voix 3 est configurée en
;  BRUIT par le DSP (percussions, chocs), comme le canal bruit de la NES.
;
;  La hauteur : le DSP rejoue l'échantillon à la vitesse pitch/4096.
;  Notre carré fait 16 échantillons à 32 kHz : pitch = Hz × 2,048.
;  Le la 440 vaut 901. Les tables en bas du fichier font la conversion.
;
;  CONTRAT avec le jeu qui inclut ce fichier : il doit définir les
;  étiquettes `melodie` et `basse` (partitions : note, durée, ..., $FF).
; =============================================================================

.zeropage
snd_cpt:      .res 1    ; le compteur de commandes (boîte 3)
snd_pitch_lo: .res 1    ; la hauteur de la prochaine note
snd_pitch_hi: .res 1
ipl_index:    .res 1    ; l'index du protocole de téléversement
snd_ptr:      .res 2
snd_reste_lo: .res 1
snd_reste_hi: .res 1
mus_active:   .res 1    ; le moteur de musique (le même que sur NES !)
mel_pos:      .res 1
mel_cpt:      .res 1
bas_pos:      .res 1
bas_cpt:      .res 1
bip_cpt:      .res 1    ; durées restantes des effets (voix 2 et 3)
bruit_cpt:    .res 1

.segment "CODE"

; --- Les voix du DSP, telles que le pilote les distribue ----------------------
VOIX_MELODIE = 0        ; onde carrée
VOIX_BASSE   = 1        ; onde triangle
VOIX_BIP     = 2        ; onde carrée (effets et jingles)
VOIX_BRUIT   = 3        ; le générateur de bruit du DSP

; --- Les notes (mêmes numéros que les jeux NES, la conversion en pitch suit) --
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
NOTE_DO6  = 15


; =============================================================================
;  initialiser_son — la poignée de main avec la ROM d'amorçage du SPC700
; =============================================================================
;  À l'allumage, le SPC700 exécute sa petite ROM interne, qui dit "coucou"
;  ($AA $BB sur les boîtes 0-1) et attend qu'on lui dicte un programme.
;  Le rituel, octet par octet, avec accusé de réception à chaque pas.
;  À appeler AVANT d'activer la NMI (le rituel prend quelques millisecondes).

initialiser_son:
        lda #0
        sta snd_cpt
        ; --- Piège de console réelle : le SPC700 SURVIT au reset logiciel ! ---
        ;  Si le jeu redémarre (jmp reset après un game over), la ROM
        ;  d'amorçage ne dira plus jamais "coucou" : notre pilote tourne
        ;  déjà. Il signe sa présence ($EE sur la boîte 1, effaçant le $BB
        ;  de l'amorçage) : dans ce cas, on se recale sur son compteur
        ;  (boîte 0 = son dernier accusé de réception) et c'est tout.
        lda $2141
        cmp #$EE
        bne @coucou_aa
        lda $2140
        sta snd_cpt
        rts
@coucou_aa:
        lda $2140
        cmp #$AA
        bne @coucou_aa
@coucou_bb:
        lda $2141
        cmp #$BB
        bne @coucou_bb
        lda #$01                ; "je vais t'envoyer des données..."
        sta $2141
        lda #$00                ; "...à ranger à l'adresse $0200"
        sta $2142
        lda #$02
        sta $2143
        lda #$CC                ; "prêt ?"
        sta $2140
@pret:
        lda $2140
        cmp #$CC                ; "prêt !"
        bne @pret

        lda #<pilote_spc
        sta snd_ptr
        lda #>pilote_spc
        sta snd_ptr+1
        lda #<(fin_pilote_spc - pilote_spc)
        sta snd_reste_lo
        lda #>(fin_pilote_spc - pilote_spc)
        sta snd_reste_hi
        stz ipl_index
        ldy #0
@envoyer:
        lda (snd_ptr), y        ; l'octet...
        sta $2141
        lda ipl_index           ; ...et son numéro d'ordre, qui déclenche
        sta $2140
@accuse:
        cmp $2140               ; le SPC répète le numéro : bien reçu
        bne @accuse
        inc ipl_index
        iny
        bne @page_ok
        inc snd_ptr+1
@page_ok:
        lda snd_reste_lo
        bne @dec_ok
        dec snd_reste_hi
@dec_ok:
        dec snd_reste_lo
        lda snd_reste_lo
        ora snd_reste_hi
        bne @envoyer

        lda #$00                ; "terminé : saute à $0200 et joue !"
        sta $2141
        lda #$00
        sta $2142
        lda #$02
        sta $2143
        lda ipl_index
        clc
        adc #2                  ; un saut se signale par index + 2 (au moins)
        sta $2140
@parti:
        cmp $2140
        bne @parti
        rts


; =============================================================================
;  jouer_voix — une commande au pilote : A = voix, snd_pitch = hauteur
;  (hauteur nulle = couper la voix). Attend l'accusé de réception.
; =============================================================================
jouer_voix:
        sta $2140
        lda snd_pitch_lo
        sta $2141
        lda snd_pitch_hi
        sta $2142
        inc snd_cpt
        lda snd_cpt
        sta $2143
@accuse:
        cmp $2140
        bne @accuse
        rts

; jouer_note : A = numéro de note, X = voix
jouer_note:
        tay
        lda notes_pitch_lo, y
        sta snd_pitch_lo
        lda notes_pitch_hi, y
        sta snd_pitch_hi
        txa
        jmp jouer_voix

; couper_voix : X = voix
couper_voix:
        stz snd_pitch_lo
        stz snd_pitch_hi
        txa
        jmp jouer_voix


; =============================================================================
;  LE MOTEUR DE MUSIQUE — celui de la NES, note pour note. Seule différence :
;  au lieu d'écrire des registres APU, on télégraphie au SPC700.
; =============================================================================
demarrer_musique:
        lda #1
        sta mus_active
        sta mel_cpt
        sta bas_cpt
        stz mel_pos
        stz bas_pos
        rts

arreter_musique:
        stz mus_active
        ldx #VOIX_MELODIE
        jsr couper_voix
        ldx #VOIX_BASSE
        jmp couper_voix

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
        phx
        ldx #VOIX_MELODIE
        jsr jouer_note          ; (la note 0 est un silence : pitch nul)
        plx
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
        phx
        ldx #VOIX_BASSE
        jsr jouer_note
        plx
        inx
        lda basse, x
        sta bas_cpt
        inx
        stx bas_pos
@fin:
        rts


; =============================================================================
;  LES EFFETS — un bip (voix 2) et un bruit (voix 3), coupés à l'échéance
; =============================================================================
; A = numéro de note, Y = durée en images
jouer_bip:
        sty bip_cpt
        ldx #VOIX_BIP
        jmp jouer_note

; Y = durée en images (le "timbre" du bruit est réglé par le pilote)
jouer_bruit:
        sty bruit_cpt
        lda #$00
        sta snd_pitch_lo
        lda #$04                ; une hauteur non nulle : "allume la voix"
        sta snd_pitch_hi
        lda #VOIX_BRUIT
        jmp jouer_voix

maj_bruitages:
        lda bip_cpt
        beq @bruit
        dec bip_cpt
        bne @bruit
        ldx #VOIX_BIP
        jsr couper_voix
@bruit:
        lda bruit_cpt
        beq @fin
        dec bruit_cpt
        bne @fin
        ldx #VOIX_BRUIT
        jsr couper_voix
@fin:
        rts


; =============================================================================
;  LES TABLES DE HAUTEURS — pitch = Hz × 2,048 (carré de 16 échantillons)
; =============================================================================
;  ATTENTION, piège d'assembleur vécu : chaque table doit être COMPLÈTE avant
;  que la suivante ne commence. Écrire lo(0-7), hi(0-7), lo(8-15), hi(8-15)
;  compile très bien... et joue n'importe quoi à partir de la note 8, car
;  notes_pitch_lo+9 tombe alors dans la table des octets hauts !
;                     sil   fa2   sol2  la2   do3   fa4   sol4  la4
notes_pitch_lo: .byte $00,  $B3,  $C9,  $E1,  $0C,  $CB,  $23,  $85
;                     si4   do5   ré5   mi5   fa5   sol5  la5   do6
                .byte $F3,  $30,  $B3,  $46,  $96,  $46,  $0A,  $5F
notes_pitch_hi: .byte $00,  $00,  $00,  $00,  $01,  $02,  $03,  $03
                .byte $03,  $04,  $04,  $05,  $05,  $06,  $07,  $08


; =============================================================================
;  LE PILOTE SPC700 — 115 octets, assemblés à la main
; =============================================================================
;  Il vit en $0200 dans la RAM du SPC700. Après avoir configuré le DSP
;  (table plus bas), il boucle : nouvelle commande ? → hauteur nulle : key
;  off ; sinon : régler le pitch de la voix et key on. Puis il répète le
;  compteur sur la boîte 0 : l'accusé de réception qu'attend jouer_voix.
;  Les registres $F2/$F3 sont sa porte vers le DSP, $F4-$F7 les boîtes.

pilote_spc:
        ; --- $0200 : signer sa présence (voir initialiser_son) ---
        .byte $E8, $EE              ; mov a,#$EE
        .byte $C4, $F5              ; mov $F5,a       ("pilote en place !")
        ; --- configurer le DSP depuis la table ---
        .byte $CD, $00              ; mov x,#0
        .byte $F5, $B0, $02         ; @table:  mov a,!$02B0+x   (registre)
        .byte $68, $FF              ;          cmp a,#$FF
        .byte $F0, $0B              ;          beq @sync
        .byte $C4, $F2              ;          mov $F2,a
        .byte $3D                   ;          inc x
        .byte $F5, $B0, $02         ;          mov a,!$02B0+x   (valeur)
        .byte $C4, $F3              ;          mov $F3,a
        .byte $3D                   ;          inc x
        .byte $2F, $EE              ;          bra @table
        ; --- $0214 : se caler sur le compteur du 65816 ---
        .byte $E4, $F7              ; @sync:   mov a,$F7
        .byte $C4, $00              ;          mov $00,a
        ; --- $0218 : LA BOUCLE ---
        .byte $E4, $F7              ; @boucle: mov a,$F7        (boîte 3)
        .byte $64, $00              ;          cmp a,$00
        .byte $F0, $FA              ;          beq @boucle      (rien de neuf)
        .byte $C4, $00              ;          mov $00,a
        .byte $E4, $F4              ;          mov a,$F4        (la voix)
        .byte $28, $03              ;          and a,#3
        .byte $C4, $01              ;          mov $01,a
        .byte $1C, $1C, $1C, $1C    ;          asl ×4 : voix×16
        .byte $C4, $02              ;          mov $02,a        (base DSP)
        .byte $F8, $01              ;          mov x,$01
        .byte $F5, $A0, $02         ;          mov a,!$02A0+x   (1<<voix)
        .byte $C4, $03              ;          mov $03,a
        .byte $E4, $F5              ;          mov a,$F5        (pitch bas)
        .byte $C4, $04              ;          mov $04,a
        .byte $E4, $F6              ;          mov a,$F6        (pitch haut)
        .byte $C4, $05              ;          mov $05,a
        .byte $04, $04              ;          or a,$04
        .byte $D0, $0E              ;          bne @note        (pitch ≠ 0)
        .byte $E8, $5C              ;          mov a,#$5C       (KOF)
        .byte $C4, $F2              ;          mov $F2,a
        .byte $E4, $03              ;          mov a,$03
        .byte $C4, $F3              ;          mov $F3,a        (silence !)
        .byte $E4, $00              ;          mov a,$00
        .byte $C4, $F4              ;          mov $F4,a        (accusé)
        .byte $2F, $CB              ;          bra @boucle
        .byte $E4, $02              ; @note:   mov a,$02
        .byte $08, $02              ;          or a,#2          (reg pitch L)
        .byte $C4, $F2              ;          mov $F2,a
        .byte $E4, $04              ;          mov a,$04
        .byte $C4, $F3              ;          mov $F3,a
        .byte $E4, $02              ;          mov a,$02
        .byte $08, $03              ;          or a,#3          (reg pitch H)
        .byte $C4, $F2              ;          mov $F2,a
        .byte $E4, $05              ;          mov a,$05
        .byte $C4, $F3              ;          mov $F3,a
        .byte $E8, $4C              ;          mov a,#$4C       (KON)
        .byte $C4, $F2              ;          mov $F2,a
        .byte $E4, $03              ;          mov a,$03
        .byte $C4, $F3              ;          mov $F3,a        (la note part)
        .byte $E4, $00              ;          mov a,$00
        .byte $C4, $F4              ;          mov $F4,a        (accusé)
        .byte $2F, $A9              ;          bra @boucle

        ; --- $02A0 : les masques 1<<voix ---
        .res $A0 - (* - pilote_spc)
        .byte $01, $02, $04, $08
        ; --- $02B0 : la table d'initialisation du DSP (registre, valeur) ---
        .res $B0 - (* - pilote_spc)
        .byte $6C, $2D              ; FLG : écho coupé, horloge du bruit
        .byte $5C, $00              ; KOF : personne
        .byte $0C, $60, $1C, $60    ; volume général
        .byte $2C, $00, $3C, $00    ; écho : volume nul
        .byte $2D, $00              ; pas de modulation
        .byte $3D, $08              ; NON : la voix 3 est du BRUIT
        .byte $4D, $00              ; écho : aucune voix
        .byte $5D, $03              ; DIR : les échantillons sont page $03
        .byte $6D, $0F, $7D, $00, $0D, $00
        .byte $00, $30, $01, $30, $04, $00, $05, $00, $07, $7F   ; voix 0
        .byte $10, $50, $11, $50, $14, $01, $15, $00, $17, $7F   ; voix 1
        .byte $20, $38, $21, $38, $24, $00, $25, $00, $27, $7F   ; voix 2
        .byte $30, $28, $31, $28, $34, $00, $35, $00, $37, $7F   ; voix 3
        .byte $FF
        ; --- $0300 : le répertoire des échantillons (début, boucle) ---
        .res $100 - (* - pilote_spc)
        .word $0310, $0310          ; échantillon 0 : le carré
        .word $0319, $0319          ; échantillon 1 : le triangle
        ; --- $0310 : l'onde CARRÉE en BRR : UN bloc de 16 échantillons,
        ;     bouclé pour toujours. 8 valeurs hautes, 8 basses : le carré !
        .res $110 - (* - pilote_spc)
        .byte $A3                   ; en-tête : gamme 10, fin + boucle
        .byte $77, $77, $77, $77, $99, $99, $99, $99
        ; --- $0319 : le TRIANGLE : 32 échantillons en 2 blocs ---
        .byte $A0                   ; gamme 10, on continue...
        .byte $01, $23, $45, $67, $76, $54, $32, $10
        .byte $A3                   ; ...fin + boucle
        .byte $0F, $ED, $CB, $A9, $9A, $BC, $DE, $F0
fin_pilote_spc:
