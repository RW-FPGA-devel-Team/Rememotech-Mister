reboot.vhd:	REBOOT.BIN
		bin2vhdl REBOOT.BIN > reboot.vhd

REBOOT.BIN:	REBOOT.REL
		memu -mc -fast ../firmware/cpmfiles/L80.COM REBOOT,REBOOT.BIN/N/Y/E

REBOOT.REL:	REBOOT.MAC PORTS.INC
		@unix2dos -q REBOOT.MAC
		@unix2dos -q PORTS.INC
		memu -mc -fast ../firmware/cpmfiles/M80.COM =REBOOT
