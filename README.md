# Académie d'Aldemar — et le cours d'assembleur qui le porte

Deux choses vivent ici :

1. **Un cours d'assembleur 6502/65816 en français**, par la pratique :
   six jeux complets, testés et documentés.
2. **Le chantier du JRPG narratif « Académie d'Aldemar »** (SNES réelle),
   construit sur la fondation technique `cristal-2026/`.

## Le cours (dans l'ordre)

| Niveau | Jeu | Machine | Leçons clés |
|---|---|---|---|
| 1 | [casse-brique-nes](casse-brique-nes/) | NES | PPU, sprites, APU, virgule fixe |
| 2 | [neo-runner-2026](neo-runner-2026/) | NES | défilement, sprite 0, niveaux en données |
| 3 | [nova-2026](nova-2026/) | NES | défilement vertical, LFSR, pools d'objets |
| 4 | [casse-brique-snes](casse-brique-snes/) | SNES | 65816, DMA/HDMA, palettes par case |
| 5 | [neo-runner-snes](neo-runner-snes/) | SNES | tilemap 64×32, BG3 fixe |
| 6 | [nova-snes](nova-snes/) + [snes-commun](snes-commun/) | SNES | BG1VOFS 16 bits, **SPC700** |
| 7 | [cristal-2026](cristal-2026/) | SNES | banques, SRAM, 16 bits, division matérielle |

## Le projet Aldemar

- La mémoire du projet : **[docs/](docs/README.md)** (vision, narration,
  gameplay, technique, reviews, décisions).
- Les rôles et le workflow : [.claude/roles.md](.claude/roles.md),
  [.claude/workflow.md](.claude/workflow.md).

## Commandes

```bash
make roms               # construit les 7 ROM (cc65 requis)
make test-snes          # les batteries de tests (simulateur maison)
make validate-content   # contrôle du contenu narratif
```

> Personne ne gagne une discussion. Seul le jeu gagne.
