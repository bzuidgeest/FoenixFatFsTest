;:ts=8
R0	equ	1
R1	equ	5
R2	equ	9
R3	equ	13
;/*-----------------------------------------------------------------------*/
;/* ATA harddisk control module                                           */
;/*-----------------------------------------------------------------------*/
;/*
;/  Copyright (C) 2014, ChaN, all right reserved.
;/
;/ * This software is a free software and there is NO WARRANTY.
;/ * No restriction on use. You can use, modify and redistribute it for
;/   personal, non-profit or commercial products UNDER YOUR RESPONSIBILITY.
;/ * Redistributions of source code must retain the above copyright notice.
;/
;/-------------------------------------------------------------------------*/
;
;
;//$AF:E830..$AF:E83F - UNITY CHIP (IDE)
;
;#include "stdio.h"
;#include <sys/types.h>
;//#include "ffconf.h" included in ff.h
;#include "ff.h"
;#include "diskio.h"
;
;#define _USE_WRITE
;#define _USE_IOCTL
;
;#define IDE_DATA8			(*(volatile unsigned char *)0xAFE830)
;#define IDE_CMD_STAT		(*(volatile unsigned char *)0xAFE837)
;#define IDE_DATA			(*(volatile unsigned short *)0xAFE839)
;#define IDE_DATA_LO			(*(volatile unsigned char *)0xAFE838)
;#define IDE_DATA_HI			(*(volatile unsigned char *)0xAFE839)
;#define IDE_ERROR			(*(volatile unsigned char *)0xAFE831)
;#define IDE_FEATURES		(*(volatile unsigned char *)0xAFE831)
;#define IDE_SECT_CNT  		(*(volatile unsigned char *)0xAFE832)
;#define IDE_SECT_SRT  		(*(volatile unsigned char *)0xAFE833)
;#define IDE_CLDR   			(*(volatile unsigned short *)0xAFE834)
;#define IDE_CLDR_LO   		(*(volatile unsigned char *)0xAFE834)
;#define IDE_CLDR_HI   		(*(volatile unsigned char *)0xAFE835)
;#define IDE_HEAD      		(*(volatile unsigned char *)0xAFE836)
;
;// status register
;// ;7    6    5   4  3   2   1    0
;// ;BSY DRDY DF DSC DRQ CORR IDX ERR
;
;/* ATA commands */
;#define CMD_READ		0x20	/* READ SECTOR(S) */
;#define CMD_WRITE		0x30	/* WRITE SECTOR(S) */
;#define CMD_IDENTIFY	0xEC	/* DEVICE IDENTIFY */
;#define CMD_SETFEATURES	0xEF	/* SET FEATURES */
;
;/* ATA register bit definitions */
;#define	HEAD_LBA				0x40	/* REG_HEAD */
;#define	HEAD_DEV				0x10	/* REG_HEAD */
;#define	STATUS_BSY				0x80	/* REG_STATUS */
;#define	STATUS_DRDY				0x40	/* REG_STATUS */
;#define	STATUS_DRQ				0x08	/* REG_STATUS */
;#define	STATUS_ERR				0x01	/* REG_STATUS */
;
;#include "../foenixLibrary/interrupt.h"
;#include "../foenixLibrary/FMX_printf.h"
;#include "../foenixLibrary/vicky.h"
;
;extern char spinner[];
;
;char spinnerState1 = 0;
	data
	xdef	~~spinnerState1
~~spinnerState1:
	db	$0
	ends
;char spinnerState2 = 0;
	data
	xdef	~~spinnerState2
~~spinnerState2:
	db	$0
	ends
;/*--------------------------------------------------------------------------
;
;   Module Private Functions
;
;---------------------------------------------------------------------------*/
;
;/* Disk status */
;static 
;DSTATUS Stat = STA_NOINIT; 
	data
~~Stat:
	db	$1
	ends
;
;/*-----------------------------------------------------------------------*/
;/* Read an ATA register (Platform dependent)                             */
;/*-----------------------------------------------------------------------*/
;
;/* Read 512 bytes from ATA data register */
;static
;void read_block (
;	BYTE *buf
;)
;{
	code
	func
~~read_block:
	longa	on
	longi	on
	tsc
	sec
	sbc	#L2
	tcs
	phd
	tcd
buf_0	set	4
;	short c = 256, index = 0, data = 0;
;
;	disableInterrupts();
c_1	set	0
index_1	set	2
data_1	set	4
	lda	#$100
	sta	<L3+c_1
	stz	<L3+index_1
	stz	<L3+data_1
	asmstart
	sei
	asmend
;
;	// dummy read, why is this needed?
;	//data = IDE_DATA;
;	do {	
L10003:
;		data = IDE_DATA;
	lda	>11528249	; volatile
	sta	<L3+data_1
;		buf[index] = (data >> 8) & 0xFF;
	ldy	#$0
	lda	<L3+index_1
	bpl	L4
	dey
L4:
	sta	<R0
	sty	<R0+2
	clc
	lda	<L2+buf_0
	adc	<R0
	sta	<R1
	lda	<L2+buf_0+2
	adc	<R0+2
	sta	<R1+2
	lda	<L3+data_1
	ldx	#<$8
	xref	~~~asr
	jsl	~~~asr
	and	#<$ff
	sep	#$20
	longa	off
	sta	[<R1]
	rep	#$20
	longa	on
;		buf[index + 1] = data & 0xFF;
	lda	<L3+index_1
	ina
	sta	<R0
	ldy	#$0
	lda	<R0
	bpl	L5
	dey
L5:
	sta	<R0
	sty	<R0+2
	clc
	lda	<L2+buf_0
	adc	<R0
	sta	<R1
	lda	<L2+buf_0+2
	adc	<R0+2
	sta	<R1+2
	lda	<L3+data_1
	and	#<$ff
	sep	#$20
	longa	off
	sta	[<R1]
	rep	#$20
	longa	on
;		index = index + 2;
	inc	<L3+index_1
	inc	<L3+index_1
;	} while (c--);
L10001:
	lda	<L3+c_1
	sta	<R0
	dec	<L3+c_1
	lda	<R0
	beq	L6
	brl	L10003
L6:
L10002:
;	enableInterrupts();
	asmstart
	cli
	asmend
;}
L7:
	lda	<L2+2
	sta	<L2+2+4
	lda	<L2+1
	sta	<L2+1+4
	pld
	tsc
	clc
	adc	#L2+4
	tcs
	rtl
L2	equ	14
L3	equ	9
	ends
	efunc
;
;
;/* Read 512 bytes from ATA data register but store a part of block */
;static
;void read_block_part (
;	BYTE *buf,
;	BYTE ofs,
;	BYTE nw
;)
;{
	code
	func
~~read_block_part:
	longa	on
	longi	on
	tsc
	sec
	sbc	#L8
	tcs
	phd
	tcd
buf_0	set	4
ofs_0	set	8
nw_0	set	10
;	// loop termination relies on byte data type overflow
;	BYTE c = 0, dl = 0, dh = 0;
;	short index = 0, data = 0;
;
;	// dummy read, why is this needed?
;	data = IDE_DATA;
c_1	set	0
dl_1	set	1
dh_1	set	2
index_1	set	3
data_1	set	5
	sep	#$20
	longa	off
	stz	<L9+c_1
	rep	#$20
	longa	on
	sep	#$20
	longa	off
	stz	<L9+dl_1
	rep	#$20
	longa	on
	sep	#$20
	longa	off
	stz	<L9+dh_1
	rep	#$20
	longa	on
	stz	<L9+index_1
	stz	<L9+data_1
	lda	>11528249	; volatile
	sta	<L9+data_1
;
;	disableInterrupts();
	asmstart
	sei
	asmend
;
;	do {	
L10006:
;		data = IDE_DATA;
	lda	>11528249	; volatile
	sta	<L9+data_1
;		
;		dh = (data >> 8) & 0xFF;
	lda	<L9+data_1
	ldx	#<$8
	xref	~~~asr
	jsl	~~~asr
	and	#<$ff
	sta	<R0
	sep	#$20
	longa	off
	lda	<R0
	sta	<L9+dh_1
	rep	#$20
	longa	on
;		dl = data & 0xFF;
	lda	<L9+data_1
	and	#<$ff
	sta	<R0
	sep	#$20
	longa	off
	lda	<R0
	sta	<L9+dl_1
	rep	#$20
	longa	on
;		
;		if (nw && (c >= ofs)) {	/* Pick up a part of block */
	lda	<L8+nw_0
	and	#$ff
	bne	L10
	brl	L10007
L10:
	sep	#$20
	longa	off
	lda	<L9+c_1
	cmp	<L8+ofs_0
	rep	#$20
	longa	on
	bcs	L11
	brl	L10007
L11:
;			*buf++ = dl; *buf++ = dh;
	sep	#$20
	longa	off
	lda	<L9+dl_1
	sta	[<L8+buf_0]
	rep	#$20
	longa	on
	inc	<L8+buf_0
	bne	L12
	inc	<L8+buf_0+2
L12:
	sep	#$20
	longa	off
	lda	<L9+dh_1
	sta	[<L8+buf_0]
	rep	#$20
	longa	on
	inc	<L8+buf_0
	bne	L13
	inc	<L8+buf_0+2
L13:
;			nw--;
	sep	#$20
	longa	off
	dec	<L8+nw_0
	rep	#$20
	longa	on
;
;			//printf("\n%c", dl);
;			//printf("\n%c", dh);
;		}
;	} while (++c); // loop termination relies on byte data type overflow
L10007:
L10004:
	sep	#$20
	longa	off
	inc	<L9+c_1
	rep	#$20
	longa	on
	lda	<L9+c_1
	and	#$ff
	beq	L14
	brl	L10006
L14:
L10005:
;
;	enableInterrupts();
	asmstart
	cli
	asmend
;}
L15:
	lda	<L8+2
	sta	<L8+2+8
	lda	<L8+1
	sta	<L8+1+8
	pld
	tsc
	clc
	adc	#L8+8
	tcs
	rtl
L8	equ	11
L9	equ	5
	ends
	efunc
;
;
;
;/*-----------------------------------------------------------------------*/
;/* Write a byte to an ATA register (Platform dependent)                  */
;/*-----------------------------------------------------------------------*/
;
;#ifdef _USE_WRITE
;static
;/* Write 512 byte block to ATA data register */
;void write_block (
;	const BYTE *buf
;)
;{
	code
	func
~~write_block:
	longa	on
	longi	on
	tsc
	sec
	sbc	#L16
	tcs
	phd
	tcd
buf_0	set	4
;	BYTE c;
;	short data = 0;
;
;	c = 256;
c_1	set	0
data_1	set	1
	stz	<L17+data_1
	sep	#$20
	longa	off
	lda	#$0
	sta	<L17+c_1
	rep	#$20
	longa	on
;	disableInterrupts();
	asmstart
	sei
	asmend
;	do {	/* Send 2 bytes/loop */
L10010:
;		IDE_DATA_LO = *buf++;
	sep	#$20
	longa	off
	lda	[<L16+buf_0]
	sta	>11528248	; volatile
	rep	#$20
	longa	on
	inc	<L16+buf_0
	bne	L18
	inc	<L16+buf_0+2
L18:
;		IDE_DATA_HI = *buf++;
	sep	#$20
	longa	off
	lda	[<L16+buf_0]
	sta	>11528249	; volatile
	rep	#$20
	longa	on
	inc	<L16+buf_0
	bne	L19
	inc	<L16+buf_0+2
L19:
;		//data = *buf++ | (*buf++ << 8);
;		//IDE_DATA = data;
;	} while (--c);
L10008:
	sep	#$20
	longa	off
	dec	<L17+c_1
	rep	#$20
	longa	on
	lda	<L17+c_1
	and	#$ff
	beq	L20
	brl	L10010
L20:
L10009:
;	enableInterrupts();
	asmstart
	cli
	asmend
;}
L21:
	lda	<L16+2
	sta	<L16+2+4
	lda	<L16+1
	sta	<L16+1+4
	pld
	tsc
	clc
	adc	#L16+4
	tcs
	rtl
L16	equ	3
L17	equ	1
	ends
	efunc
;#endif
;
;
;
;/*-----------------------------------------------------------------------*/
;/* Wait for BSY goes 0 and the specified bit goes 1                                */
;/*-----------------------------------------------------------------------*/
;
;static
;int wait_stat (	/* 0:Timeout or or ERR goes 1 */
;	UINT ms,
;	BYTE bit
;)
;{
	code
	func
~~wait_stat:
	longa	on
	longi	on
	tsc
	sec
	sbc	#L22
	tcs
	phd
	tcd
ms_0	set	4
bit_0	set	6
;	BYTE s;
;
;	do {
s_1	set	0
L10013:
;		s = IDE_CMD_STAT;
	sep	#$20
	longa	off
	lda	>11528247	; volatile
	sta	<L23+s_1
	rep	#$20
	longa	on
;		if ((s & STATUS_ERR)) 
;		{
	sep	#$20
	longa	off
	lda	<L23+s_1
	and	#<$1
	rep	#$20
	longa	on
	bne	L24
	brl	L10014
L24:
;			
;			printf("\nerror! %d", IDE_ERROR);
	sep	#$20
	longa	off
	lda	>11528241	; volatile
	rep	#$20
	longa	on
	and	#$ff
	pha
	pea	#^L1
	pea	#<L1
	pea	#8
	jsl	~~printf_
;			return 0;	/* Abort when timeout or error occured */
	lda	#$0
L25:
	tay
	lda	<L22+2
	sta	<L22+2+4
	lda	<L22+1
	sta	<L22+1+4
	pld
	tsc
	clc
	adc	#L22+4
	tcs
	tya
	rtl
;		}
;	} while ((s & STATUS_BSY) || (bit && !(bit & s)));		/* Wait for BSY goes 0 and the bit goes 1 */
L10014:
L10011:
	sep	#$20
	longa	off
	lda	<L23+s_1
	and	#<$80
	rep	#$20
	longa	on
	beq	L26
	brl	L10013
L26:
	lda	<L22+bit_0
	and	#$ff
	bne	L28
	brl	L27
L28:
	sep	#$20
	longa	off
	lda	<L23+s_1
	and	<L22+bit_0
	rep	#$20
	longa	on
	bne	L29
	brl	L10013
L29:
L27:
L10012:
;
;	//read_ata(REG_ALTSTAT);
;	return 1;
	lda	#$1
	brl	L25
;}
L22	equ	1
L23	equ	1
	ends
	efunc
	data
L1:
	db	$0A,$65,$72,$72,$6F,$72,$21,$20,$25,$64,$00
	ends
;
;
;
;/*-----------------------------------------------------------------------*/
;/* Issue Read/Write command to the drive                                 */
;/*-----------------------------------------------------------------------*/
;
;static
;int issue_rwcmd (
;	BYTE pdrv,
;	BYTE cmd,
;	DWORD sector,
;	UINT count
;)
;{
	code
	func
~~issue_rwcmd:
	longa	on
	longi	on
	tsc
	sec
	sbc	#L31
	tcs
	phd
	tcd
pdrv_0	set	4
cmd_0	set	6
sector_0	set	8
count_0	set	12
;	BYTE head = ((BYTE)(sector >> 24) & 0x0F) | HEAD_LBA;
;	if (!wait_stat(1000, STATUS_DRDY)) return 0;
head_1	set	0
	pei	<L31+sector_0+2
	pei	<L31+sector_0
	lda	#$18
	xref	~~~llsr
	jsl	~~~llsr
	sta	<R0
	stx	<R0+2
	sep	#$20
	longa	off
	lda	<R0
	and	#<$f
	rep	#$20
	longa	on
	sep	#$20
	longa	off
	ora	#<$40
	sta	<L32+head_1
	rep	#$20
	longa	on
	pea	#<$40
	pea	#<$3e8
	jsl	~~wait_stat
	tax
	beq	L33
	brl	L10015
L33:
	lda	#$0
L34:
	tay
	lda	<L31+2
	sta	<L31+2+10
	lda	<L31+1
	sta	<L31+1+10
	pld
	tsc
	clc
	adc	#L31+10
	tcs
	tya
	rtl
;	IDE_HEAD = head;
L10015:
	sep	#$20
	longa	off
	lda	<L32+head_1
	sta	>11528246	; volatile
	rep	#$20
	longa	on
;	if (!wait_stat(1000, STATUS_DRDY)) return 0;
	pea	#<$40
	pea	#<$3e8
	jsl	~~wait_stat
	tax
	beq	L35
	brl	L10016
L35:
	lda	#$0
	brl	L34
;	IDE_CLDR_HI = (BYTE)(sector >> 16);
L10016:
	pei	<L31+sector_0+2
	pei	<L31+sector_0
	lda	#$10
	xref	~~~llsr
	jsl	~~~llsr
	sta	<R0
	stx	<R0+2
	sep	#$20
	longa	off
	lda	<R0
	sta	>11528245	; volatile
	rep	#$20
	longa	on
;	IDE_CLDR_LO = (BYTE)(sector >> 8);
	pei	<L31+sector_0+2
	pei	<L31+sector_0
	lda	#$8
	xref	~~~llsr
	jsl	~~~llsr
	sta	<R0
	stx	<R0+2
	sep	#$20
	longa	off
	lda	<R0
	sta	>11528244	; volatile
	rep	#$20
	longa	on
;	IDE_SECT_SRT = (BYTE)sector;
	sep	#$20
	longa	off
	lda	<L31+sector_0
	sta	>11528243	; volatile
	rep	#$20
	longa	on
;	IDE_SECT_CNT = (BYTE)count;
	sep	#$20
	longa	off
	lda	<L31+count_0
	sta	>11528242	; volatile
	rep	#$20
	longa	on
;	IDE_CMD_STAT = cmd;
	sep	#$20
	longa	off
	lda	<L31+cmd_0
	sta	>11528247	; volatile
	rep	#$20
	longa	on
;	return 1;
	lda	#$1
	brl	L34
;}
L31	equ	5
L32	equ	5
	ends
	efunc
;
;
;
;/*--------------------------------------------------------------------------
;
;   Public Functions
;
;---------------------------------------------------------------------------*/
;
;
;/*-----------------------------------------------------------------------*/
;/* Initialize Disk Drive                                                 */
;/*-----------------------------------------------------------------------*/
;
;DSTATUS disk_initialize (
;	BYTE pdrv		/* Physical drive nmuber (0/1) */
;)
;{
	code
	xdef	~~disk_initialize
	func
~~disk_initialize:
	longa	on
	longi	on
	tsc
	sec
	sbc	#L36
	tcs
	phd
	tcd
pdrv_0	set	4
;	/* Returns current status if initialization has been done */
;	if (Stat != STA_NOINIT) return Stat;	
	sep	#$20
	longa	off
	lda	|~~Stat
	cmp	#<$1
	rep	#$20
	longa	on
	bne	L38
	brl	L10017
L38:
	lda	|~~Stat
	and	#$ff
L39:
	tay
	lda	<L36+2
	sta	<L36+2+2
	lda	<L36+1
	sta	<L36+1+2
	pld
	tsc
	clc
	adc	#L36+2
	tcs
	tya
	rtl
;
;	IDE_HEAD = 0 | HEAD_LBA;
L10017:
	sep	#$20
	longa	off
	lda	#$40
	sta	>11528246	; volatile
	rep	#$20
	longa	on
;	if (wait_stat(3000, STATUS_DRDY)) {
	pea	#<$40
	pea	#<$bb8
	jsl	~~wait_stat
	tax
	bne	L40
	brl	L10018
L40:
;		Stat = 0;
	sep	#$20
	longa	off
	stz	|~~Stat
	rep	#$20
	longa	on
;	}
;	return Stat;
L10018:
	lda	|~~Stat
	and	#$ff
	brl	L39
;}
L36	equ	0
L37	equ	1
	ends
	efunc
;
;/*-----------------------------------------------------------------------*/
;/* Return Disk Status                                                    */
;/*-----------------------------------------------------------------------*/
;
;DSTATUS disk_status (
;	BYTE pdrv		/* Physical drive nmuber (0/1) */
;)
;{
	code
	xdef	~~disk_status
	func
~~disk_status:
	longa	on
	longi	on
	tsc
	sec
	sbc	#L41
	tcs
	phd
	tcd
pdrv_0	set	4
;	/* Supports only single drive */
;	if (pdrv >= 1) return STA_NOINIT;	
	sep	#$20
	longa	off
	lda	<L41+pdrv_0
	cmp	#<$1
	rep	#$20
	longa	on
	bcs	L43
	brl	L10019
L43:
	lda	#$1
L44:
	tay
	lda	<L41+2
	sta	<L41+2+2
	lda	<L41+1
	sta	<L41+1+2
	pld
	tsc
	clc
	adc	#L41+2
	tcs
	tya
	rtl
;	else return Stat;
L10019:
	lda	|~~Stat
	and	#$ff
	brl	L44
;}
L41	equ	0
L42	equ	1
	ends
	efunc
;
;/*-----------------------------------------------------------------------*/
;/* Read Sector(s)                                                        */
;/*-----------------------------------------------------------------------*/
;
;DRESULT disk_read (
;	BYTE pdrv,		/* Physical drive nmuber (0/1) */
;	BYTE *buff,		/* Data buffer to store read data */
;	DWORD sector,	/* Sector number (LBA) */
;	UINT count		/* Sector count (1..128) */
;)
;{
	code
	xdef	~~disk_read
	func
~~disk_read:
	longa	on
	longi	on
	tsc
	sec
	sbc	#L45
	tcs
	phd
	tcd
pdrv_0	set	4
buff_0	set	6
sector_0	set	10
count_0	set	14
;	BYTE stat;
;	short dummy = 0;
;
;	if (pdrv >= 1 || !count || sector > 0xFFFFFFF) return RES_PARERR;
stat_1	set	0
dummy_1	set	1
	stz	<L46+dummy_1
	sep	#$20
	longa	off
	lda	<L45+pdrv_0
	cmp	#<$1
	rep	#$20
	longa	on
	bcc	L48
	brl	L47
L48:
	lda	<L45+count_0
	bne	L49
	brl	L47
L49:
	lda	#$ffff
	cmp	<L45+sector_0
	lda	#$fff
	sbc	<L45+sector_0+2
	bcc	L50
	brl	L10020
L50:
L47:
	lda	#$4
L51:
	tay
	lda	<L45+2
	sta	<L45+2+12
	lda	<L45+1
	sta	<L45+1+12
	pld
	tsc
	clc
	adc	#L45+12
	tcs
	tya
	rtl
;	if (Stat & STA_NOINIT) return RES_NOTRDY;
L10020:
	sep	#$20
	longa	off
	lda	|~~Stat
	and	#<$1
	rep	#$20
	longa	on
	bne	L52
	brl	L10021
L52:
	lda	#$3
	brl	L51
;
;	/* Issue Read Setor(s) command */
;	if (!issue_rwcmd(pdrv, CMD_READ, sector, count)) return RES_ERROR;
L10021:
	pei	<L45+count_0
	pei	<L45+sector_0+2
	pei	<L45+sector_0
	pea	#<$20
	pei	<L45+pdrv_0
	jsl	~~issue_rwcmd
	tax
	beq	L53
	brl	L10022
L53:
	lda	#$1
	brl	L51
;
;	/* Receive data blocks */
;	printf("\n count: %d sector: %d",count , sector);
L10022:
	pei	<L45+sector_0+2
	pei	<L45+sector_0
	pei	<L45+count_0
	pea	#^L30
	pea	#<L30
	pea	#12
	jsl	~~printf_
;	
;	do {
L10025:
;		if (!wait_stat(2000, STATUS_DRQ)) return RES_ERROR; 	/* Wait for a sector prepared */
	pea	#<$8
	pea	#<$7d0
	jsl	~~wait_stat
	tax
	beq	L54
	brl	L10026
L54:
	lda	#$1
	brl	L51
;		printf("\nread2 %d", buff);
L10026:
	pei	<L45+buff_0+2
	pei	<L45+buff_0
	pea	#^L30+23
	pea	#<L30+23
	pea	#10
	jsl	~~printf_
;		
;		// dummy read, why is this needed?
;		dummy = IDE_DATA;	
	lda	>11528249	; volatile
	sta	<L46+dummy_1
;		
;		read_block(buff);	/* Read a sector */
	pei	<L45+buff_0+2
	pei	<L45+buff_0
	jsl	~~read_block
;		buff += 512;
	clc
	lda	#$200
	adc	<L45+buff_0
	sta	<L45+buff_0
	bcc	L55
	inc	<L45+buff_0+2
L55:
;		/// dummy read, why is this needed?
;		//dummy = IDE_DATA;
;	} while (--count);		/* Repeat all sectors read */
L10023:
	dec	<L45+count_0
	lda	<L45+count_0
	beq	L56
	brl	L10025
L56:
L10024:
;//printf("read3");
;	// read_ata(REG_ALTSTAT);
;	// read_ata(REG_STATUS);
;	stat = IDE_CMD_STAT;
	sep	#$20
	longa	off
	lda	>11528247	; volatile
	sta	<L46+stat_1
	rep	#$20
	longa	on
;
;	return RES_OK;
	lda	#$0
	brl	L51
;}
L45	equ	3
L46	equ	1
	ends
	efunc
	data
L30:
	db	$0A,$20,$63,$6F,$75,$6E,$74,$3A,$20,$25,$64,$20,$73,$65,$63
	db	$74,$6F,$72,$3A,$20,$25,$64,$00,$0A,$72,$65,$61,$64,$32,$20
	db	$25,$64,$00
	ends
;
;
;
;/*-----------------------------------------------------------------------*/
;/* Write Sector(s)                                                       */
;/*-----------------------------------------------------------------------*/
;
;#ifdef _USE_WRITE
;DRESULT disk_write (
;	BYTE pdrv,			/* Physical drive nmuber (0/1) */
;	const BYTE *buff,	/* Data to be written */
;	DWORD sector,		/* Sector number (LBA) */
;	UINT count			/* Sector count (1..128) */
;)
;{
	code
	xdef	~~disk_write
	func
~~disk_write:
	longa	on
	longi	on
	tsc
	sec
	sbc	#L58
	tcs
	phd
	tcd
pdrv_0	set	4
buff_0	set	6
sector_0	set	10
count_0	set	14
;	BYTE stat;
;	short dummy = 0;
;
;	if (pdrv > 0 || !count || sector > 0xFFFFFFF) return RES_PARERR;
stat_1	set	0
dummy_1	set	1
	stz	<L59+dummy_1
	sep	#$20
	longa	off
	lda	#$0
	cmp	<L58+pdrv_0
	rep	#$20
	longa	on
	bcs	L61
	brl	L60
L61:
	lda	<L58+count_0
	bne	L62
	brl	L60
L62:
	lda	#$ffff
	cmp	<L58+sector_0
	lda	#$fff
	sbc	<L58+sector_0+2
	bcc	L63
	brl	L10027
L63:
L60:
	lda	#$4
L64:
	tay
	lda	<L58+2
	sta	<L58+2+12
	lda	<L58+1
	sta	<L58+1+12
	pld
	tsc
	clc
	adc	#L58+12
	tcs
	tya
	rtl
;	if (Stat & STA_NOINIT) return RES_NOTRDY;
L10027:
	sep	#$20
	longa	off
	lda	|~~Stat
	and	#<$1
	rep	#$20
	longa	on
	bne	L65
	brl	L10028
L65:
	lda	#$3
	brl	L64
;
;	/* Issue Write Setor(s) command */
;	if (!issue_rwcmd(pdrv, CMD_WRITE, sector, count)) return RES_ERROR;
L10028:
	pei	<L58+count_0
	pei	<L58+sector_0+2
	pei	<L58+sector_0
	pea	#<$30
	pei	<L58+pdrv_0
	jsl	~~issue_rwcmd
	tax
	beq	L66
	brl	L10029
L66:
	lda	#$1
	brl	L64
;	//printf("\nCount: %d Sector: %d", count, sector);
;	/* Send data blocks */
;	do {
L10029:
L10032:
;		if (!wait_stat(2000, STATUS_DRQ)) return RES_ERROR;	/* Wait for request to send data */
	pea	#<$8
	pea	#<$7d0
	jsl	~~wait_stat
	tax
	beq	L67
	brl	L10033
L67:
	lda	#$1
	brl	L64
;		//printf("\nbuff %d", buff);
;		write_block(buff);	/* Send a sector */
L10033:
	pei	<L58+buff_0+2
	pei	<L58+buff_0
	jsl	~~write_block
;		buff += 512;
	clc
	lda	#$200
	adc	<L58+buff_0
	sta	<L58+buff_0
	bcc	L68
	inc	<L58+buff_0+2
L68:
;		
;		// dummy write, why is this needed?
;		IDE_DATA = dummy;
	lda	<L59+dummy_1
	sta	>11528249	; volatile
;	} while (--count);		/* Repeat until all sector sent */
L10030:
	dec	<L58+count_0
	lda	<L58+count_0
	beq	L69
	brl	L10032
L69:
L10031:
;
;	/* Wait for end of write process */
;	if (!wait_stat(1000, 0)) return RES_ERROR;
	pea	#<$0
	pea	#<$3e8
	jsl	~~wait_stat
	tax
	beq	L70
	brl	L10034
L70:
	lda	#$1
	brl	L64
;	stat = IDE_CMD_STAT;
L10034:
	sep	#$20
	longa	off
	lda	>11528247	; volatile
	sta	<L59+stat_1
	rep	#$20
	longa	on
;	// read_ata(REG_ALTSTAT);
;	// read_ata(REG_STATUS);
;
;	return RES_OK;
	lda	#$0
	brl	L64
;}
L58	equ	3
L59	equ	1
	ends
	efunc
;#endif
;
;
;/*-----------------------------------------------------------------------*/
;/* Miscellaneous Functions                                               */
;/*-----------------------------------------------------------------------*/
;
;#ifdef _USE_IOCTL
;DRESULT disk_ioctl (
;	BYTE pdrv,		/* Physical drive nmuber (0/1) */
;	BYTE cmd,		/* Control code */
;	void *buff		/* Buffer to send/receive data block */
;)
;{
	code
	xdef	~~disk_ioctl
	func
~~disk_ioctl:
	longa	on
	longi	on
	tsc
	sec
	sbc	#L71
	tcs
	phd
	tcd
pdrv_0	set	4
cmd_0	set	6
buff_0	set	8
;	BYTE n, w, ofs, dl, dh, *ptr = (BYTE*)buff;
;	BYTE stat;
;
;	if (pdrv >= 1) return RES_PARERR;
n_1	set	0
w_1	set	1
ofs_1	set	2
dl_1	set	3
dh_1	set	4
ptr_1	set	5
stat_1	set	9
	lda	<L71+buff_0
	sta	<L72+ptr_1
	lda	<L71+buff_0+2
	sta	<L72+ptr_1+2
	sep	#$20
	longa	off
	lda	<L71+pdrv_0
	cmp	#<$1
	rep	#$20
	longa	on
	bcs	L73
	brl	L10035
L73:
	lda	#$4
L74:
	tay
	lda	<L71+2
	sta	<L71+2+8
	lda	<L71+1
	sta	<L71+1+8
	pld
	tsc
	clc
	adc	#L71+8
	tcs
	tya
	rtl
;	if (Stat & STA_NOINIT) return RES_NOTRDY;
L10035:
	sep	#$20
	longa	off
	lda	|~~Stat
	and	#<$1
	rep	#$20
	longa	on
	bne	L75
	brl	L10036
L75:
	lda	#$3
	brl	L74
;
;	switch (cmd) {
L10036:
	lda	<L71+cmd_0
	and	#$ff
	brl	L10037
;		case CTRL_SYNC :		/* Nothing to do */
L10039:
;			return RES_OK;
	lda	#$0
	brl	L74
;
;		case GET_SECTOR_COUNT :	/* Get number of sectors on the disk (DWORD) */
L10040:
;			ofs = 60; w = 2; n = 2;
	sep	#$20
	longa	off
	lda	#$3c
	sta	<L72+ofs_1
	rep	#$20
	longa	on
	sep	#$20
	longa	off
	lda	#$2
	sta	<L72+w_1
	rep	#$20
	longa	on
	sep	#$20
	longa	off
	lda	#$2
	sta	<L72+n_1
	rep	#$20
	longa	on
;			break;
	brl	L10038
;
;		case GET_BLOCK_SIZE :	/* Get erase block size in sectors (DWORD) */
L10041:
;			*(DWORD*)buff = 1;
	lda	#$1
	sta	[<L71+buff_0]
	lda	#$0
	ldy	#$2
	sta	[<L71+buff_0],Y
;			return RES_OK;
	lda	#$0
	brl	L74
;
;		case ATA_GET_REV :		/* Get firmware revision (8 chars) */
L10042:
;			ofs = 23; w = 4; n = 0;//n = 4;
	sep	#$20
	longa	off
	lda	#$17
	sta	<L72+ofs_1
	rep	#$20
	longa	on
	sep	#$20
	longa	off
	lda	#$4
	sta	<L72+w_1
	rep	#$20
	longa	on
	sep	#$20
	longa	off
	stz	<L72+n_1
	rep	#$20
	longa	on
;			break;
	brl	L10038
;
;		case ATA_GET_MODEL :	/* Get model name (40 chars) */
L10043:
;			ofs = 27; w = 20; n = 0;//n = 20;
	sep	#$20
	longa	off
	lda	#$1b
	sta	<L72+ofs_1
	rep	#$20
	longa	on
	sep	#$20
	longa	off
	lda	#$14
	sta	<L72+w_1
	rep	#$20
	longa	on
	sep	#$20
	longa	off
	stz	<L72+n_1
	rep	#$20
	longa	on
;			break;
	brl	L10038
;
;		case ATA_GET_SN :		/* Get serial number (20 chars) */
L10044:
;			ofs = 10; w = 10; n = 0;//n = 10;
	sep	#$20
	longa	off
	lda	#$a
	sta	<L72+ofs_1
	rep	#$20
	longa	on
	sep	#$20
	longa	off
	lda	#$a
	sta	<L72+w_1
	rep	#$20
	longa	on
	sep	#$20
	longa	off
	stz	<L72+n_1
	rep	#$20
	longa	on
;			break;
	brl	L10038
;
;		default:
L10045:
;			return RES_PARERR;
	lda	#$4
	brl	L74
;	}
L10037:
	xref	~~~swt
	jsl	~~~swt
	dw	6
	dw	0
	dw	L10039-1
	dw	1
	dw	L10040-1
	dw	3
	dw	L10041-1
	dw	20
	dw	L10042-1
	dw	21
	dw	L10043-1
	dw	22
	dw	L10044-1
	dw	L10045-1
L10038:
;
;//printf("world1");
;	if (!wait_stat(1000, 0)) return RES_ERROR;	/* Select device */
	pea	#<$0
	pea	#<$3e8
	jsl	~~wait_stat
	tax
	beq	L76
	brl	L10046
L76:
	lda	#$1
	brl	L74
;	//write_ata(REG_DEV, pdrv ? DEV : 0);
;	IDE_HEAD = 0;
L10046:
	sep	#$20
	longa	off
	lda	#$0
	sta	>11528246	; volatile
	rep	#$20
	longa	on
;	//printf("world2");
;	if (!wait_stat(1000, STATUS_DRDY)) return RES_ERROR;
	pea	#<$40
	pea	#<$3e8
	jsl	~~wait_stat
	tax
	beq	L77
	brl	L10047
L77:
	lda	#$1
	brl	L74
;	//write_ata(REG_COMMAND, CMD_IDENTIFY);	/* Get device ID data block */
;	IDE_CMD_STAT = CMD_IDENTIFY;
L10047:
	sep	#$20
	longa	off
	lda	#$ec
	sta	>11528247	; volatile
	rep	#$20
	longa	on
;	//printf("world3");
;	if (!wait_stat(1000, STATUS_DRQ)) return RES_ERROR;	/* Wait for data ready */
	pea	#<$8
	pea	#<$3e8
	jsl	~~wait_stat
	tax
	beq	L78
	brl	L10048
L78:
	lda	#$1
	brl	L74
;	//printf("world4");
;	read_block_part(ptr, ofs, w);
L10048:
	pei	<L72+w_1
	pei	<L72+ofs_1
	pei	<L72+ptr_1+2
	pei	<L72+ptr_1
	jsl	~~read_block_part
;	//printf("world5");
;	while (n--) {				/* Swap byte order */
L10049:
	sep	#$20
	longa	off
	lda	<L72+n_1
	sta	<R0
	rep	#$20
	longa	on
	sep	#$20
	longa	off
	dec	<L72+n_1
	rep	#$20
	longa	on
	lda	<R0
	and	#$ff
	bne	L79
	brl	L10050
L79:
;		dl = *ptr++; dh = *ptr--;
	sep	#$20
	longa	off
	lda	[<L72+ptr_1]
	sta	<L72+dl_1
	rep	#$20
	longa	on
	inc	<L72+ptr_1
	bne	L80
	inc	<L72+ptr_1+2
L80:
	sep	#$20
	longa	off
	lda	[<L72+ptr_1]
	sta	<L72+dh_1
	rep	#$20
	longa	on
	lda	<L72+ptr_1
	bne	L81
	dec	<L72+ptr_1+2
L81:
	dec	<L72+ptr_1
;		*ptr++ = dh; *ptr++ = dl; 
	sep	#$20
	longa	off
	lda	<L72+dh_1
	sta	[<L72+ptr_1]
	rep	#$20
	longa	on
	inc	<L72+ptr_1
	bne	L82
	inc	<L72+ptr_1+2
L82:
	sep	#$20
	longa	off
	lda	<L72+dl_1
	sta	[<L72+ptr_1]
	rep	#$20
	longa	on
	inc	<L72+ptr_1
	bne	L83
	inc	<L72+ptr_1+2
L83:
;	}
	brl	L10049
L10050:
;
;	stat = IDE_CMD_STAT;
	sep	#$20
	longa	off
	lda	>11528247	; volatile
	sta	<L72+stat_1
	rep	#$20
	longa	on
;	// read_ata(REG_ALTSTAT);
;	// read_ata(REG_STATUS);
;
;	return RES_OK;
	lda	#$0
	brl	L74
;}
L71	equ	14
L72	equ	5
	ends
	efunc
;#endif
;
;  
;
	xref	~~printf_
	end
