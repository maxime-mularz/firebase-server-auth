# =============================================================================
#  Makefile — voir le casse-brique pour les explications (ca65 puis ld65)
# =============================================================================
#  Utilisation :   make          → construit neo-runner.nes
#                  make clean    → supprime les fichiers générés

ROM = neo-runner.nes

$(ROM): neo-runner.o nes.cfg
	ld65 -C nes.cfg -o $@ neo-runner.o

neo-runner.o: src/neo-runner.s
	ca65 --cpu 6502 -o $@ $<

clean:
	rm -f neo-runner.o $(ROM)

.PHONY: clean
