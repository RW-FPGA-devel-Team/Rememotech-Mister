#
# REMEMOTECH firmware
#

MEDIA =		/dev/sdc

#

all:		flash.bin sddisc.bin sddisc2.bin

# The image itself

flash.bin:	ACPM.BIN SDX.BIN REMON.BIN ramdisc.bin
		dd if=/dev/zero count=64 bs=1k  > $@ 2> /dev/null
		dd if=basic.rom                >> $@ 2> /dev/null
		dd if=assem.rom                >> $@ 2> /dev/null
		dd if=/dev/zero count=16 bs=1k >> $@ 2> /dev/null
		dd if=ACPM.BIN                 >> $@ 2> /dev/null
		dd if=SDX.BIN                  >> $@ 2> /dev/null
		dd if=/dev/zero count=8  bs=1k >> $@ 2> /dev/null
		dd if=/dev/zero count=8  bs=1k >> $@ 2> /dev/null
		dd if=os-sdx.rom               >> $@ 2> /dev/null
		dd if=REMON.BIN                >> $@ 2> /dev/null
		dd if=/dev/zero count=48 bs=1k >> $@ 2> /dev/null
		dd if=ramdisc.bin              >> $@ 2> /dev/null

# The REMEMOTECH monitor

REMON.BIN:	REMON.REL
		memu -mc -fast cpmfiles/L80.COM REMON,REMON.BIN/N/Y/E

REMON.REL:	REMON.MAC PORTS.INC
		@unix2dos -q REMON.MAC
		@unix2dos -q PORTS.INC
		memu -mc -fast cpmfiles/M80.COM =REMON

# The CP/M boot ROM

ACPM.BIN:	AZMON.REL ASDXKBD.REL ACRT.REL ARAM.REL ASDCARD.REL
		memu -mc -fast cpmfiles/L80.COM AZMON,ASDXKBD,ACRT,ARAM,ASDCARD,ACPM.BIN/N/Y/E

AZMON.REL:	AZMON.MAC
		@unix2dos -q AZMON.MAC
		memu -mc -fast cpmfiles/M80.COM =AZMON

ASDXKBD.REL:	ASDXKBD.MAC
		@unix2dos -q ASDXKBD.MAC
		memu -mc -fast cpmfiles/M80.COM =ASDXKBD

ACRT.REL:	ACRT.MAC
		@unix2dos -q ACRT.MAC
		memu -mc -fast cpmfiles/M80.COM =ACRT

ARAM.REL:	ARAM.MAC
		@unix2dos -q ARAM.MAC
		memu -mc -fast cpmfiles/M80.COM =ARAM

ASDCARD.REL:	ASDCARD.MAC
		@unix2dos -q ASDCARD.MAC
		memu -mc -fast cpmfiles/M80.COM =ASDCARD

#

SDX.BIN:	SDXMAIN.REL SDXFDSC.REL SDXBAS.REL SDXFMT.REL SDXSTAT.REL SDXSD.REL SDXRAM.REL SDXEND.REL
		memu -mc -fast cpmfiles/L80.COM /P:2000,SDXMAIN,SDXFDSC,SDXBAS,SDXFMT,SDXSTAT,SDXSD,SDXRAM,SDXEND,SDX.OUT/N/Y/E
		dd if=SDX.OUT of=SDX.BIN bs=256 skip=31 count=32
		@rm SDX.OUT

SDXMAIN.REL:	SDXMAIN.MAC BDOS.INC BASIC.INC SYSVARS.INC SDXCONF.INC SDXHIGH.INC
		@unix2dos -q SDXMAIN.MAC
		@unix2dos -q BDOS.INC
		@unix2dos -q BASIC.INC
		@unix2dos -q SYSVARS.INC
		@unix2dos -q SDXCONF.INC
		@unix2dos -q SDXHIGH.INC
		memu -mc -fast cpmfiles/M80.COM =SDXMAIN

SDXFDSC.REL:	SDXFDSC.MAC SDXCONF.INC SDXHIGH.INC
		@unix2dos -q SDXFDSC.MAC
		@unix2dos -q SDXCONF.INC
		@unix2dos -q SDXHIGH.INC
		memu -mc -fast cpmfiles/M80.COM =SDXFDSC

SDXBAS.REL:	SDXBAS.MAC BDOS.INC BASIC.INC SYSVARS.INC SDXCONF.INC SDXHIGH.INC
		@unix2dos -q SDXBAS.MAC
		@unix2dos -q BDOS.INC
		@unix2dos -q BASIC.INC
		@unix2dos -q SDXCONF.INC
		@unix2dos -q SYSVARS.INC
		@unix2dos -q SDXHIGH.INC
		memu -mc -fast cpmfiles/M80.COM =SDXBAS

SDXFMT.REL:	SDXFMT.MAC SDXCONF.INC
		@unix2dos -q SDXFMT.MAC
		@unix2dos -q SDXCONF.INC
		memu -mc -fast cpmfiles/M80.COM =SDXFMT

SDXSTAT.REL:	SDXSTAT.MAC BDOS.INC BASIC.INC SYSVARS.INC SDXCONF.INC SDXHIGH.INC
		@unix2dos -q SDXSTAT.MAC
		@unix2dos -q BDOS.INC
		@unix2dos -q BASIC.INC
		@unix2dos -q SDXCONF.INC
		@unix2dos -q SYSVARS.INC
		@unix2dos -q SDXHIGH.INC
		memu -mc -fast cpmfiles/M80.COM =SDXSTAT

SDXSD.REL:	SDXSD.MAC PORTS.INC SDXCONF.INC SDXHIGH.INC
		@unix2dos -q SDXSD.MAC
		@unix2dos -q PORTS.INC
		@unix2dos -q SDXCONF.INC
		@unix2dos -q SDXHIGH.INC
		memu -mc -fast cpmfiles/M80.COM =SDXSD

SDXRAM.REL:	SDXRAM.MAC SYSVARS.INC SDXCONF.INC SDXHIGH.INC
		@unix2dos -q SDXRAM.MAC
		@unix2dos -q SDXCONF.INC
		@unix2dos -q SYSVARS.INC
		@unix2dos -q SDXHIGH.INC
		memu -mc -fast cpmfiles/M80.COM =SDXRAM

SDXEND.REL:	SDXEND.MAC
		@unix2dos -q SDXEND.MAC
		memu -mc -fast cpmfiles/M80.COM =SDXEND

# An initial RAM disk image

ramdisc.bin:	RECONFIG.COM REFORMAT.COM RETAPE.COM RENUMT.COM RENUM.COM cpmfiles/*
		cp RECONFIG.COM REFORMAT.COM RETAPE.COM RENUMT.COM RENUM.COM cpmfiles
		dd if=/dev/zero count=320 bs=1k > $@ 2> /dev/null
		mkfs.cpm -f memotech-type52 -b boot59.dat $@
		./startup.sh $@ "RECONFIG F:52,B:18,C:19,D:1A,E:1B"
		cpmcp -f memotech-type52 $@ cpmfiles/* 0:

# A sample SD Card disk image

sddisc.bin:	RECONFIG.COM REFORMAT.COM RETAPE.COM RENUMT.COM RENUM.COM cpmfiles/* cpmfiles2/*
		cp RECONFIG.COM REFORMAT.COM RETAPE.COM RENUMT.COM RENUM.COM cpmfiles
		dd if=/dev/zero count=8192 bs=1k > $@ 2> /dev/null
		mkfs.cpm -f memotech-type18 -b boot59.dat $@
		cpmcp -f memotech-type18 $@ cpmfiles/* 0:
		cpmcp -f memotech-type18 $@ cpmfiles2/* 0:

# Another sample SD Card disk image

sddisc2.bin:	RECONFIG.COM REFORMAT.COM RETAPE.COM RENUMT.COM RENUM.COM cpmfiles/* cpmfiles3/*
		cp RECONFIG.COM REFORMAT.COM RETAPE.COM RENUMT.COM RENUM.COM cpmfiles
		dd if=/dev/zero count=8192 bs=1k > $@ 2> /dev/null
		mkfs.cpm -f memotech-type18 -b boot54.dat $@
		cpmcp -f memotech-type18 $@ cpmfiles/* 0:
		cpmcp -f memotech-type18 $@ cpmfiles3/* 0:

# RECONFIG and REFORMAT

RECONFIG.COM:	RECONFIG.REL
		memu -mc -fast cpmfiles/L80.COM RECONFIG,RECONFIG/N/Y/E

RECONFIG.REL:	RECONFIG.MAC
		@unix2dos -q RECONFIG.MAC
		memu -mc -fast cpmfiles/M80.COM =RECONFIG

REFORMAT.COM:	REFORMAT.REL
		memu -mc -fast cpmfiles/L80.COM REFORMAT,REFORMAT/N/Y/E

REFORMAT.REL:	REFORMAT.MAC
		@unix2dos -q REFORMAT.MAC
		memu -mc -fast cpmfiles/M80.COM =REFORMAT

# RETAPE

RETAPE.COM:	RETAPE.REL
		memu -mc -fast cpmfiles/L80.COM RETAPE,RETAPE/N/Y/E

RETAPE.REL:	RETAPE.MAC
		@unix2dos -q RETAPE.MAC
		@unix2dos -q PORTS.INC
		memu -mc -fast cpmfiles/M80.COM =RETAPE

# RENUMT

RENUMT.COM:	RENUMT.REL
		memu -mc -fast cpmfiles/L80.COM RENUMT,RENUMT/N/Y/E

RENUMT.REL:	RENUMT.MAC PORTS.INC NUMACCEL.INC
		@unix2dos -q PORTS.INC
		@unix2dos -q NUMACCEL.INC
		@unix2dos -q RENUMT.MAC
		memu -mc -fast cpmfiles/M80.COM =RENUMT

# RENUM

RENUM.COM:	RENUM.REL
		memu -mc -fast cpmfiles/L80.COM RENUM,RENUM/N/Y/E

RENUM.REL:	RENUM.MAC PORTS.INC NUMACCEL.INC
		@unix2dos -q PORTS.INC
		@unix2dos -q NUMACCEL.INC
		@unix2dos -q RENUM.MAC
		memu -mc -fast cpmfiles/M80.COM =RENUM

#

clean:
		@rm *.bin *.REL *.BIN

#

write-flash:
		dd if=flash.bin of=$(MEDIA)

#

write-sddisc:
		dd if=sddisc.bin of=$(MEDIA)
		dd if=sddisc2.bin of=$(MEDIA) bs=8M seek=1
