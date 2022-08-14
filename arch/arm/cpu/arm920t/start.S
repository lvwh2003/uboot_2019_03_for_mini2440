/* SPDX-License-Identifier: GPL-2.0+ */
/*
 *  armboot - Startup Code for ARM920 CPU-core
 *
 *  Copyright (c) 2001	Marius Gröger <mag@sysgo.de>
 *  Copyright (c) 2002	Alex Züpke <azu@sysgo.de>
 *  Copyright (c) 2002	Gary Jennejohn <garyj@denx.de>
 */

#include <asm-offsets.h>
#include <common.h>
#include <config.h>

/*
 *************************************************************************
 *
 * Startup Code (called from the ARM reset exception vector)
 *
 * do important init only if we don't start from memory!
 * relocate armboot to ram
 * setup stack
 * jump to second stage
 *
 *************************************************************************
 */
.globl  _TEXT_BASE
_TEXT_BASE:
        .word   _start

/*
 * These are defined in the board-specific linker script.                                                       
 */
.globl _bss_start                                                                                               
_bss_start:
        .word __bss_start                                                                                       

.globl _bss_end                                                                                                 
_bss_end:
        .word _end 


	.globl	reset

reset:
	/*
	 * set the cpu to SVC32 mode
	 */
	mrs	r0, cpsr
	bic	r0, r0, #0x1f
	orr	r0, r0, #0xd3
	msr	cpsr, r0

#if	defined(CONFIG_AT91RM9200DK) || defined(CONFIG_AT91RM9200EK)
	/*
	 * relocate exception table
	 */
	ldr	r0, =_start
	ldr	r1, =0x0
	mov	r2, #16
copyex:
	subs	r2, r2, #1
	ldr	r3, [r0], #4
	str	r3, [r1], #4
	bne	copyex
#endif

#ifdef CONFIG_S3C24X0
        /* turn off the watchdog */

# if defined(CONFIG_S3C2400)
#  define pWTCON        0x15300000
#  define INTMSK        0x14400008      /* Interupt-Controller base addresses */
#  define CLKDIVN       0x14800014      /* clock divisor register */
#else
#  define pWTCON        0x53000000
#  define INTMSK        0x4A000008      /* Interupt-Controller base addresses */
#  define INTSUBMSK     0x4A00001C
#  define CLKDIVN       0x4C000014      /* clock divisor register */
# endif
#define CLK_CTL_BASE    0x4C000000      /* tekkaman */
#define MDIV_405        0x7f << 12      /* tekkaman */
#define PSDIV_405       0x21            /* tekkaman */
#define MDIV_200        0xa1 << 12      /* tekkaman */
#define PSDIV_200       0x31            /* tekkaman */

#  define MPLLCON			0x4C000004
#  define UPLLCON			0x4C000008

#  define CLKDIV_VAL	5
#  define M_MDIV	0x7f				/* XTal=12.0MHz MPLL=405MHz */
#  define M_PDIV	2
#  define M_SDIV	1
#  define U_MDIV	0x38				/* XTal=12.0MHz UPLL=48MHz */
#  define U_PDIV	2
#  define U_SDIV	2


        ldr     r0, =pWTCON
        mov     r1, #0x0
        str     r1, [r0]

        /*
         * mask all IRQs by setting all bits in the INTMR - default
         */
        mov     r1, #0xffffffff
        ldr     r0, =INTMSK
        str     r1, [r0]
# if defined(CONFIG_S3C2410)
        ldr     r1, =0x7ff
        ldr     r0, =INTSUBMSK
        str     r1, [r0]
# endif
#if defined(CONFIG_S3C2440)
        ldr     r1, =0x7fff
        ldr     r0, =INTSUBMSK
        str     r1, [r0]
#endif

#if defined(CONFIG_S3C2440)
        
	/* FCLK:HCLK:PCLK = 1:4:8 */
        ldr     r0, =CLKDIVN
        mov     r1, #5
        str     r1, [r0]

        mrc     p15, 0, r1, c1, c0, 0   
        orr     r1, r1, #0xc0000000             
        mcr     p15, 0, r1, c1, c0, 0   

	ldr	r0,=UPLLCON						/* ÅäÖÃUPLL */
	ldr	r1,=((U_MDIV<<12) + (U_PDIV<<4) + U_SDIV)
	str	r1,[r0]
	
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	ldr	r0,=MPLLCON						/* ÅäÖÃMPLL */
	ldr	r1,=((M_MDIV<<12) + (M_PDIV<<4) + M_SDIV)
	str	r1,[r0]

       @ mov     r1, #CLK_CTL_BASE       
       @ mov     r2, #MDIV_405   
       @ add     r2, r2, #PSDIV_405      
       @ str     r2, [r1, #0x04]         /* MPLLCON tekkaman */

#else
        /* FCLK:HCLK:PCLK = 1:2:4 */
        /* default FCLK is 120 MHz ! */
        ldr     r0, =CLKDIVN
        mov     r1, #3
        str     r1, [r0]


        mrc     p15, 0, r1, c1, c0, 0   
        orr     r1, r1, #0xc0000000     
        mcr     p15, 0, r1, c1, c0, 0   /*write ctrl register tekkaman*/


        mov     r1, #CLK_CTL_BASE       /* tekkaman*/
        mov     r2, #MDIV_200   
        add     r2, r2, #PSDIV_200      
        str     r2, [r1, #0x04]
#endif
#endif  /* CONFIG_S3C24X0 */




	/*
	 * we do sys-critical inits only at reboot,
	 * not when booting from ram!
	 */
#ifndef CONFIG_SKIP_LOWLEVEL_INIT
	bl	cpu_init_crit
#endif


	adr  r0, _TEXT_BASE
	ldr  r1, =CONFIG_SYS_TEXT_BASE
	cmp  r0, r1
        beq  stack_setup

/***************** NAND_BOOT *************************************************/

//#define STACK_BASE 0x33f00000
//#define STACK_SIZE 0x10000
//       .align  2
//DW_STACK_START: .word   STACK_BASE+STACK_SIZE-4
#define  DW_STACK_START   0x33e0fffc  
//#define  DW_STACK_START   0x33f0fffc  

#define LENGTH_UBOOT 0x60000
#define NAND_CTL_BASE 0x4E000000

#ifdef CONFIG_S3C2440
/* Offset */
#define oNFCONF 0x00
#define oNFCONT 0x04
#define oNFCMD 0x08
#define oNFSTAT 0x20

        @ reset NAND
        mov     r1, #NAND_CTL_BASE
        ldr     r2, =( (7<<12)|(7<<8)|(7<<4)|(0<<0) )
        str     r2, [r1, #oNFCONF]
        ldr     r2, [r1, #oNFCONF]

        ldr     r2, =( (1<<4)|(0<<1)|(1<<0) )   @ Active low CE Control 
        str     r2, [r1, #oNFCONT]
        ldr     r2, [r1, #oNFCONT]

        ldr     r2, =(0x6)      @ RnB Clear
        str     r2, [r1, #oNFSTAT]
        ldr     r2, [r1, #oNFSTAT]

        mov     r2, #0xff       @ RESET command
        strb    r2, [r1, #oNFCMD]

        mov     r3, #0  @ wait
nand1:
        add     r3, r3, #0x1
        cmp     r3, #0xa
        blt     nand1

nand2:
        ldr     r2, [r1, #oNFSTAT]      @ wait ready
        tst     r2, #0x4
        beq     nand2


        ldr     r2, [r1, #oNFCONT]
        orr     r2, r2, #0x2    @ Flash Memory Chip Disable
        str     r2, [r1, #oNFCONT]

        @ get read to call C functions (for nand_read())
        ldr     sp, =DW_STACK_START      @ setup stack pointer
        mov     fp, #0  @ no previous frame, so fp=0

        @ copy U-Boot to RAM
        ldr     r0, =CONFIG_SYS_TEXT_BASE
        mov     r1, #0x0
        mov     r2, #LENGTH_UBOOT
        bl      nand_read_ll
        tst     r0, #0x0
        beq     ok_nand_read

bad_nand_read:
loop2:
        b       loop2   @ infinite loop
ok_nand_read:
        @ verify
#ifdef CONFIG_MINI2440_ASM_PRINT
	bl 	print_init_log
#endif
        mov     r0, #0
        ldr     r1, =CONFIG_SYS_TEXT_BASE
        mov     r2, #0x400      @ 4 bytes * 1024 = 4K-bytes
go_next:
        ldr     r3, [r0], #4
        ldr     r4, [r1], #4
        teq     r3, r4
        bne     notmatch
        subs    r2, r2, #4
        beq     stack_setup
        bne     go_next

notmatch:
loop3:
        b       loop3   @ infinite loop
#endif
        /* Set up the stack                                                 */
stack_setup:
        ldr     r0, =CONFIG_SYS_TEXT_BASE          /* upper 128 KiB: relocated uboot   */
        sub     r0, r0, #CONFIG_SYS_MALLOC_LEN  /* malloc area              */
        sub     r0, r0, #CONFIG_SYS_GBL_DATA_SIZE /* bdinfo                 */
#ifdef CONFIG_USE_IRQ
        sub     r0, r0, #(CONFIG_STACKSIZE_IRQ+CONFIG_STACKSIZE_FIQ)
#endif
        sub     sp, r0, #12             /* leave 3 words for abort-stack    */

@clear_bss:
@        ldr     r0, _bss_start          /* find start of bss segment        */
@        ldr     r1, _bss_end            /* stop here                        */
@        mov     r2, #0x00000000         /* clear                            */

@clbss_l:str     r2, [r0]                /* clear loop...                    */
@        add     r0, r0, #4
@        cmp     r0, r1
@        ble     clbss_l
#ifdef CONFIG_S3C2440
        #ldr     pc, _start_armboot
	ldr     pc, =_main
#else
	bl	_main
#endif

_start_armboot: .word _main


/*------------------------------------------------------------------------------*/

	.globl	c_runtime_cpu_setup
c_runtime_cpu_setup:

	mov	pc, lr

/*
 *************************************************************************
 *
 * CPU_init_critical registers
 *
 * setup important registers
 * setup memory timing
 *
 *************************************************************************
 */
#ifdef CONFIG_MINI2440_ASM_PRINT
print_init_log:

/*init uart io*/
	ldr	r0, =0x56000070
	ldr	r1, =0x002AFAAA
	str	r1, [r0]

	ldr	r0, =0x56000078
	ldr	r1, =0x000007FF
	str	r1, [r0]

#define MINI2440_ULCON0 0x50000000
#define MINI2440_UCON0 0x50000004
#define MINI2440_UFCON0 0x50000008
#define MINI2440_UMCON0 0x5000000c
#define MINI2440_UBRDIV0 0x50000028

/*init uart controller*/
	ldr r0,=MINI2440_ULCON0
	ldr r1,=0x3
	str r1,[r0]

	ldr r0,=MINI2440_UCON0
	ldr r1,=0x245
	str r1,[r0]

	ldr r0,=MINI2440_UFCON0
	ldr r1,=0x1
	str r1,[r0]

	ldr r0,=MINI2440_UMCON0
	ldr r1,=0x0
	str r1,[r0]

	ldr r0,=MINI2440_UBRDIV0
	ldr r1,=0x1a
	str r1,[r0]

/*send char to tx buffer*/
	ldr	r0, =0x50000020

	ldr	r1,='T'
	str r1, [r0]

	ldr	r1, ='h'
	str r1, [r0]

	ldr	r1, ='i'
	str r1, [r0]

	ldr	r1, ='s'
	str r1, [r0]

	ldr	r1, =' '
	str r1, [r0]

	ldr	r1, ='i'
	str r1, [r0]

	ldr r1, ='s'
	str r1, [r0]

	ldr	r1, =' '
	str r1, [r0]

	ldr	r1, ='l'
	str r1, [r0]

	ldr	r1, ='o'
	str r1, [r0]

	ldr	r1, ='g'
	str r1, [r0]

	ldr	r1, ='.'
	str r1, [r0]

	mov pc, lr
#endif

#ifndef CONFIG_SKIP_LOWLEVEL_INIT
cpu_init_crit:
	/*
	 * flush v4 I/D caches
	 */
	mov	r0, #0
	mcr	p15, 0, r0, c7, c7, 0	/* flush v3/v4 cache */
	mcr	p15, 0, r0, c8, c7, 0	/* flush v4 TLB */

	/*
	 * disable MMU stuff and caches
	 */
	mrc	p15, 0, r0, c1, c0, 0
	bic	r0, r0, #0x00002300	@ clear bits 13, 9:8 (--V- --RS)
	bic	r0, r0, #0x00000087	@ clear bits 7, 2:0 (B--- -CAM)
	orr	r0, r0, #0x00000002	@ set bit 1 (A) Align
	orr	r0, r0, #0x00001000	@ set bit 12 (I) I-Cache
	mcr	p15, 0, r0, c1, c0, 0

#ifndef CONFIG_SKIP_LOWLEVEL_INIT_ONLY
	/*
	 * before relocating, we have to setup RAM timing
	 * because memory timing is board-dependend, you will
	 * find a lowlevel_init.S in your board directory.
	 */
	mov	ip, lr

	bl	lowlevel_init
	mov	lr, ip
#endif
	mov	pc, lr
#endif /* CONFIG_SKIP_LOWLEVEL_INIT */
