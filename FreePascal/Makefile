TARGETS=score4

all:	$(TARGETS)

# Optimiere aggressiv und schalte Range/Overflow-Checks ab
FPCFLAGS = -O3 -Cr- -Co-

all: $(TARGETS)

score4: score4.lpr
	fpc $(FPCFLAGS) -o$@ $<

clean:
	@rm -rf $(TARGETS)
	@rm -rf *.o

include ../Makefile.common

test:	|all
	@echo -n 'Benchmarking imperative FreePascal ...'
	@BINARY=./score4 make -s speedtest


