# -------------------------------------
#  This make file is for compiling the 
#  z80 SBC assemply code
#
#  Use:
#    clean      - clean environment
#    all        - build all outputs
#    bin        - build binary output
#    srec       - build S-record output
#
#    all output build will create a listing file
#
# -------------------------------------

#
# change log
# -------------------
# 05/18/2014        created
#

BINDIR = .
DEPENDENCIES = int32K.asm bas32K.asm

#DEBUG = NONE

all : bin srec

bin : z80sbc.bin

srec : z80sbc.srec

z80sbc.bin : $(DEPENDENCIES)
	./z80asm.sh -v -b -l -nm -o$@ $?

z80sbc.srec : z80sbc.bin
	# add: tool to conver z80sbc.bin to z80sbc.srec

.PHONY : CLEAN
clean :
	rm -f $(BINDIR)/*obj
	rm -f $(BINDIR)/*srec
	rm -f $(BINDIR)/*lst
	rm -f $(BINDIR)/*err
	rm -f $(BINDIR)/*bin

