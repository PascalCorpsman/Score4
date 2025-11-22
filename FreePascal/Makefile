TARGETS=score4

all:	$(TARGETS)

score4: score4.lpr
	fpc -o$@ $<

clean:
	@rm -rf $(TARGETS)
	@rm -rf *.o

include ../Makefile.common

test:	|all
	@echo -n 'Benchmarking imperative FreePascal ...'
	@BINARY=./score4 make -s speedtest


