;
; Memotech Ports
;

P_IOB	EQU	000H		; -o IOBYTE
P_PRTS	EQU	000H		; i- printer strobe
P_VDPD	EQU	001H		; io VDP data
P_VDPC	EQU	002H		; -o VDP control
P_VDPS	EQU	002H		; io VDP status
P_TAPE	EQU	003H		; -o cassette
P_SNDI	EQU	003H		; i- sound
P_PRT	EQU	004H		; io printer
P_KDRV	EQU	005H		; -o keyboard drive
P_KSNS5	EQU	005H		; i- keyboard sense
P_KSNS6	EQU	006H		; i- keyboard sense
P_SNDO	EQU	006H		; -o sound
P_PIO	EQU	007H		; io PIO
P_CTC0	EQU	008H		; io CTC channel 0
P_CTC1	EQU	009H		; io CTC channel 1
P_CTC2	EQU	00AH		; io CTC channel 2
P_CTC3	EQU	00BH		; io CTC channel 3
P_DART0	EQU	00CH		; io DART
P_DART1	EQU	00DH		; io DART
P_DART2	EQU	00EH		; io DART
P_DART3	EQU	00FH		; io DART
P_TAPEC	EQU	01FH		; -o tape motor control
P_BELL	EQU	030H		; i- 80 column bell
P_ADRLO	EQU	030H		; -o 80 column address low
P_ADRHI	EQU	031H		; -o 80 column address high
P_ASCD	EQU	032H		; io 80 column character data
P_ATRD	EQU	033H		; io 80 column attribute data
P_CRTR	EQU	038H		; io 80 column CRTC register select
P_CRTD	EQU	039H		; io 80 column CRTC register data

;
; REMEMOTECH/REMEMOrizer specific ports
;

; Accelerator related ports in later REMEMOrizers and REMEMOTECH
P_MAN0	EQU	0A0H		; IO mantissa bits -24..-31
P_MAN1	EQU	0A1H		; IO mantissa bits -16..-23
P_MAN2	EQU	0A2H		; IO mantissa bits -8..-15
P_MAN3	EQU	0A3H		; IO sign and mantissa bits -1..-7
P_EXP	EQU	0A4H		; IO exponent, + 081H
P_NCMD	EQU	0A5H		; -O command
P_NRES	EQU	0A5H		; I- result

P_HEX10	EQU	0C0H		; io seven segment digits 1 and 0
P_HEX32	EQU	0C1H		; io seven segment digits 3 and 2
P_LEDG	EQU	0C4H		; io green LEDs
P_KEY	EQU	0C5H		; i- keys KEY2..KEY0 (KEY3=reset)
P_XKEY	EQU	0C7H		; i- extra keys, mainly numeric pad
P_PAGE1	EQU	0D0H		; io page register 1
P_PAGE2	EQU	0D1H		; io page register 2
P_SDCTL	EQU	0D4H		; io SD control/status
P_SDDAT	EQU	0D6H		; io SD data
P_SDDAF	EQU	0D7H		; i- SD data, with implied send ff
P_CLK	EQU	0D8H		; i- clock divider
P_RIZER	EQU	0D9H		; io REMEMOrizer flags
P_RIZEQ	EQU	0DAH		; io more REMEMOrizer/REMEMOTECH flags

