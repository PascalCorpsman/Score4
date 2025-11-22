TARGETS=testbench

all:	$(TARGETS)

testbench: testbench.lpr
	fpc -o$@ $<

clean:
	@rm -rf $(TARGETS)
	@rm -rf *.o
	@rm -rf c_record.txt

record: | all
	@./$(TARGETS) ../C/score4 c_record.txt $(RUNS)

test: | all
	@./$(TARGETS) ../$(DUT) c_record.txt

