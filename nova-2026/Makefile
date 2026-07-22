# Compile NOVA-2026 (voir le casse-brique pour les explications)
ROM = nova.nes

$(ROM): nova.o nes.cfg
	ld65 -C nes.cfg -o $@ nova.o

nova.o: src/nova.s
	ca65 --cpu 6502 -o $@ $<

clean:
	rm -f nova.o $(ROM)

.PHONY: clean
