# Académie d'Aldemar / cours d'assembleur NES-SNES

> **Personne ne gagne une discussion. Seul le jeu gagne.**

Ce dépôt contient (1) un cours progressif d'assembleur 6502/65816 en
français — six jeux NES et SNES complets — et (2) le chantier du JRPG
narratif **Académie d'Aldemar**, construit sur la fondation
`cristal-2026/`.

Les règles opérationnelles complètes de Claude Code (rôles, limites
d'autorité narrative, workflow, commandes) : **[.claude/CLAUDE.md](.claude/CLAUDE.md)**.
La mémoire du projet : **[docs/README.md](docs/README.md)**.

## L'essentiel

- Trois rôles : Maxime (Creative Director), ChatGPT (Narrative
  Director), Claude Code (Technical Director). Claude ne modifie JAMAIS
  le sens narratif de sa propre initiative : review dans `docs/reviews/`.
- Rien ne s'implémente avant `status: approved` ; rien n'est définitif
  avant un ADR « Accepté » (`docs/decisions/`).
- Style du code : assembleur commenté EN FRANÇAIS, pédagogique,
  data-driven — le dépôt reste un cours.

## Commandes vérifiées

```bash
make roms               # construit les 7 ROM
make test-snes          # les 4 batteries SNES (simulateur maison, tests/)
make validate-content   # validateur du contenu narratif (PyYAML)
make -C cristal-2026    # un seul jeu (pareil pour chaque dossier de jeu)
```
