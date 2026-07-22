# Casse-brique SNES : atelier graphique -> assemblage -> edition de liens
# -> sommes de controle de l'en-tete. Produit casse-brique.sfc.
ROM = casse-brique.sfc

$(ROM): main.o snes.cfg
	ld65 -C snes.cfg -o $@ main.o
	python3 tools/checksum.py $@

main.o: src/main.s gfx_bg.bin
	ca65 --cpu 65816 -o $@ src/main.s

gfx_bg.bin: tools/make_gfx.py
	python3 tools/make_gfx.py

clean:
	rm -f main.o $(ROM) gfx_bg.bin gfx_obj.bin palettes.bin gradient.bin

.PHONY: clean
