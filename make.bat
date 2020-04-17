@echo off
cls

rem for hardware
wdc816as -DUSING_816 -DLARGE -V -L fxloader.asm -O fxloader.obj

wdc816cc -ML ata.c
wdc816cc -ML function_check.c
wdcln -HIE -T  -P00 ata.obj function_check.obj fxloader.obj -L../foenixLibrary/FMX -LML -LCL -O function_check.hex -C10000  -D20000

rem for simulator
rem wdc816cc -ML printf.c -bs
rem wdcln -HZ -G -V -T -P00 printf.obj c0l.obj -LCL -O printf.bin

rem output assembly
rem wdc816cc -ML printf.c -AT
