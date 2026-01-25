/* 
	boot.S

	kernel boot code, shall be used with newer rpi3 firmware that builds in
	armstub, which boots kernel at 0x80000 and EL2

	no mmu/pgtable, single core, no bootstack
*/ 	

#include "param.h"
#include "sysregs.h"
#include "plat.h"

.section ".text.boot"

.globl _start
_start:		
	// MMU off, until we set pgtables. cf: sysregs.h
	ldr	x0, =SCTLR_VALUE_MMU_DISABLED  
	msr	sctlr_el1, x0
	
	/* -------- Exception level switch -------------- */
	// Check the current exception level: EL2 or EL3?
	mrs x0, CurrentEL
  	lsr x0, x0, #2
	cmp x0, #3
	beq el3

	// Current EL is EL2 
	// set EL1 to be running in AArch64
	mrs	x0, hcr_el2
	orr	x0, x0, #HCR_RW  
	msr	hcr_el2, x0

	// prepare to switch to EL1
	mov x0, #SPSR_VALUE
	msr	spsr_el2, x0

	adr	x0, el1_entry
	msr	elr_el2, x0
	eret	// switch to EL1

el3: 		// Current EL: EL3
	// 	With the rpi3 firmware (armstub) or qemu, kernel always starts in EL2; 
	//  We leave EL3 code here for completeness
  	ldr x0, =HCR_VALUE
  	msr hcr_el2, x0

	ldr	x0, =SCR_VALUE
	msr	scr_el3, x0

	// prepare to switch to EL1
	ldr	x0, =SPSR_VALUE
	msr	spsr_el3, x0

	adr	x0, el1_entry		
	msr	elr_el3, x0	
	eret	// switch to EL1				

	/* ------- Start of EL1 execution ------- */
el1_entry:	
	/* Below: clean up bss region. 
	  bss_begin/end must be 8 bytes aligned, per the linker script */
	// quest: boot
	/* STUDENT_TODO: your code here */

	adr x0, bss_begin
	adr x1, bss_end
	sub x1, x1, x0

	bl 	memzero_aligned
	
setup_sp: 	
	// quest: boot. set sp to somewhere above PHYS_BASE, far away from kernel image
	/* STUDENT_TODO: your code here */

	mov sp, 0x400000 // Set stack pointer so that we have 4MB of room

	// NB: we aren't use sp yet -- until we start to execute kernel_main(below)

	// install irq vectors
	ldr x0, =vectors	// load VBAR_EL1 vector table addr
	msr	vbar_el1, x0	

	// load the addr of kernel_main
	bl kernel_main  	// kernel.c
	