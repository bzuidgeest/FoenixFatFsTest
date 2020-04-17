/*----------------------------------------------------------------------/
/ Low level disk I/O module function checker                            /
/-----------------------------------------------------------------------/
/ WARNING: The data on the target drive will be lost!
*/

void *heap_start = (void * )0x190000, *heap_end = (void * )0x193000;

#include <stdio.h>
#include <string.h>
#include "ff.h"         /* Declarations of sector size */
#include "diskio.h"     /* Declarations of disk functions */

//#include <sys/types.h>
#include "../foenixLibrary/vicky.h"
//#include "../foenixLibrary/FMX_printf.h"
#include "../foenixLibrary/timer.h"
#include "../foenixLibrary/interrupt.h"
#define IDE_CMD_STAT  		(*(volatile unsigned char *)0xAFE837)

char spinner[] = {'|', '/', '-', '\\', '|', '/', '-', '\\'};
char spinnerState = 0;
char spinnerStateDisk = 0;

void IRQHandler(void)              
{          
	int reg = 0;

	if (reg = (INT_PENDING_REG0 & FNX0_INT02_TMR0))
	{
		
		textScreen[6] = spinner[spinnerState];
		if (spinnerState < 7)
			spinnerState++;
		else
		{
			spinnerState = 0;
		}

		//disk_timerproc();

		reg = INT_PENDING_REG0 & FNX0_INT02_TMR0;
		INT_PENDING_REG0 = reg;
	}   

	if (reg = (INT_PENDING_REG3 & FNX3_INT02_IDE))
	{
		
		textScreen[10] = spinner[spinnerStateDisk];
		if (spinnerStateDisk < 7)
			spinnerStateDisk++;
		else
		{
			spinnerStateDisk = 0;
		}

		printf("interrupt %d", IDE_CMD_STAT);

		reg = INT_PENDING_REG3 & INT_PENDING_REG3;
		INT_PENDING_REG3 = reg;
	}   
}

void COPHandler(void)              
{             
}

void BRKHandler(void)              
{             
}

static DWORD pn (       /* Pseudo random number generator */
    DWORD pns   /* 0:Initialize, !0:Read */
)
{
    static DWORD lfsr;
    UINT n;


    if (pns) {
        lfsr = pns;
        for (n = 0; n < 32; n++) pn(0);
    }
    if (lfsr & 1) {
        lfsr >>= 1;
        lfsr ^= 0x80200003;
    } else {
        lfsr >>= 1;
    }
    return lfsr;
}


int test_diskio (
    BYTE pdrv,      /* Physical drive number to be checked (all data on the drive will be lost) */
    UINT ncyc,      /* Number of test cycles */
    DWORD* buff,    /* Pointer to the working buffer */
    UINT sz_buff    /* Size of the working buffer in unit of byte */
)
{
    UINT n, cc, ns;
    DWORD sz_drv, lba, lba2, sz_eblk, pns = 1;
    WORD sz_sect;
    BYTE *pbuff = (BYTE*)buff;
    DSTATUS ds;
    DRESULT dr;


    printf("test_diskio(%u, %u, 0x%08X, 0x%08X)\n", pdrv, ncyc, 0, sz_buff);

    if (sz_buff < FF_MAX_SS + 8) {
        printf("Insufficient work area to run the program.\n");
        return 1;
    }

    for (cc = 1; cc <= ncyc; cc++) {
        printf("**** Test cycle %u of %u start ****\n", cc, ncyc);

        printf(" disk_initalize(%u)", pdrv);
        ds = disk_initialize(pdrv);
        if (ds & STA_NOINIT) {
            printf(" - failed.\n");
            return 2;
        } else {
            printf(" - ok.\n");
        }
// extra thingy for testing getting the model
//disk_ioctl(0, ATA_GET_MODEL, 0);

        printf("**** Get drive size ****\n");
        printf(" disk_ioctl(%u, GET_SECTOR_COUNT, 0x%08X)", pdrv, (unsigned long)&sz_drv);
        sz_drv = 0;
        dr = disk_ioctl(pdrv, GET_SECTOR_COUNT, &sz_drv);
        if (dr == RES_OK) {
            printf(" - ok.\n");
        } else {
            printf(" - failed.\n");
            return 3;
        }
        if (sz_drv < 128) {
            printf("Failed: Insufficient drive size to test.\n");
            return 4;
        }
        printf(" Number of sectors on the drive %u is %lu.\n", pdrv, sz_drv);

#if FF_MAX_SS != FF_MIN_SS
        printf("**** Get sector size ****\n");
        printf(" disk_ioctl(%u, GET_SECTOR_SIZE, 0x%X)", pdrv, (UINT)&sz_sect);
        sz_sect = 0;
        dr = disk_ioctl(pdrv, GET_SECTOR_SIZE, &sz_sect);
        if (dr == RES_OK) {
            printf(" - ok.\n");
        } else {
            printf(" - failed.\n");
            return 5;
        }
        printf(" Size of sector is %u bytes.\n", sz_sect);
#else
        sz_sect = FF_MAX_SS;
#endif

        printf("**** Get block size ****\n");
        printf(" disk_ioctl(%u, GET_BLOCK_SIZE, 0x%X)", pdrv, (unsigned long)&sz_eblk);
        sz_eblk = 0;
        dr = disk_ioctl(pdrv, GET_BLOCK_SIZE, &sz_eblk);
        if (dr == RES_OK) {
            printf(" - ok.\n");
        } else {
            printf(" - failed.\n");
        }
        if (dr == RES_OK || sz_eblk >= 2) {
            printf(" Size of the erase block is %lu sectors.\n", sz_eblk);
        } else {
            printf(" Size of the erase block is unknown.\n");
        }

        /* Single sector write test */
        printf("**** Single sector write test ****\n");
        lba = 0;
        for (n = 0, pn(pns); n < sz_sect; n++)
		{ 
			//printf("\n%d",n);
			//pbuff[n] = n;//(BYTE)pn(0);
			pbuff[n] = (BYTE)pn(0);
		}
		//printf("\nwrite %d %d %d %d .....", pbuff[0], pbuff[1], pbuff[2], pbuff[3]);
        printf(" disk_write(%u, 0x%X, %lu, 1)", pdrv, pbuff, lba);
        dr = disk_write(pdrv, pbuff, lba, 1);
        if (dr == RES_OK) {
            printf(" - ok.\n");
        } else {
            printf(" - failed.\n");
            return 6;
        }
        printf(" disk_ioctl(%u, CTRL_SYNC, NULL)", pdrv);
        dr = disk_ioctl(pdrv, CTRL_SYNC, 0);
        if (dr == RES_OK) {
            printf(" - ok.\n");
        } else {
            printf(" - failed.\n");
            return 7;
        }
        memset(pbuff, 0, sz_sect);
        printf(" disk_read(%u, 0x%X, %lu, 1)", pdrv, pbuff, lba);
        dr = disk_read(pdrv, pbuff, lba, 1);
        if (dr == RES_OK) {
            printf(" - ok.\n");
        } else {
            printf(" - failed.\n");
            return 8;
        }
		//printf("\n expected: %d got: %d", (BYTE)pn(0), pbuff[0]);
        for (n = 0, pn(pns); n < sz_sect && pbuff[n] == (BYTE)pn(0); n++) 
		//for (n = 0, pn(pns); n < sz_sect && pbuff[n] == (BYTE)n; n++) 
		{
			// if (n < 4)
			// 	printf("\n expected: %d got: %d", n, pbuff[n]);
		}
		//printf("\n expected: %d got: %d", n, pbuff[n]);
        if (n == sz_sect) {
            printf(" Read data matched.\n");
        } else {
            printf(" Read data differs from the data written. %d\n", n);
            return 10;
        }
        pns++;

        printf("**** Multiple sector write test ****\n");
        lba = 5; ns = sz_buff / sz_sect;
        if (ns > 4) ns = 4;
        if (ns > 1) {
			for (n = 0, pn(pns); n < (UINT)(sz_sect * ns); n++) pbuff[n] = (BYTE)pn(0);
            //for (n = 0, pn(pns); n < (UINT)(sz_sect * ns); n++) pbuff[n] = n;//(BYTE)pn(0);
            printf(" disk_write(%u, 0x%X, %lu, %u)", pdrv, 0, lba, ns);
            dr = disk_write(pdrv, pbuff, lba, ns);
            if (dr == RES_OK) {
                printf(" - ok.\n");
            } else {
                printf(" - failed.\n");
                return 11;
            }
            printf(" disk_ioctl(%u, CTRL_SYNC, NULL)", pdrv);
            dr = disk_ioctl(pdrv, CTRL_SYNC, 0);
            if (dr == RES_OK) {
                printf(" - ok.\n");
            } else {
                printf(" - failed.\n");
                return 12;
            }
            memset(pbuff, 0, sz_sect * ns);
            printf(" disk_read(%u, 0x%X, %lu, %u)", pdrv, pbuff, lba, ns);
            dr = disk_read(pdrv, pbuff, lba, ns);
            if (dr == RES_OK) {
                printf(" - ok.\n");
            } else {
                printf(" - failed.\n");
                return 13;
            }
            
			//for (n = 0, pn(pns); n < (UINT)(sz_sect * ns) && pbuff[n] == (BYTE)n; n++)
			for (n = 0, pn(pns); n < (UINT)(sz_sect * ns) && pbuff[n] == (BYTE)pn(0); n++)
			{
				//if (n % 256 == 0)
				// if (n > 500 && n < 520)
				  	//printf("\nN = %d %d %d", n, n, pbuff[n]);
			}

			// printf("\nX = %d", pbuff[511]);
			// printf("\nX = %d", pbuff[512]);
			// printf("\nX = %d", pbuff[513]);
			// printf("\nX = %d", pbuff[514]);
			// printf("\nX = %d", pbuff[515]);

			// printf("\nX = %d", pbuff[1023]);
			// printf("\nX = %d", pbuff[1024]);
			// printf("\nX = %d", pbuff[1025]);
			// printf("\nX = %d", pbuff[1026]);
			// printf("\nX = %d", pbuff[1027]);

            if (n == (UINT)(sz_sect * ns)) {
                printf(" Read data matched.\n");
            } else {
                printf(" Read data differs from the data written.\n");
                return 14;
            }
        } else {
            printf(" Test skipped.\n");
        }
        pns++;

        printf("**** Single sector write test (unaligned buffer address) ****\n");
        lba = 5;
        for (n = 0, pn(pns); n < sz_sect; n++) pbuff[n+3] = (BYTE)pn(0);
        printf(" disk_write(%u, 0x%X, %lu, 1)", pdrv, (unsigned long)(pbuff+3), lba);
        dr = disk_write(pdrv, pbuff+3, lba, 1);
        if (dr == RES_OK) {
            printf(" - ok.\n");
        } else {
            printf(" - failed.\n");
            return 15;
        }
        printf(" disk_ioctl(%u, CTRL_SYNC, NULL)", pdrv);
        dr = disk_ioctl(pdrv, CTRL_SYNC, 0);
        if (dr == RES_OK) {
            printf(" - ok.\n");
        } else {
            printf(" - failed.\n");
            return 16;
        }
        memset(pbuff+5, 0, sz_sect);
        printf(" disk_read(%u, 0x%X, %lu, 1)", pdrv, (unsigned long)(pbuff+5), lba);
        dr = disk_read(pdrv, pbuff+5, lba, 1);
        if (dr == RES_OK) {
            printf(" - ok.\n");
        } else {
            printf(" - failed.\n");
            return 17;
        }
        for (n = 0, pn(pns); n < sz_sect && pbuff[n+5] == (BYTE)pn(0); n++) ;
        if (n == sz_sect) {
            printf(" Read data matched.\n");
        } else {
            printf(" Read data differs from the data written.\n");
            return 18;
        }
        pns++;

        printf("**** 4GB barrier test ****\n");
        if (sz_drv >= 128 + 0x80000000 / (sz_sect / 2)) {
            lba = 6; lba2 = lba + 0x80000000 / (sz_sect / 2);
            for (n = 0, pn(pns); n < (UINT)(sz_sect * 2); n++) pbuff[n] = (BYTE)pn(0);
            printf(" disk_write(%u, 0x%X, %lu, 1)", pdrv, (unsigned long)pbuff, lba);
            dr = disk_write(pdrv, pbuff, lba, 1);
            if (dr == RES_OK) {
                printf(" - ok.\n");
            } else {
                printf(" - failed.\n");
                return 19;
            }
            printf(" disk_write(%u, 0x%X, %lu, 1)", pdrv, (unsigned long)(pbuff+sz_sect), lba2);
            dr = disk_write(pdrv, pbuff+sz_sect, lba2, 1);
            if (dr == RES_OK) {
                printf(" - ok.\n");
            } else {
                printf(" - failed.\n");
                return 20;
            }
            printf(" disk_ioctl(%u, CTRL_SYNC, NULL)", pdrv);
            dr = disk_ioctl(pdrv, CTRL_SYNC, 0);
            if (dr == RES_OK) {
            printf(" - ok.\n");
            } else {
                printf(" - failed.\n");
                return 21;
            }
            memset(pbuff, 0, sz_sect * 2);
            printf(" disk_read(%u, 0x%X, %lu, 1)", pdrv, (unsigned long)pbuff, lba);
            dr = disk_read(pdrv, pbuff, lba, 1);
            if (dr == RES_OK) {
                printf(" - ok.\n");
            } else {
                printf(" - failed.\n");
                return 22;
            }
            printf(" disk_read(%u, 0x%X, %lu, 1)", pdrv, (unsigned long)(pbuff+sz_sect), lba2);
            dr = disk_read(pdrv, pbuff+sz_sect, lba2, 1);
            if (dr == RES_OK) {
                printf(" - ok.\n");
            } else {
                printf(" - failed.\n");
                return 23;
            }
            for (n = 0, pn(pns); pbuff[n] == (BYTE)pn(0) && n < (unsigned long)(sz_sect * 2); n++) ;
            if (n == (UINT)(sz_sect * 2)) {
                printf(" Read data matched.\n");
            } else {
                printf(" Read data differs from the data written.\n");
                return 24;
            }
        } else {
            printf(" Test skipped.\n");
        }
        pns++;

        printf("**** Test cycle %u of %u completed ****\n\n", cc, ncyc);
    }

    return 0;
}

DWORD buff[FF_MAX_SS];  /* Working buffer (4 sector in size) */

void main (void)
{
    int rc;
	int clock = 14318000;
	//int spd = clock / 100;
	int spd = clock / 1;
    //DWORD buff[FF_MAX_SS];  /* Working buffer (4 sector in size) */


	// Emulator workarround for screen
	//set the display size - 128 x 64
	COLS_PER_LINE = 80;
	LINES_MAX = 60;
	//set the visible display size - 80 x 60
  	COLS_VISIBLE = 80;
	LINES_VISIBLE = 60;

	TIMER0_CHARGE_L = 0x00;
	TIMER0_CHARGE_M = 0x00;
	TIMER0_CHARGE_H = 0x00;
	TIMER0_CMP_L = (spd) & 0xFF;
	TIMER0_CMP_M = (spd >> 8) & 0xFF;
	TIMER0_CMP_H = (spd >> 16) & 0xFF;;
	
	TIMER0_CMP_REG = TMR0_CMP_RECLR;

	TIMER0_CTRL_REG = TMR_EN | TMR_UPDWN | TMR_SCLR;

	INT_MASK_REG0 = 0xFB; // unmask timer 0

	INT_MASK_REG0 = 0xFB; // unmask harddisk;

	// enable interrupts
	enableInterrupts();

	setEGATextPalette();
	clearTextScreen(' ', 0xD, 0xE);

	VKY_TXT_CURSOR_X_REG = 0;
	VKY_TXT_CURSOR_Y_REG = 0;

	

	printf("starting tests....");

    /* Check function/compatibility of the physical drive #0 */
    rc = test_diskio(0, 1, buff, sizeof(buff));

    if (rc) {
        printf("Sorry the function/compatibility test failed. (rc=%d)\nFatFs will not work with this disk driver.\n", rc);
    } else {
        printf("Congratulations! The disk driver works well.\n");
    }

	
	while(1);
    //return rc;
}

/*
// for FMX_printf
void _putchar(char character)
{
	if (character == '\n')
	{
		VKY_TXT_CURSOR_X_REG = 0;
		VKY_TXT_CURSOR_Y_REG++;

		if (VKY_TXT_CURSOR_Y_REG == LINES_VISIBLE)
		{
			VKY_TXT_CURSOR_Y_REG = 0;
		}

		return;
	}

	textScreen[(0x80 * VKY_TXT_CURSOR_Y_REG) + VKY_TXT_CURSOR_X_REG] = character;
	
	textScreenColor[(0x80 * VKY_TXT_CURSOR_Y_REG) + VKY_TXT_CURSOR_X_REG] = 0xE0;
	VKY_TXT_CURSOR_X_REG++;
	
	if (VKY_TXT_CURSOR_X_REG == COLS_VISIBLE)
	{
		VKY_TXT_CURSOR_X_REG = 0;
		VKY_TXT_CURSOR_Y_REG++;
		
		if (VKY_TXT_CURSOR_Y_REG == LINES_VISIBLE)
		{
			VKY_TXT_CURSOR_Y_REG = 0;
		}
	}
}
*/

void _abort(void) {

}

int close(int fd) {
    return 0;
}

int creat(const char *_name, int _mode) {
    return 0;
}


long lseek(int fd, long pos, int rel) {
    return 0;
}

int open(const char * _name, int _mode) {
    return 0;
}

size_t read(int fd, void *buffer, size_t len) {
    return 0;
}

int unlink(const char *filename) {
    return 0;
}

size_t write(int fd, void *buffer, size_t len) {
    size_t count;
	for (count = 0; count < len; count++)
	{
		if (((unsigned char *)buffer)[count] == '\n')
		{
			VKY_TXT_CURSOR_X_REG = 0;
			VKY_TXT_CURSOR_Y_REG++;

			if (VKY_TXT_CURSOR_Y_REG == LINES_VISIBLE)
			{
				VKY_TXT_CURSOR_Y_REG = 0;
			}

			continue;
		}

		textScreen[(0x80 * VKY_TXT_CURSOR_Y_REG) + VKY_TXT_CURSOR_X_REG] = ((unsigned char *)buffer)[count];
		
		textScreenColor[(0x80 * VKY_TXT_CURSOR_Y_REG) + VKY_TXT_CURSOR_X_REG] = 0xE0;
		/*
		textScreenColor[(0x80 * VKY_TXT_CURSOR_Y_REG) + VKY_TXT_CURSOR_X_REG] = color;
		color += 16;
		if (color == 0xF0)
			color = 0x10;*/
		
		VKY_TXT_CURSOR_X_REG++;
		
		if (VKY_TXT_CURSOR_X_REG == COLS_VISIBLE)
		{
			VKY_TXT_CURSOR_X_REG = 0;
			VKY_TXT_CURSOR_Y_REG++;
			
			if (VKY_TXT_CURSOR_Y_REG == LINES_VISIBLE)
			{
				VKY_TXT_CURSOR_Y_REG = 0;
			}
		}
	}
    return len;
}

//
// Missing STDLIB.H function
//
int    isatty(int fd) {
    // descriptors 0, 1 and 2 are STDIN_FILENO, STDOUT_FILENO and STDERR_FILENO
    return fd < 3;
}
