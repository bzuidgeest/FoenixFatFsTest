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


//$AF:E830..$AF:E83F - UNITY CHIP (IDE)

#include "stdio.h"
#include <sys/types.h>
//#include "ffconf.h" included in ff.h
#include "ff.h"
#include "diskio.h"

#define _USE_WRITE
#define _USE_IOCTL

#define IDE_DATA8			(*(volatile unsigned char *)0xAFE830)
#define IDE_CMD_STAT		(*(volatile unsigned char *)0xAFE837)
#define IDE_DATA			(*(volatile unsigned short *)0xAFE839)
#define IDE_DATA_LO			(*(volatile unsigned char *)0xAFE838)
#define IDE_DATA_HI			(*(volatile unsigned char *)0xAFE839)
#define IDE_ERROR			(*(volatile unsigned char *)0xAFE831)
#define IDE_FEATURES		(*(volatile unsigned char *)0xAFE831)
#define IDE_SECT_CNT  		(*(volatile unsigned char *)0xAFE832)
#define IDE_SECT_SRT  		(*(volatile unsigned char *)0xAFE833)
#define IDE_CLDR   			(*(volatile unsigned short *)0xAFE834)
#define IDE_CLDR_LO   		(*(volatile unsigned char *)0xAFE834)
#define IDE_CLDR_HI   		(*(volatile unsigned char *)0xAFE835)
#define IDE_HEAD      		(*(volatile unsigned char *)0xAFE836)

// status register
// ;7    6    5   4  3   2   1    0
// ;BSY DRDY DF DSC DRQ CORR IDX ERR

/* ATA commands */
#define CMD_READ		0x20	/* READ SECTOR(S) */
#define CMD_WRITE		0x30	/* WRITE SECTOR(S) */
#define CMD_IDENTIFY	0xEC	/* DEVICE IDENTIFY */
#define CMD_SETFEATURES	0xEF	/* SET FEATURES */

/* ATA register bit definitions */
#define	HEAD_LBA				0x40	/* REG_HEAD */
#define	HEAD_DEV				0x10	/* REG_HEAD */
#define	STATUS_BSY				0x80	/* REG_STATUS */
#define	STATUS_DRDY				0x40	/* REG_STATUS */
#define	STATUS_DRQ				0x08	/* REG_STATUS */
#define	STATUS_ERR				0x01	/* REG_STATUS */

#include "../foenixLibrary/interrupt.h"
//#include "../foenixLibrary/FMX_printf.h"
#include <stdio.h>
#include "../foenixLibrary/vicky.h"

extern char spinner[];

char spinnerState1 = 0;
char spinnerState2 = 0;
/*--------------------------------------------------------------------------

   Module Private Functions

---------------------------------------------------------------------------*/

/* Disk status */
static 
DSTATUS Stat = STA_NOINIT; 

/*-----------------------------------------------------------------------*/
/* Read an ATA register (Platform dependent)                             */
/*-----------------------------------------------------------------------*/

/* Read 512 bytes from ATA data register */
static
void read_block (
	BYTE *buf
)
{
	short c = 256, index = 0, data = 0;

	disableInterrupts();

	// dummy read, why is this needed?
	//data = IDE_DATA;
	do {	
		data = IDE_DATA;
		buf[index] = (data >> 8) & 0xFF;
		buf[index + 1] = data & 0xFF;
		index = index + 2;
	} while (c--);
	enableInterrupts();
}


/* Read 512 bytes from ATA data register but store a part of block */
static
void read_block_part (
	BYTE *buf,
	BYTE ofs,
	BYTE nw
)
{
	// loop termination relies on byte data type overflow
	BYTE c = 0, dl = 0, dh = 0;
	short index = 0, data = 0;

	// dummy read, why is this needed?
	data = IDE_DATA;

	disableInterrupts();

	do {	
		data = IDE_DATA;
		
		dh = (data >> 8) & 0xFF;
		dl = data & 0xFF;
		
		if (nw && (c >= ofs)) {	/* Pick up a part of block */
			*buf++ = dl; *buf++ = dh;
			nw--;

			//printf("\n%c", dl);
			//printf("\n%c", dh);
		}
	} while (++c); // loop termination relies on byte data type overflow

	enableInterrupts();
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
	BYTE c;
	short data = 0;

	c = 256;
	disableInterrupts();
	do {	/* Send 2 bytes/loop */
		IDE_DATA_LO = *buf++;
		IDE_DATA_HI = *buf++;
		//data = *buf++ | (*buf++ << 8);
		//IDE_DATA = data;
	} while (--c);
	enableInterrupts();
}
#endif



/*-----------------------------------------------------------------------*/
/* Wait for BSY goes 0 and the specified bit goes 1                                */
/*-----------------------------------------------------------------------*/

static
int wait_stat (	/* 0:Timeout or or ERR goes 1 */
	UINT ms,
	BYTE bit
)
{
	BYTE s;

	do {
		s = IDE_CMD_STAT;
		if ((s & STATUS_ERR)) 
		{
			
			printf("\nerror! %d", IDE_ERROR);
			return 0;	/* Abort when timeout or error occured */
		}
	} while ((s & STATUS_BSY) || (bit && !(bit & s)));		/* Wait for BSY goes 0 and the bit goes 1 */

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
	BYTE head = ((BYTE)(sector >> 24) & 0x0F) | HEAD_LBA;
	if (!wait_stat(1000, STATUS_DRDY)) return 0;
	IDE_HEAD = head;
	if (!wait_stat(1000, STATUS_DRDY)) return 0;
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
	/* Returns current status if initialization has been done */
	if (Stat != STA_NOINIT) return Stat;	

	IDE_HEAD = 0 | HEAD_LBA;
	if (wait_stat(3000, STATUS_DRDY)) {
		Stat = 0;
	}
	return Stat;
}

/*-----------------------------------------------------------------------*/
/* Return Disk Status                                                    */
/*-----------------------------------------------------------------------*/

DSTATUS disk_status (
	BYTE pdrv		/* Physical drive nmuber (0/1) */
)
{
	/* Supports only single drive */
	if (pdrv >= 1) return STA_NOINIT;	
	else return Stat;
}

/*-----------------------------------------------------------------------*/
/* Read Sector(s)                                                        */
/*-----------------------------------------------------------------------*/

// DRESULT disk_read (
// 	BYTE pdrv,		/* Physical drive nmuber (0/1) */
// 	BYTE *buff,		/* Data buffer to store read data */
// 	DWORD sector,	/* Sector number (LBA) */
// 	UINT count		/* Sector count (1..128) */
// )
// {
// 	BYTE stat;
// 	short dummy = 0;

// 	if (pdrv >= 1 || !count || sector > 0xFFFFFFF) return RES_PARERR;
// 	if (Stat & STA_NOINIT) return RES_NOTRDY;

// 	/* Issue Read Setor(s) command */
// 	if (!issue_rwcmd(pdrv, CMD_READ, sector, count)) return RES_ERROR;

// 	/* Receive data blocks */
// 	printf("\n count: %d sector: %d",count , sector);
	
// 	do {
// 		if (!wait_stat(2000, STATUS_DRQ)) return RES_ERROR; 	/* Wait for a sector prepared */
// 		printf("\nbuff %d", buff);
		
// 		// dummy read, why is this needed?
// 		// if (dummy == 0)
// 		// {
// 		dummy = IDE_DATA8;	
// 		// dummy = 1;
// 		// }
// 		read_block(buff);	/* Read a sector */
// 		buff += 512;
// 		// dummy read, why is this needed?
// 		//dummy = IDE_CMD_STAT;

// 	} while (--count);		/* Repeat all sectors read */
// //printf("read3");
// 	// read_ata(REG_ALTSTAT);
// 	// read_ata(REG_STATUS);
// 	stat = IDE_CMD_STAT;

// 	return RES_OK;
// }


DRESULT disk_read (
	BYTE pdrv,		/* Physical drive nmuber (0/1) */
	BYTE *buff,		/* Data buffer to store read data */
	DWORD sector,	/* Sector number (LBA) */
	UINT count		/* Sector count (1..128) */
)
{
	BYTE stat, i = 0, s = sector;
	short dummy = 0;

	if (pdrv >= 1 || !count || sector > 0xFFFFFFF) return RES_PARERR;
	if (Stat & STA_NOINIT) return RES_NOTRDY;

	// Do count single sector reads.
	for (i = 0; i < count; i++)
	{
	
		/* Issue Read Setor(s) command */
		if (!issue_rwcmd(pdrv, CMD_READ, sector, count)) return RES_ERROR;

		/* Receive data blocks */
		//printf("\n count: %d sector: %d", i, sector);
		
		if (!wait_stat(2000, STATUS_DRQ)) return RES_ERROR; 	/* Wait for a sector prepared */
		//printf("\nbuff %d", buff);
		
		dummy = IDE_DATA;	
		read_block(buff);	/* Read a sector */
		buff += 512;
		sector++;
		stat = IDE_CMD_STAT;
	
	}
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
	short dummy = 0;

	if (pdrv > 0 || !count || sector > 0xFFFFFFF) return RES_PARERR;
	if (Stat & STA_NOINIT) return RES_NOTRDY;

	/* Issue Write Setor(s) command */
	if (!issue_rwcmd(pdrv, CMD_WRITE, sector, count)) return RES_ERROR;
	//printf("\nCount: %d Sector: %d", count, sector);
	/* Send data blocks */
	do {
		if (!wait_stat(2000, STATUS_DRQ)) return RES_ERROR;	/* Wait for request to send data */
		//printf("\nbuff %d", buff);
		write_block(buff);	/* Send a sector */
		buff += 512;
		
		// dummy write, why is this needed?
		dummy = IDE_CMD_STAT;
		// asm nop;
		// asm nop;
		// asm nop;
		// asm nop;
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
			ofs = 60; w = 2; n = 2;
			break;

		case GET_BLOCK_SIZE :	/* Get erase block size in sectors (DWORD) */
			*(DWORD*)buff = 1;
			return RES_OK;

		case ATA_GET_REV :		/* Get firmware revision (8 chars) */
			ofs = 23; w = 4; n = 0;//n = 4;
			break;

		case ATA_GET_MODEL :	/* Get model name (40 chars) */
			ofs = 27; w = 20; n = 0;//n = 20;
			break;

		case ATA_GET_SN :		/* Get serial number (20 chars) */
			ofs = 10; w = 10; n = 0;//n = 10;
			break;

		default:
			return RES_PARERR;
	}

	if (!wait_stat(1000, 0)) return RES_ERROR;	/* Select device */
	IDE_HEAD = 0;
	if (!wait_stat(1000, STATUS_DRDY)) return RES_ERROR;
	IDE_CMD_STAT = CMD_IDENTIFY;
	if (!wait_stat(1000, STATUS_DRQ)) return RES_ERROR;	/* Wait for data ready */
	read_block_part(ptr, ofs, w);
	while (n--) {				/* Swap byte order */
		dl = *ptr++; dh = *ptr--;
		*ptr++ = dh; *ptr++ = dl; 
	}

	stat = IDE_CMD_STAT;

	return RES_OK;
}
#endif

  