# CRISTAL-2026 : atelier graphique -> assemblage -> edition de liens
# -> sommes de controle. Produit cristal.sfc (256 Ko, SRAM 8 Ko a pile).
ROM = cristal.sfc

$(ROM): main.o snes.cfg
	ld65 -C snes.cfg -o $@ main.o
	python3 tools/checksum.py $@

main.o: src/main.s ../snes-commun/son.s gfx_bg.bin
	ca65 --cpu 65816 -I ../snes-commun -o $@ src/main.s

gfx_bg.bin: tools/make_gfx.py
	python3 tools/make_gfx.py

clean:
	rm -f main.o $(ROM) gfx_bg.bin gfx_bg3.bin gfx_obj.bin palettes.bin gradient.bin

.PHONY: clean
