# Académie d'Aldemar / cours d'assembleur — commandes racine.
#
#   make roms              construit les 7 ROM (cc65 requis)
#   make test-snes         les 4 batteries SNES (simulateur maison, tests/)
#   make validate-content  contrôle du contenu narratif (docs/narrative/)

JEUX_NES  = casse-brique-nes neo-runner-2026 nova-2026
JEUX_SNES = casse-brique-snes neo-runner-snes nova-snes cristal-2026

roms:
	@for d in $(JEUX_NES) $(JEUX_SNES); do \
	  echo "=== $$d ==="; $(MAKE) -C $$d || exit 1; done

test-snes: roms
	cd tests && python3 smoke_snes.py && python3 smoke_runner_snes.py \
	  && python3 smoke_nova_snes.py && python3 smoke_cristal.py

validate-content:
	python3 tools/validate_content.py

clean:
	@for d in $(JEUX_NES) $(JEUX_SNES); do $(MAKE) -C $$d clean; done

.PHONY: roms test-snes validate-content clean
