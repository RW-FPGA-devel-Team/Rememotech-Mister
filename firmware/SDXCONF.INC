;
; SDX ROM configuration
;

; One of these can be selected
FDXFDC	EQU	0
SDXFDC	EQU	0

; One of these must be selected
DRVB03	EQU	0
DRVB07	EQU	0
DRVB18	EQU	1			; for REMEMOTECH or REMEMOrizer

; One of these can be selected
DRVC03	EQU	0			; only use with DRVB03
DRVC07	EQU	0			; only use with DRVB07 - !!! UNSAFE !!!

; One of these can be selected
DRVF51	EQU	0
DRVF52	EQU	1			; for REMEMOTECH or REMEMOrizer or SDX Plus

; The original ROM wasted space
WASTAGE	EQU	0

; One of these must be selected
CLK50	EQU	1			; select if REMEMOTECH
CLK4	EQU	0			; select otherwise

;

	IFT FDXFDC+SDXFDC GT 1
	.PRINTX /!!! At most one choice for FDC must be made!!!/
	ENDIF

	IFT ( FDXFDC+SDXFDC EQ 0 ) AND ( DRVB03 OR DRVB07 OR DRVC03 OR DRVC07 )
	.PRINTX /!!! Can't support floppy drive without FDC!!!/
	ENDIF

	IFT DRVB03+DRVB07+DRVB18 NE 1
	.PRINTX /!!! Exactly one choice for B: must be made!!!/
	ENDIF

	IFT DRVC03+DRVC07 GT 1
	.PRINTX /!!! At most one choice for C: can be made!!!/
	ENDIF

	IFT DRVC03 AND DRVB07
	.PRINTF /!!! If C: is supported, it must agree with B:!!!/
	ENDIF
	IFT DRVC03 AND DRVB18
	.PRINTF /!!! If C: is supported, it must agree with B:!!!/
	ENDIF
	IFT DRVC07 AND DRVB03
	.PRINTF /!!! If C: is supported, it must agree with B:!!!/
	ENDIF
	IFT DRVC07 AND DRVB18
	.PRINTF /!!! If C: is supported, it must agree with B:!!!/
	ENDIF

	IFT DRVF51 AND DRVF52
	.PRINTX /!!! At most one choice for F: can be made!!!/
	ENDIF

	IFT CLK50+CLK4 NE 1
	.PRINTX /!!! Exactly one choice of SD card clock speed must be made!!!/
	ENDIF

