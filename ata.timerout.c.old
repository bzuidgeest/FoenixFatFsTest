/*-----------------------------------------------------------------------*/
/* ATA harddisk control module                                           */
/*-----------------------------------------------------------------------*/
/*
/  Copyright (C) 2014, ChaN, all right reserved.
/
/ * This software is a free software and there is NO WARRANTY.
/ * No restriction on use. You can use, modify and redistribute it for
/   personal, non-profit or commercial products UNDER YOUR RESPONSIBILITY.
/ * Redistributions of source code must retain the above copyright notice.
/
/-------------------------------------------------------------------------*/

//#define N_DRIVES	1	/* 1:Master only, 2:Master+Slave */


//$AF:E830..$AF:E83F - UNITY CHIP (IDE)

#include "stdio.h"
#include <sys/types.h>
//#include "ffconf.h" included in ff.h
#include "ff.h"
#include "diskio.h"

#define _USE_WRITE
#define _USE_IOCTL

/* Contorl Ports */
/*
#define	CTRL_PORT		PORTA
#define	CTRL_DDR		DDRA
#define	DATH_PORT		PORTC
#define	DATH_DDR		DDRC
#define	DATH_PIN		PINC
#define	DATL_PORT		PORTD
#define	DATL_DDR		DDRD
#define	DATL_PIN		PIND
*/

// IDE Interface
// IDE_DATA      = $AFE830 ; 8Bit Access here Only
// IDE_ERROR     = $AFE831 ; Error Information register (only read when there is an error ) - Probably clears Error Bits
// IDE_SECT_CNT  = $AFE832 ; Sector Count Register (also used to pass parameter for timeout for IDLE modus Command)
// IDE_SECT_SRT  = $AFE833 ; Start Sector Register (0 = 256), so start @ 1
// IDE_CLDR_LO   = $AFE834 ; Low Byte of Cylinder Numnber {7:0}
// IDE_CLDR_HI   = $AFE835 ;  Hi Byte of Cylinder Number {9:8} (1023-0).
// IDE_HEAD      = $AFE836 ; Head, device select, {3:0} HEad Number, 4 -> 0:Master, 1:Slave, {7:5} = 101 (legacy);
// IDE_CMD_STAT  = $AFE837 ; Command/Status Register - Reading this will clear the Interrupt Registers
// IDE_DATA_LO   = $AFE838 ; The 16Bits Buffer is LITTLE ENDIAN, the 65C816 is BIG ENDIAN, but UNITY does the conversion
// IDE_DATA_HI   = $AFE839 ;
// ;7    6    5   4  3   2   1    0
// ;BSY DRDY DF DSC DRQ CORR IDX ERR

#define IDE_DATA8         	(*(volatile unsigned char *)0xAFE830)
#define IDE_CMD_STAT  		(*(volatile unsigned char *)0xAFE837)
#define IDE_DATA         	(*(volatile unsigned short *)0xAFE838)
#define IDE_DATA_LO        	(*(volatile unsigned char *)0xAFE838)
#define IDE_DATA_HI        	(*(volatile unsigned char *)0xAFE839)
#define IDE_ERROR     		(*(volatile unsigned char *)0xAFE831)
#define IDE_FEATURES		(*(volatile unsigned char *)0xAFE831)
#define IDE_SECT_CNT  		(*(volatile unsigned char *)0xAFE832)
#define IDE_SECT_SRT  		(*(volatile unsigned char *)0xAFE833)
#define IDE_CLDR   			(*(volatile unsigned short *)0xAFE834)
#define IDE_CLDR_LO   		(*(volatile unsigned char *)0xAFE834)
#define IDE_CLDR_HI   		(*(volatile unsigned char *)0xAFE835)
#define IDE_HEAD      		(*(volatile unsigned char *)0xAFE836)


/* Bit definitions for Control Port */

// #define	REG_DATA		0b11110000	/* Select Data register */
// #define	REG_ERROR		0b11110001	/* Select Error register */
// #define	REG_FEATURES	0b11110001	/* Select Features register */
// #define	REG_COUNT		0b11110010	/* Select Count register */
// #define	REG_SECTOR		0b11110011	/* Select Sector register */
// #define	REG_CYLL		0b11110100	/* Select Cylinder low register */
// #define	REG_CYLH		0b11110101	/* Select Cylinder high regitser */
// #define	REG_DEV			0b11110110	/* Select Device register */
// #define	REG_COMMAND		0b11110111	/* Select Command register */
// #define	REG_STATUS		0b11110111	/* Select Status register */
// #define	REG_DEVCTRL		0b11101110	/* Select Device control register */
// #define	REG_ALTSTAT		0b11101110	/* Select Alternative Setatus register */
// #define	IORD			0b00100000	/* IORD# bit in the control port */
// #define	IOWR			0b01000000	/* IOWR# bit in the control port */
// #define	RESET			0b10000000	/* RESE# bit in the control port */

/* ATA command */
#define CMD_READ		0x20	/* READ SECTOR(S) */
#define CMD_WRITE		0x30	/* WRITE SECTOR(S) */
#define CMD_IDENTIFY	0xEC	/* DEVICE IDENTIFY */
#define CMD_SETFEATURES	0xEF	/* SET FEATURES */

/* ATA register bit definitions */
#define	LBA				0x40	/* REG_HEAD */
#define	DEV				0x10	/* REG_HEAD */
#define	BSY				0x80	/* REG_STATUS */
#define	DRDY			0x40	/* REG_STATUS */
#define	DRQ				0x08	/* REG_STATUS */
#define	ERR				0x01	/* REG_STATUS */
#define	SRST			0x04	/* REG_DEVCTRL */
#define	NIEN			0x02	/* REG_DEVCTRL */


// remove to use the proper header stuff
//#define UINT uint32_t
//#define BYTE char

#include "../foenixLibrary/interrupt.h"
#include "../foenixLibrary/FMX_printf.h"
#include "../foenixLibrary/vicky.h"

extern char spinner[];

char spinnerState1 = 0;
char spinnerState2 = 0;
/*--------------------------------------------------------------------------

   Module Private Functions

---------------------------------------------------------------------------*/


//static
//DSTATUS Stat[2] = {STA_NOINIT, STA_NOINIT};	/* Disk status */
static 
DSTATUS Stat = STA_NOINIT; /* Disk status */

static
BYTE Init = 0;	/* b0:master initialized, b1:slave initialized */

static
volatile UINT Timer;	/* 100Hz decrement timer */



static
void set_timer (
	UINT ms
)
{
	ms /= 10;
	disableInterrupts();
	Timer = ms;
	enableInterrupts();;
}


static
UINT get_timer (void)
{
	UINT n;

	disableInterrupts();;
	n = Timer;
	enableInterrupts();;

	return n * 10;
}


static
void delay_ms (
	UINT ms
)
{
	ms /= 10;
	disableInterrupts();; 
	Timer = ms; 
	enableInterrupts();;

	do {
		disableInterrupts();; 
		ms = Timer; 
		enableInterrupts();;
	} while (ms);
}



/*-----------------------------------------------------------------------*/
/* Initialize control port (Platform dependent)                          */
/*-----------------------------------------------------------------------*/

static
void IDE_DRIVE_BSY(void)
{
	 while (IDE_CMD_STAT & BSY == BSY) 
	 {
		if (spinnerState1 < 7)
			spinnerState1++;
		else
		{
			spinnerState1 = 0;
		}
		textScreen[7] = spinner[spinnerState1];
	 }
}

static
void IDE_DRV_READY(void)
{
	while (IDE_CMD_STAT & DRDY != DRDY)
	{
		if (spinnerState2 < 7)
			spinnerState2++;
		else
		{
			spinnerState2 = 0;
		}
		textScreen[8] = spinner[spinnerState2];
	} 
}

static
void IDE_DRV_READY_NOTBUSY(void)
{
	while (IDE_CMD_STAT & DRDY != DRDY) 
	{
		if (spinnerState1 < 7)
			spinnerState1++;
		else
		{
			spinnerState1 = 0;
		}
		textScreen[7] = spinner[spinnerState1];
	}
		
	while (IDE_CMD_STAT & BSY != BSY)
	{
		if (spinnerState2 < 7)
			spinnerState2++;
		else
		{
			spinnerState2 = 0;
		}
		textScreen[8] = spinner[spinnerState2];	
	} 
}

static
void IDE_NOT_DRQ(void)
{
	while (IDE_CMD_STAT & 0x08 != 0x08);
}

static
void init_port (void)
{
	// ide_library.asm -> IDE_INIT
	
	IDE_DRIVE_BSY(); 
	
	IDE_CLDR = 0;
	IDE_SECT_CNT = 0;
	IDE_SECT_SRT = 1;
	IDE_HEAD =  0xA0;
	
	IDE_DRV_READY_NOTBUSY();
}


/*-----------------------------------------------------------------------*/
/* Read an ATA register (Platform dependent)                             */
/*-----------------------------------------------------------------------*/

/* Read 512 bytes from ATA data register */
static
void read_block (
	BYTE *buf
)
{
	BYTE dl, dh, c, iord_l, iord_h;

	c = 512;
	disableInterrupts();;
	do {	
		*buf++ = IDE_DATA_LO; *buf++ = IDE_DATA_HI;	
	} while (--c);
	enableInterrupts();;
}


/* Read 512 bytes from ATA data register but store a part of block */
static
void read_block_part (
	BYTE *buf,
	BYTE ofs,
	BYTE nw
)
{
	BYTE c, dl, dh;

	disableInterrupts();;
	do {
		if (nw && (c >= ofs)) {	/* Pick up a part of block */
			*buf++ = IDE_DATA_LO; *buf++ = IDE_DATA_HI;
			nw--;
		}
	} while (++c);
	enableInterrupts();;
}



/*-----------------------------------------------------------------------*/
/* Write a byte to an ATA register (Platform dependent)                  */
/*-----------------------------------------------------------------------*/

#ifdef _USE_WRITE
static
/* Write 512 byte block to ATA data register */
void write_block (
	const BYTE *buf
)
{
	// BYTE c, iowr_l, iowr_h;


	// CTRL_PORT = REG_DATA;	/* Select data register */
	// iowr_h = REG_DATA;
	// iowr_l = REG_DATA & ~IOWR;
	// DATL_DDR = 0xFF; DATH_DDR = 0xFF;	/* Set D15..D0 as output */
	// c = 128;
	// disableInterrupts();;
	// do {	/* Send 4 bytes/loop */
	// 	DATL_PORT = *buf++; DATH_PORT = *buf++;	/* Set a word on the D15..D0 */
	// 	CTRL_PORT = iowr_l; CTRL_PORT = iowr_h;	/* Make low pulse on IOWR# */
	// 	DATL_PORT = *buf++; DATH_PORT = *buf++;	/* Set a word on the D15..D0 */
	// 	CTRL_PORT = iowr_l; CTRL_PORT = iowr_h;	/* Make low pulse on IOWR# */
	// } while (--c);
	// enableInterrupts();;
	// DATL_PORT = 0x7F; DATH_PORT = 0xFF;		/* Set D0..D15 as input (pull-up wo/D7) */
	// DATL_DDR = 0; DATH_DDR = 0;
}
#endif



/*-----------------------------------------------------------------------*/
/* Wait for BSY goes 0 and the bit goes 1                                */
/*-----------------------------------------------------------------------*/

static
int wait_stat (	/* 0:Timeout or or ERR goes 1 */
	UINT ms,
	BYTE bit
)
{
	BYTE s;

	set_timer(ms);
	do {
		//s = read_ata(REG_STATUS);					/* Get status */
		s = IDE_CMD_STAT;
		//printf("\nstat: %d", s);
		if (!get_timer()) 
		{
			
			printf("\ntimeout! %d %d", s, Timer);
			return 0;	/* Abort when timeout or error occured */
		}
		if ((s & ERR)) 
		{
			
			printf("\nerror! %d", IDE_ERROR);
			return 0;	/* Abort when timeout or error occured */
		}
	} while ((s & BSY) || (bit && !(bit & s)));		/* Wait for BSY goes 0 and the bit goes 1 */

	//read_ata(REG_ALTSTAT);
	return 1;
}



/*-----------------------------------------------------------------------*/
/* Issue Read/Write command to the drive                                 */
/*-----------------------------------------------------------------------*/

static
int issue_rwcmd (
	BYTE pdrv,
	BYTE cmd,
	DWORD sector,
	UINT count
)
{

	// if (!wait_stat(1000, DRDY)) return 0;
	// write_ata(REG_DEV, ((BYTE)(sector >> 24) & 0x0F) | LBA | (pdrv ? DEV : 0));
	// if (!wait_stat(1000, DRDY)) return 0;
	// write_ata(REG_CYLH, (BYTE)(sector >> 16));
	// write_ata(REG_CYLL, (BYTE)(sector >> 8));
	// write_ata(REG_SECTOR, (BYTE)sector);
	// write_ata(REG_COUNT, (BYTE)count);
	// write_ata(REG_COMMAND, cmd);

	if (!wait_stat(1000, DRDY)) return 0;
	IDE_HEAD = ((BYTE)(sector >> 24) & 0x0F) | LBA | (pdrv ? DEV : 0);
	if (!wait_stat(1000, DRDY)) return 0;
	IDE_CLDR_HI = (BYTE)(sector >> 16);
	IDE_CLDR_LO = (BYTE)(sector >> 8);
	IDE_SECT_SRT = (BYTE)sector;
	IDE_SECT_CNT = (BYTE)count;
	IDE_CMD_STAT = cmd;
	return 1;
}



/*--------------------------------------------------------------------------

   Public Functions

---------------------------------------------------------------------------*/


/*-----------------------------------------------------------------------*/
/* Initialize Disk Drive                                                 */
/*-----------------------------------------------------------------------*/

DSTATUS disk_initialize (
	BYTE pdrv		/* Physical drive nmuber (0/1) */
)
{
	BYTE n, ex;


	//if (pdrv >= N_DRIVES) return STA_NOINIT;/* Supports master/slave */
	if (Init) return Stat;	/* Returns current status if initialization has been done */

	//init_port();	/* Initialize the ATA control port and reset drives */

	// Reset most likely controlled by unity
	// No access to this register device control
	//write_ata(REG_DEVCTRL, SRST);	/* Set software reset */
	//REG_DEVCTRL = SRST;
	//delay_ms(20);
	//write_ata(REG_DEVCTRL, 0);		/* Release software reset */
	//REG_DEVCTRL = 0;
	//delay_ms(20);

	
	ex = 0;
	IDE_HEAD = 0;
	if (wait_stat(3000, DRDY)) {

		// Unity does not give access to features register
		//IDE_FEATURES = 0x02;
		//IDE_SECT_CNT = 0x00;
		//IDE_CMD_STAT = CMD_SETFEATURES;
		// write_ata(REG_FEATURES, 0x03);	/* Set default PIO mode wo IORDY */
		// write_ata(REG_COUNT, 0x01);
		// write_ata(REG_COMMAND, CMD_SETFEATURES);
		if (wait_stat(1000, 0)) {
			ex |= 1 << n;
			Stat = 0;
		}
	}

	Init = 1;
	return Stat;
}



/*-----------------------------------------------------------------------*/
/* Return Disk Status                                                    */
/*-----------------------------------------------------------------------*/

DSTATUS disk_status (
	BYTE pdrv		/* Physical drive nmuber (0/1) */
)
{
	if (pdrv >= 1) return STA_NOINIT;	/* Supports only single drive */
	return Stat;
}



/*-----------------------------------------------------------------------*/
/* Read Sector(s)                                                        */
/*-----------------------------------------------------------------------*/

DRESULT disk_read (
	BYTE pdrv,		/* Physical drive nmuber (0/1) */
	BYTE *buff,		/* Data buffer to store read data */
	DWORD sector,	/* Sector number (LBA) */
	UINT count		/* Sector count (1..128) */
)
{
	BYTE stat;

	if (pdrv >= 1 || !count || sector > 0xFFFFFFF) return RES_PARERR;
	if (Stat & STA_NOINIT) return RES_NOTRDY;

	/* Issue Read Setor(s) command */
	if (!issue_rwcmd(pdrv, CMD_READ, sector, count)) return RES_ERROR;

	/* Receive data blocks */
	printf("read1 %d", IDE_CMD_STAT);
	do {
		if (!wait_stat(2000, DRQ)) return RES_ERROR; 	/* Wait for a sector prepared */
		read_block(buff);	/* Read a sector */
		buff += 512;
		printf("read2");
	} while (--count);		/* Repeat all sectors read */
printf("read3");
	// read_ata(REG_ALTSTAT);
	// read_ata(REG_STATUS);
	stat = IDE_CMD_STAT;

	return RES_OK;
}



/*-----------------------------------------------------------------------*/
/* Write Sector(s)                                                       */
/*-----------------------------------------------------------------------*/

#ifdef _USE_WRITE
DRESULT disk_write (
	BYTE pdrv,			/* Physical drive nmuber (0/1) */
	const BYTE *buff,	/* Data to be written */
	DWORD sector,		/* Sector number (LBA) */
	UINT count			/* Sector count (1..128) */
)
{
	BYTE stat;

	if (pdrv >= 1 || !count || sector > 0xFFFFFFF) return RES_PARERR;
	if (Stat & STA_NOINIT) return RES_NOTRDY;

	/* Issue Write Setor(s) command */
	if (!issue_rwcmd(pdrv, CMD_WRITE, sector, count)) return RES_ERROR;

	/* Send data blocks */
	do {
		if (!wait_stat(2000, DRQ)) return RES_ERROR;	/* Wait for request to send data */
		write_block(buff);	/* Send a sector */
		buff += 512;
	} while (--count);		/* Repeat until all sector sent */

	/* Wait for end of write process */
	if (!wait_stat(1000, 0)) return RES_ERROR;
	stat = IDE_CMD_STAT;
	// read_ata(REG_ALTSTAT);
	// read_ata(REG_STATUS);

	return RES_OK;
}
#endif


/*-----------------------------------------------------------------------*/
/* Miscellaneous Functions                                               */
/*-----------------------------------------------------------------------*/

#ifdef _USE_IOCTL
DRESULT disk_ioctl (
	BYTE pdrv,		/* Physical drive nmuber (0/1) */
	BYTE cmd,		/* Control code */
	void *buff		/* Buffer to send/receive data block */
)
{
	BYTE n, w, ofs, dl, dh, *ptr = (BYTE*)buff;
	BYTE stat;

	if (pdrv >= 1) return RES_PARERR;
	if (Stat & STA_NOINIT) return RES_NOTRDY;

	switch (cmd) {
		case CTRL_SYNC :		/* Nothing to do */
			return RES_OK;

		case GET_SECTOR_COUNT :	/* Get number of sectors on the disk (DWORD) */
			ofs = 60; w = 2; n = 0;
			break;

		case GET_BLOCK_SIZE :	/* Get erase block size in sectors (DWORD) */
			*(DWORD*)buff = 1;
			return RES_OK;

		case ATA_GET_REV :		/* Get firmware revision (8 chars) */
			ofs = 23; w = 4; n = 4;
			break;

		case ATA_GET_MODEL :	/* Get model name (40 chars) */
			ofs = 27; w = 20; n = 20;
			break;

		case ATA_GET_SN :		/* Get serial number (20 chars) */
			ofs = 10; w = 10; n = 10;
			break;

		default:
			return RES_PARERR;
	}

printf("world1");
	if (!wait_stat(1000, 0)) return RES_ERROR;	/* Select device */
	//write_ata(REG_DEV, pdrv ? DEV : 0);
	IDE_HEAD = 0;
	printf("world2");
	if (!wait_stat(1000, DRDY)) return RES_ERROR;
	//write_ata(REG_COMMAND, CMD_IDENTIFY);	/* Get device ID data block */
	IDE_CMD_STAT = CMD_IDENTIFY;
	printf("world3");
	if (!wait_stat(1000, DRQ)) return RES_ERROR;	/* Wait for data ready */
	printf("world4");
	read_block_part(ptr, ofs, w);
	printf("world5");
	while (n--) {				/* Swap byte order */
		dl = *ptr++; dh = *ptr--;
		*ptr++ = dh; *ptr++ = dl; 
	}

	stat = IDE_CMD_STAT;
	// read_ata(REG_ALTSTAT);
	// read_ata(REG_STATUS);

	return RES_OK;
}
#endif


/*-----------------------------------------------------------------------*/
/* Device timer interrupt procedure                                      */
/*-----------------------------------------------------------------------*/
/* This function must be called in period of 10ms */

void disk_timerproc (void)
{
	UINT n;


	n = Timer;					/* 100Hz decrement timer */
	if (n) Timer = --n;
}

