# =============================================================================
#  Makefile — compile le jeu en deux étapes
# =============================================================================
#  1. ca65 : l'ASSEMBLEUR. Il traduit le texte (casse-brique.s) en code
#     machine, dans un fichier "objet" (.o).
#  2. ld65 : l'ÉDITEUR DE LIENS. Il range ce code aux bonnes adresses
#     (d'après nes.cfg) et produit la cartouche finale : casse-brique.nes.
#
#  Utilisation :   make          → construit casse-brique.nes
#                  make clean    → supprime les fichiers générés

ROM = casse-brique.nes

$(ROM): casse-brique.o nes.cfg
	ld65 -C nes.cfg -o $@ casse-brique.o

casse-brique.o: src/casse-brique.s
	ca65 --cpu 6502 -o $@ $<

clean:
	rm -f casse-brique.o $(ROM)

.PHONY: clean
