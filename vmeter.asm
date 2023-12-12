;
;	PIC12F675 LED Voltmeter
;
;	Apr., 29, 2005 ChuckTimber
;
;	$Id: vmeter.asm,v 1.2 2005/11/24 02:53:11 ChuckTimber Exp $

list		p=12f675		; list directive to define processor
#include	<p12f675.inc>	; processor specific variable definitions

__CONFIG	_CP_OFF & _CPD_OFF & _BODEN_ON & _MCLRE_OFF & _WDT_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT 

PWM_FRAME	equ		d'41'
bRED		equ		0	; GPIO bit 0
bGREEN		equ		1	; GPIO bit 1
bBLUE		equ		2	; GPIO bit 2
bADFLG		equ		0	; AD_FLAG
bLOGIC		equ		1	; LED 0:source/1:sink from GP3

; variables
	CBLOCK	 H'20'	;
	WTEMP
	STATUSTEMP
	frame_cnt
	color_out
	red
	green
	blue
	red_tmp
	green_tmp
	blue_tmp
	ad_tmp
	flag
	ENDC

; objects
	org	0x000
	goto	INIT
	org 0x004
;	goto	ISR

ISR
PUSHD
	movwf	WTEMP		;SAVE CONTEXT
	swapf	STATUS, W
	clrf	STATUS
	movwf	STATUSTEMP	;
T0ISR
	nop
	bcf		INTCON,T0IF		; clear timer0 interrupt
	movlw	d'256' - d'64' + d'12'	; 64d cnt, ovhead 15
	movwf	TMR0
	decfsz	frame_cnt,f
	goto	LED_PROC
	movlw	PWM_FRAME		; reset frame counter
	movwf	frame_cnt
	bsf		flag, bADFLG
	movf	red, W			; reset RED_tmp
	movwf	red_tmp
	movf	green, W		; reset GREEN_tmp
	movwf	green_tmp
	movf	blue, W			; reset BLUE_tmp
	movwf	blue_tmp

LED_PROC
PROC_RED
	movf	red_tmp, F
	btfss	STATUS, Z
	goto	PROC_RED_ON
	bcf		color_out, bRED
	goto	PROC_GREEN
PROC_RED_ON
	decfsz	red_tmp, F
	bsf		color_out, bRED

PROC_GREEN
	movf	green_tmp, F
	btfss	STATUS, Z
	goto	PROC_GREEN_ON
	bcf		color_out, bGREEN
	goto	PROC_BLUE
PROC_GREEN_ON
	decfsz	green_tmp, F
	bsf		color_out, bGREEN

PROC_BLUE
	movf	blue_tmp, F
	btfss	STATUS, Z
	goto	PROC_BLUE_ON
	bcf		color_out, bBLUE
	goto	PROC_COLOR
PROC_BLUE_ON
	decfsz	blue_tmp, F
	bsf		color_out, bBLUE

PROC_COLOR
	movf	color_out, W
	btfsc	flag, bLOGIC
	comf	color_out, W
	andlw	b'00000111'
	movwf	GPIO

POPD
	swapf	STATUSTEMP, W	;RESTORE CONTEXT
	movwf	STATUS
	swapf	WTEMP, F
	swapf	WTEMP, W
	retfie

INIT
	bsf		STATUS,RP0		; Select Bank 1
	call	3FFh			; Internal RC calibration
	movwf	OSCCAL
	movlw	b'10001000'		; T0CS, PreScaler for WDT
	movwf	OPTION_REG
	movlw	b'10100000'		; GIE/T0IE
	movwf	INTCON
	bcf		STATUS,RP0
	clrf	TMR0
	clrf	GPIO			; GPIO cleared
	movlw	h'07'			; comparator dsabled
	movwf	CMCON
	bsf		STATUS,RP0
	movlw	b'00011000'		; Fosc/8, AN3 enabled
	movwf	ANSEL			;
	movlw	b'00100000'		; GP5 pull-up
	movwf	WPU
	movlw	b'00111000'		; GP5, GP3 input, GP2-0 output
	movwf	TRISIO
	bcf		STATUS,RP0		; Select Bank 0
	clrf	flag

	movlw	b'00001101'		; A/D left, Vdd ref, AN3
	movwf	ADCON0

	movlw	PWM_FRAME		; PWM frame counter set
	movwf	frame_cnt
	clrf	flag
	movf	red, W			; reset RED
	movwf	red_tmp
	movf	green, W		; reset GREEN
	movwf	green_tmp
	movf	blue, W			; reset BLUE
	movwf	blue_tmp

	btfsc	GPIO, GP3		; if GP3, sink LED current
	bsf		flag, bLOGIC	;    (if bLOGIC, sink)
	clrf	TMR0

MAIN_LOOP

	btfss	flag, bADFLG		; test A/D asserted?
	goto	MAIN_LOOP

;	bsf		ADCON0, ADON
	bsf		ADCON0, GO
AD_WAIT_LOOP
	btfsc	ADCON0, GO_DONE
	goto	AD_WAIT_LOOP
	bcf		flag, bADFLG
	movf	ADRESH, W
	btfss	GPIO, GP5		; if GP5, default pattern
	sublw	d'255'
	movwf	ad_tmp
;	bcf		ADCON0, ADON

REGION6
	movlw	d'214'
	subwf	ad_tmp, W
	btfss	STATUS, C
	goto	REGION5
	movwf	blue
	movlw	PWM_FRAME
	movwf	red
	movwf	green
	goto	MAIN_LOOP	

REGION5
	movlw	d'172'
	subwf	ad_tmp, W
	btfss	STATUS, C
	goto	REGION4
	movwf	green
	movlw	PWM_FRAME
	movwf	red
	clrf	blue
	goto	MAIN_LOOP	

REGION4
	movlw	d'130'
	subwf	ad_tmp, W
	btfss	STATUS, C
	goto	REGION3
	movwf	red
	clrf	green
	clrf	blue
	goto	MAIN_LOOP	

REGION3
	movlw	d'126'
	subwf	ad_tmp, W
	btfss	STATUS, C
	goto	REGION2
	clrf	red
	clrf	green
	clrf	blue
	goto	MAIN_LOOP	

REGION2
	movlw	d'84'
	subwf	ad_tmp, W
	btfss	STATUS, C
	goto	REGION1
	sublw	PWM_FRAME
	movwf	blue
	clrf	red
	clrf	green
	goto	MAIN_LOOP	

REGION1
	movlw	d'42'
	subwf	ad_tmp, W
	btfss	STATUS, C
	goto	REGION0
	sublw	PWM_FRAME
	movwf	red
	movlw	PWM_FRAME
	movwf	blue
	clrf	green
	goto	MAIN_LOOP	

REGION0
	movf	ad_tmp, W
	movwf	red
	sublw	PWM_FRAME
	movwf	green
	movlw	PWM_FRAME
	movwf	blue
	goto	MAIN_LOOP	


REGION_END
	goto	MAIN_LOOP


	END
;
; $Log: vmeter.asm,v $
; Revision 1.2  2005/11/24 02:53:11  ChuckTimber
; Added CVS directives.
;
;
