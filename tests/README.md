# Les batteries de tests

Chaque ROM du dépôt est vérifiée par un simulateur maison qui EXÉCUTE la
cartouche : CPU 65816 (sous-ensemble, modes 8/16 bits), PPU (rendu PNG),
DMA/HDMA, APU (le blob SPC700 téléversé est réellement interprété),
SRAM transmissible entre instances (cycle d'alimentation simulé).

```bash
make test-snes            # depuis la racine : les 4 batteries SNES
python3 smoke_cristal.py  # depuis tests/ : une batterie seule
```

| Fichier | Cible |
|---|---|
| sim_snes.py | le simulateur SNES commun |
| smoke_snes.py | casse-brique-snes |
| smoke_runner_snes.py | neo-runner-snes |
| smoke_nova_snes.py | nova-snes |
| smoke_cristal.py | cristal-2026 (fondation RPG : banques, SRAM, 16 bits) |

Dépendances : Python 3, Pillow, PyYAML (validateur). Les batteries NES
historiques (py65) restent à rapatrier — voir docs/technical/build_and_run.md.

Règle : `/implement-scene` ajoute une assertion par critère
d'acceptation de la scène. Une batterie rouge bloque la PR.
