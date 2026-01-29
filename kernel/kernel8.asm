
build-rpi3qemu/kernel8.elf:     file format elf64-littleaarch64


Disassembly of section .text.boot:

0000000000080000 <_start>:
.section ".text.boot"

.globl _start
_start:		
	// MMU off, until we set pgtables. cf: sysregs.h
	ldr	x0, =SCTLR_VALUE_MMU_DISABLED  
   80000:	58000440 	ldr	x0, 80088 <setup_sp+0x1c>
	msr	sctlr_el1, x0
   80004:	d5181000 	msr	sctlr_el1, x0
	
	/* -------- Exception level switch -------------- */
	// Check the current exception level: EL2 or EL3?
	mrs x0, CurrentEL
   80008:	d5384240 	mrs	x0, currentel
  	lsr x0, x0, #2
   8000c:	d342fc00 	lsr	x0, x0, #2
	cmp x0, #3
   80010:	f1000c1f 	cmp	x0, #0x3
	beq el3
   80014:	54000120 	b.eq	80038 <el3>  // b.none

	// Current EL is EL2 
	// set EL1 to be running in AArch64
	mrs	x0, hcr_el2
   80018:	d53c1100 	mrs	x0, hcr_el2
	orr	x0, x0, #HCR_RW  
   8001c:	b2610000 	orr	x0, x0, #0x80000000
	msr	hcr_el2, x0
   80020:	d51c1100 	msr	hcr_el2, x0

	// prepare to switch to EL1
	mov x0, #SPSR_VALUE
   80024:	d28038a0 	mov	x0, #0x1c5                 	// #453
	msr	spsr_el2, x0
   80028:	d51c4000 	msr	spsr_el2, x0

	adr	x0, el1_entry
   8002c:	10000180 	adr	x0, 8005c <el1_entry>
	msr	elr_el2, x0
   80030:	d51c4020 	msr	elr_el2, x0
	eret	// switch to EL1
   80034:	d69f03e0 	eret

0000000000080038 <el3>:

el3: 		// Current EL: EL3
	// 	With the rpi3 firmware (armstub) or qemu, kernel always starts in EL2; 
	//  We leave EL3 code here for completeness
  	ldr x0, =HCR_VALUE
   80038:	580002c0 	ldr	x0, 80090 <setup_sp+0x24>
  	msr hcr_el2, x0
   8003c:	d51c1100 	msr	hcr_el2, x0

	ldr	x0, =SCR_VALUE
   80040:	580002c0 	ldr	x0, 80098 <setup_sp+0x2c>
	msr	scr_el3, x0
   80044:	d51e1100 	msr	scr_el3, x0

	// prepare to switch to EL1
	ldr	x0, =SPSR_VALUE
   80048:	580002c0 	ldr	x0, 800a0 <setup_sp+0x34>
	msr	spsr_el3, x0
   8004c:	d51e4000 	msr	spsr_el3, x0

	adr	x0, el1_entry		
   80050:	10000060 	adr	x0, 8005c <el1_entry>
	msr	elr_el3, x0	
   80054:	d51e4020 	msr	elr_el3, x0
	eret	// switch to EL1				
   80058:	d69f03e0 	eret

000000000008005c <el1_entry>:
	/* Below: clean up bss region. 
	  bss_begin/end must be 8 bytes aligned, per the linker script */
	// quest: boot
	/* STUDENT_TODO: your code here */
    
    ldr x0, =bss_begin
   8005c:	58000260 	ldr	x0, 800a8 <setup_sp+0x3c>
    ldr x1, =bss_end
   80060:	58000281 	ldr	x1, 800b0 <setup_sp+0x44>
    sub x1, x1, x0
   80064:	cb000021 	sub	x1, x1, x0
	bl 	memzero_aligned
   80068:	9400125b 	bl	849d4 <memzero_aligned>

000000000008006c <setup_sp>:
	
setup_sp: 	
	// quest: boot. set sp to somewhere above PHYS_BASE, far away from kernel image
	/* STUDENT_TODO: your code here */

    ldr x0, =PHYS_BASE
   8006c:	58000260 	ldr	x0, 800b8 <setup_sp+0x4c>
    add x0, x0, #0x400000
   80070:	91500000 	add	x0, x0, #0x400, lsl #12
    mov sp, x0
   80074:	9100001f 	mov	sp, x0

	// NB: we aren't use sp yet -- until we start to execute kernel_main(below)

	// install irq vectors
	ldr x0, =vectors	// load VBAR_EL1 vector table addr
   80078:	58000240 	ldr	x0, 800c0 <setup_sp+0x54>
	msr	vbar_el1, x0	
   8007c:	d518c000 	msr	vbar_el1, x0

	// load the addr of kernel_main
	bl kernel_main  	// kernel.c
   80080:	94000256 	bl	809d8 <kernel_main>
   80084:	00000000 	udf	#0
   80088:	30d00800 	.word	0x30d00800
   8008c:	00000000 	.word	0x00000000
   80090:	80000000 	.word	0x80000000
   80094:	00000000 	.word	0x00000000
   80098:	00000431 	.word	0x00000431
   8009c:	00000000 	.word	0x00000000
   800a0:	000001c5 	.word	0x000001c5
   800a4:	00000000 	.word	0x00000000
   800a8:	00093ef8 	.word	0x00093ef8
   800ac:	00000000 	.word	0x00000000
   800b0:	000950c0 	.word	0x000950c0
	...
   800c0:	00084000 	.word	0x00084000
   800c4:	00000000 	.word	0x00000000

Disassembly of section .text:

0000000000080800 <enable_interrupt_controller>:
#if defined(PLAT_RPI3) || defined(PLAT_RPI3QEMU)
    // On RPi3, Arm Generic timer IRQs are wired to a per-core interrupt controller/register. 
    // For core 0, this is `TIMER_INT_CTRL_0` at 0x40000040; bit 1 is for physical timer at EL1 (CNTP). This register is documented 
    // in the [manual](https://www.raspberrypi.org/documentation/hardware/raspberrypi/bcm2836/QA7_rev3.4.pdf) of BCM2836 
    // (search for "Core timers interrupts"). Note the manual is NOT for the BCM2837 SoC used by Rpi3    
    put32(TIMER_INT_CTRL_0 + 4*coreid, TIMER_INT_CTRL_0_VALUE);
   80800:	531e7402 	lsl	w2, w0, #2
   80804:	d2800801 	mov	x1, #0x40                  	// #64
   80808:	f2a80001 	movk	x1, #0x4000, lsl #16
   8080c:	52800043 	mov	w3, #0x2                   	// #2
   80810:	b822c823 	str	w3, [x1, w2, sxtw]

    if (coreid==0)
   80814:	350000c0 	cbnz	w0, 8082c <enable_interrupt_controller+0x2c>
        put32(ENABLE_IRQS_1, 
   80818:	d2964200 	mov	x0, #0xb210                	// #45584
   8081c:	52804041 	mov	w1, #0x202                 	// #514
   80820:	f2a7e000 	movk	x0, #0x3f00, lsl #16
   80824:	72a60001 	movk	w1, #0x3000, lsl #16
   80828:	b9000001 	str	w1, [x0]
    //     arm_gic_umask(0, i);
    // gic_dump(); // debugging 
#else   
    #error "unimplemented"    
#endif
}
   8082c:	d65f03c0 	ret

0000000000080830 <handle_irq>:

// Q10 quest: pixel donut. call sys_timer_irq_simple() in the right place
// called from hw irq handler (el1_irq, entry.S)
// call from entry.S, el{0|1}_irq
#if defined(PLAT_RPI3) || defined(PLAT_RPI3QEMU)
void handle_irq(void) {
   80830:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
   80834:	910003fd 	mov	x29, sp
   80838:	a90153f3 	stp	x19, x20, [sp, #16]
    // register that holds interrupt status for interrupts `0 - 31`. 
    // Using this register we can check whether the current interrupt was 
    // generated by the timer or by some other device and call device specific 
    // interrupt handler
    // NB: Each Core has its own pending local interrupt register. 
    int coreid = cpuid();
   8083c:	9400105e 	bl	849b4 <cpuid>
    unsigned int irq = get32(INT_SOURCE_0 + 4*coreid), irq0 = irq; 
   80840:	d2800c01 	mov	x1, #0x60                  	// #96
   80844:	531e7400 	lsl	w0, w0, #2
   80848:	f2a80001 	movk	x1, #0x4000, lsl #16
   8084c:	b860c834 	ldr	w20, [x1, w0, sxtw]

    if (irq & GENERIC_TIMER_INTERRUPT) {
   80850:	2a1403f3 	mov	w19, w20
   80854:	370804d4 	tbnz	w20, #1, 808ec <handle_irq+0xbc>
        handle_generic_timer_irq();
        irq &= (~GENERIC_TIMER_INTERRUPT);
    } 
    
    if (irq & GPU_SIDE_INTERRUPT) {
   80858:	36400193 	tbz	w19, #8, 80888 <handle_irq+0x58>
        unsigned int p1 = get32(IRQ_PENDING_1);
   8085c:	d2964080 	mov	x0, #0xb204                	// #45572
   80860:	f90013f5 	str	x21, [sp, #32]
   80864:	f2a7e000 	movk	x0, #0x3f00, lsl #16
   80868:	b9400015 	ldr	w21, [x0]
        if (p1 & IRQ_PENDING_1_AUX) {   // mini uart 
   8086c:	37e804d5 	tbnz	w21, #29, 80904 <handle_irq+0xd4>
            uart_irq(); 
            p1 &= (~IRQ_PENDING_1_AUX); 
        }        
        if (p1 & SYSTEM_TIMER_IRQ_1) {
            /* STUDENT_TODO: your code here */
            p1 &= (~SYSTEM_TIMER_IRQ_1);
   80870:	f27f02bf 	tst	x21, #0x2
   80874:	121e7aa0 	and	w0, w21, #0xfffffffd
        }
        if (p1) {
            E("unknown pending irq in IRQ_PENDING_1 p1 %08x", p1); 
            goto unknown; 
        }          
        irq &= (~GPU_SIDE_INTERRUPT);  // clear all "GPU side" irqs
   80878:	12177a73 	and	w19, w19, #0xfffffeff
            p1 &= (~SYSTEM_TIMER_IRQ_1);
   8087c:	1a951015 	csel	w21, w0, w21, ne  // ne = any
        if (p1) {
   80880:	35000515 	cbnz	w21, 80920 <handle_irq+0xf0>
   80884:	f94013f5 	ldr	x21, [sp, #32]
    } 

    if (!irq) 
   80888:	34000393 	cbz	w19, 808f8 <handle_irq+0xc8>
   8088c:	90000033 	adrp	x19, 84000 <vectors>
        return;  // all irq bits cleared

unknown:
    E("Unknown pending irq: INT_SOURCE_0 %08x IRQ_BASIC_PENDING %08x " 
   80890:	d2964002 	mov	x2, #0xb200                	// #45568
   80894:	d2964081 	mov	x1, #0xb204                	// #45572
   80898:	d2964100 	mov	x0, #0xb208                	// #45576
   8089c:	f2a7e002 	movk	x2, #0x3f00, lsl #16
   808a0:	f2a7e001 	movk	x1, #0x3f00, lsl #16
   808a4:	f2a7e000 	movk	x0, #0x3f00, lsl #16
   808a8:	b9400044 	ldr	w4, [x2]
   808ac:	9127c273 	add	x19, x19, #0x9f0
   808b0:	b9400025 	ldr	w5, [x1]
   808b4:	2a1403e3 	mov	w3, w20
   808b8:	b9400006 	ldr	w6, [x0]
   808bc:	aa1303e1 	mov	x1, x19
   808c0:	52800ce2 	mov	w2, #0x67                  	// #103
   808c4:	90000020 	adrp	x0, 84000 <vectors>
   808c8:	9128e000 	add	x0, x0, #0xa38
   808cc:	94000337 	bl	815a8 <tfp_printf>
        irq0, 
        get32(IRQ_BASIC_PENDING), 
        get32(IRQ_PENDING_1),
        get32(IRQ_PENDING_2)
        );
    BUG(); 
   808d0:	aa1303e1 	mov	x1, x19
   808d4:	90000020 	adrp	x0, 84000 <vectors>
}
   808d8:	a94153f3 	ldp	x19, x20, [sp, #16]
    BUG(); 
   808dc:	912ac000 	add	x0, x0, #0xab0
}
   808e0:	a8c37bfd 	ldp	x29, x30, [sp], #48
    BUG(); 
   808e4:	52800dc2 	mov	w2, #0x6e                  	// #110
   808e8:	140003fe 	b	818e0 <assertion_failed>
        irq &= (~GENERIC_TIMER_INTERRUPT);
   808ec:	121e7a93 	and	w19, w20, #0xfffffffd
        handle_generic_timer_irq();
   808f0:	940005a2 	bl	81f78 <handle_generic_timer_irq>
        irq &= (~GENERIC_TIMER_INTERRUPT);
   808f4:	17ffffd9 	b	80858 <handle_irq+0x28>
}
   808f8:	a94153f3 	ldp	x19, x20, [sp, #16]
   808fc:	a8c37bfd 	ldp	x29, x30, [sp], #48
   80900:	d65f03c0 	ret
            p1 &= (~IRQ_PENDING_1_AUX); 
   80904:	12027ab5 	and	w21, w21, #0xdfffffff
            uart_irq(); 
   80908:	94000c7c 	bl	83af8 <uart_irq>
            p1 &= (~SYSTEM_TIMER_IRQ_1);
   8090c:	121e7aa0 	and	w0, w21, #0xfffffffd
        irq &= (~GPU_SIDE_INTERRUPT);  // clear all "GPU side" irqs
   80910:	12177a73 	and	w19, w19, #0xfffffeff
            p1 &= (~SYSTEM_TIMER_IRQ_1);
   80914:	f27f02bf 	tst	x21, #0x2
   80918:	1a951015 	csel	w21, w0, w21, ne  // ne = any
        if (p1) {
   8091c:	34fffb55 	cbz	w21, 80884 <handle_irq+0x54>
            E("unknown pending irq in IRQ_PENDING_1 p1 %08x", p1); 
   80920:	2a1503e3 	mov	w3, w21
   80924:	90000033 	adrp	x19, 84000 <vectors>
   80928:	90000020 	adrp	x0, 84000 <vectors>
   8092c:	9127c261 	add	x1, x19, #0x9f0
   80930:	9127e000 	add	x0, x0, #0x9f8
   80934:	52800ba2 	mov	w2, #0x5d                  	// #93
   80938:	9400031c 	bl	815a8 <tfp_printf>
            goto unknown; 
   8093c:	f94013f5 	ldr	x21, [sp, #32]
   80940:	17ffffd4 	b	80890 <handle_irq+0x60>
   80944:	d503201f 	nop

0000000000080948 <show_invalid_entry_message>:
#endif

// esr: syndrome, elr: ~faulty pc, far: faulty access addr
void show_invalid_entry_message(int type, unsigned long esr, 
    unsigned long elr, unsigned long far)
{    
   80948:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
    E("%s, cpu%d, esr: 0x%016lx, elr: 0x%016lx, far: 0x%016lx",  
   8094c:	f0000084 	adrp	x4, 93000 <get_el+0xe61c>
   80950:	91372084 	add	x4, x4, #0xdc8
{    
   80954:	910003fd 	mov	x29, sp
   80958:	f9001bf7 	str	x23, [sp, #48]
    E("%s, cpu%d, esr: 0x%016lx, elr: 0x%016lx, far: 0x%016lx",  
   8095c:	f860d897 	ldr	x23, [x4, w0, sxtw #3]
{    
   80960:	a90153f3 	stp	x19, x20, [sp, #16]
   80964:	aa0103f4 	mov	x20, x1
    E("%s, cpu%d, esr: 0x%016lx, elr: 0x%016lx, far: 0x%016lx",  
   80968:	90000033 	adrp	x19, 84000 <vectors>
   8096c:	9127c273 	add	x19, x19, #0x9f0
{    
   80970:	a9025bf5 	stp	x21, x22, [sp, #32]
   80974:	aa0203f5 	mov	x21, x2
   80978:	aa0303f6 	mov	x22, x3
    E("%s, cpu%d, esr: 0x%016lx, elr: 0x%016lx, far: 0x%016lx",  
   8097c:	9400100e 	bl	849b4 <cpuid>
   80980:	2a0003e4 	mov	w4, w0
   80984:	aa1703e3 	mov	x3, x23
   80988:	aa1603e7 	mov	x7, x22
   8098c:	aa1503e6 	mov	x6, x21
   80990:	aa1403e5 	mov	x5, x20
   80994:	aa1303e1 	mov	x1, x19
   80998:	52800ec2 	mov	w2, #0x76                  	// #118
   8099c:	90000020 	adrp	x0, 84000 <vectors>
   809a0:	912ae000 	add	x0, x0, #0xab8
   809a4:	94000301 	bl	815a8 <tfp_printf>
        entry_error_messages[type], cpuid(), esr, elr, far);
    E("online esr decoder: %s0x%016lx", "https://esr.arm64.dev/#", esr);
   809a8:	aa1403e4 	mov	x4, x20
   809ac:	aa1303e1 	mov	x1, x19
}
   809b0:	a94153f3 	ldp	x19, x20, [sp, #16]
    E("online esr decoder: %s0x%016lx", "https://esr.arm64.dev/#", esr);
   809b4:	90000023 	adrp	x3, 84000 <vectors>
}
   809b8:	a9425bf5 	ldp	x21, x22, [sp, #32]
    E("online esr decoder: %s0x%016lx", "https://esr.arm64.dev/#", esr);
   809bc:	912c2063 	add	x3, x3, #0xb08
}
   809c0:	f9401bf7 	ldr	x23, [sp, #48]
    E("online esr decoder: %s0x%016lx", "https://esr.arm64.dev/#", esr);
   809c4:	90000020 	adrp	x0, 84000 <vectors>
}
   809c8:	a8c47bfd 	ldp	x29, x30, [sp], #64
    E("online esr decoder: %s0x%016lx", "https://esr.arm64.dev/#", esr);
   809cc:	912c8000 	add	x0, x0, #0xb20
   809d0:	52800f02 	mov	w2, #0x78                  	// #120
   809d4:	140002f5 	b	815a8 <tfp_printf>

00000000000809d8 <kernel_main>:
void uart_init(void);
void putc(void* p, char);

struct cpu cpus[NCPU]; 

void kernel_main() {
   809d8:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
   809dc:	910003fd 	mov	x29, sp
	// Q4 quest
	/* STUDENT_TODO: your code here */

	uart_init();
   809e0:	94000c58 	bl	83b40 <uart_init>

	// Q4 quest
	/* STUDENT_TODO: your code here */
	
	init_printf(0, putc);
   809e4:	f0000081 	adrp	x1, 93000 <get_el+0xe61c>
   809e8:	d2800000 	mov	x0, #0x0                   	// #0
   809ec:	f9474421 	ldr	x1, [x1, #3720]
   809f0:	940002e8 	bl	81590 <init_printf>

	printf("------ kernel boot ------  core %d\n\r", cpuid());
   809f4:	94000ff0 	bl	849b4 <cpuid>
   809f8:	2a0003e1 	mov	w1, w0
   809fc:	90000020 	adrp	x0, 84000 <vectors>
   80a00:	91324000 	add	x0, x0, #0xc90
   80a04:	940002e9 	bl	815a8 <tfp_printf>
	printf("build time (kernel.c) %s %s\n", __DATE__, __TIME__); // simplicity 
   80a08:	90000022 	adrp	x2, 84000 <vectors>
   80a0c:	90000021 	adrp	x1, 84000 <vectors>
   80a10:	9132e042 	add	x2, x2, #0xcb8
   80a14:	91332021 	add	x1, x1, #0xcc8
   80a18:	90000020 	adrp	x0, 84000 <vectors>
   80a1c:	91336000 	add	x0, x0, #0xcd8
   80a20:	940002e2 	bl	815a8 <tfp_printf>

	sys_timer_init();                   // kernel timer: delay, timekeeping...
   80a24:	940005a9 	bl	820c8 <sys_timer_init>
	enable_interrupt_controller(0);     // coreid
   80a28:	52800000 	mov	w0, #0x0                   	// #0
   80a2c:	97ffff75 	bl	80800 <enable_interrupt_controller>
	// Q5 quest: sys_timer irq
	/* STUDENT_TODO: your code here */

	generic_timer_init();               // periodic ticks alive
   80a30:	9400054c 	bl	81f60 <generic_timer_init>

	if (fb_init() != 0) BUG();          // will show the OS logo
   80a34:	94000803 	bl	82a40 <fb_init>
   80a38:	350000a0 	cbnz	w0, 80a4c <kernel_main+0x74>
	/* to enable it,  irq handler must be modified to call sys_timer_irq_simple() */
	/* STUDENT_TODO: your code here */
	
	// Q5 quest: textual donut. call donut_text()
	/* STUDENT_TODO: your code here */
	donut_text();
   80a3c:	940009df 	bl	831b8 <donut_text>

	while (1)
		asm volatile("wfi");            // what happen here?
   80a40:	d503207f 	wfi
   80a44:	d503207f 	wfi
	while (1)
   80a48:	17fffffe 	b	80a40 <kernel_main+0x68>
	if (fb_init() != 0) BUG();          // will show the OS logo
   80a4c:	90000021 	adrp	x1, 84000 <vectors>
   80a50:	90000020 	adrp	x0, 84000 <vectors>
   80a54:	9133e021 	add	x1, x1, #0xcf8
   80a58:	912ac000 	add	x0, x0, #0xab0
   80a5c:	52800582 	mov	w2, #0x2c                  	// #44
   80a60:	940003a0 	bl	818e0 <assertion_failed>
	donut_text();
   80a64:	940009d5 	bl	831b8 <donut_text>
   80a68:	17fffff6 	b	80a40 <kernel_main+0x68>
   80a6c:	00000000 	udf	#0

0000000000080a70 <ulli2a>:
    unsigned long long int num, struct param *p)
{
    int n = 0;
    unsigned long long int d = 1;
    char *bf = p->bf;
    while (num / d >= p->base)
   80a70:	b9400c26 	ldr	w6, [x1, #12]
    char *bf = p->bf;
   80a74:	f9400829 	ldr	x9, [x1, #16]
    while (num / d >= p->base)
   80a78:	2a0603e4 	mov	w4, w6
   80a7c:	eb26401f 	cmp	x0, w6, uxtw
   80a80:	54000583 	b.cc	80b30 <ulli2a+0xc0>  // b.lo, b.ul, b.last
    unsigned long long int d = 1;
   80a84:	d2800022 	mov	x2, #0x1                   	// #1
        d *= p->base;
   80a88:	9b047c42 	mul	x2, x2, x4
    while (num / d >= p->base)
   80a8c:	9ac20803 	udiv	x3, x0, x2
   80a90:	eb04007f 	cmp	x3, x4
   80a94:	54ffffa2 	b.cs	80a88 <ulli2a+0x18>  // b.hs, b.nlast
    while (d != 0) {
   80a98:	b4000462 	cbz	x2, 80b24 <ulli2a+0xb4>
    int n = 0;
   80a9c:	52800007 	mov	w7, #0x0                   	// #0
        int dgt = num / d;
        num %= d;
        d /= p->base;
        if (n || dgt > 0 || d == 0) {
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80aa0:	528006eb 	mov	w11, #0x37                  	// #55
   80aa4:	52800aea 	mov	w10, #0x57                  	// #87
        if (n || dgt > 0 || d == 0) {
   80aa8:	710000ff 	cmp	w7, #0x0
        num %= d;
   80aac:	9b028060 	msub	x0, x3, x2, x0
        d /= p->base;
   80ab0:	9ac40848 	udiv	x8, x2, x4
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80ab4:	aa0903e5 	mov	x5, x9
        if (n || dgt > 0 || d == 0) {
   80ab8:	7a400860 	ccmp	w3, #0x0, #0x0, eq  // eq = none
   80abc:	540000ec 	b.gt	80ad8 <ulli2a+0x68>
   80ac0:	eb02009f 	cmp	x4, x2
   80ac4:	540002c9 	b.ls	80b1c <ulli2a+0xac>  // b.plast
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80ac8:	1100c063 	add	w3, w3, #0x30
   80acc:	380014a3 	strb	w3, [x5], #1
            ++n;
        }
    }
    *bf = 0;
   80ad0:	390000bf 	strb	wzr, [x5]
}
   80ad4:	d65f03c0 	ret
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80ad8:	7100247f 	cmp	w3, #0x9
   80adc:	52800606 	mov	w6, #0x30                  	// #48
   80ae0:	5400008d 	b.le	80af0 <ulli2a+0x80>
   80ae4:	39400026 	ldrb	w6, [x1]
   80ae8:	f27e00df 	tst	x6, #0x4
   80aec:	1a8a1166 	csel	w6, w11, w10, ne  // ne = any
   80af0:	0b0300c3 	add	w3, w6, w3
   80af4:	380014a3 	strb	w3, [x5], #1
            ++n;
   80af8:	110004e7 	add	w7, w7, #0x1
    while (d != 0) {
   80afc:	eb02009f 	cmp	x4, x2
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80b00:	aa0503e9 	mov	x9, x5
    while (d != 0) {
   80b04:	54fffe68 	b.hi	80ad0 <ulli2a+0x60>  // b.pmore
   80b08:	b9400c26 	ldr	w6, [x1, #12]
   80b0c:	9ac80803 	udiv	x3, x0, x8
   80b10:	2a0603e4 	mov	w4, w6
    int n = 0;
   80b14:	aa0803e2 	mov	x2, x8
   80b18:	17ffffe4 	b	80aa8 <ulli2a+0x38>
   80b1c:	52800007 	mov	w7, #0x0                   	// #0
   80b20:	17fffffb 	b	80b0c <ulli2a+0x9c>
    char *bf = p->bf;
   80b24:	aa0903e5 	mov	x5, x9
    *bf = 0;
   80b28:	390000bf 	strb	wzr, [x5]
}
   80b2c:	d65f03c0 	ret
   80b30:	aa0003e3 	mov	x3, x0
    unsigned long long int d = 1;
   80b34:	d2800022 	mov	x2, #0x1                   	// #1
   80b38:	17ffffd9 	b	80a9c <ulli2a+0x2c>
   80b3c:	d503201f 	nop

0000000000080b40 <uli2a>:
static void uli2a(unsigned long int num, struct param *p)
{
    int n = 0;
    unsigned long int d = 1;
    char *bf = p->bf;
    while (num / d >= p->base)
   80b40:	b9400c26 	ldr	w6, [x1, #12]
    char *bf = p->bf;
   80b44:	f9400829 	ldr	x9, [x1, #16]
    while (num / d >= p->base)
   80b48:	2a0603e4 	mov	w4, w6
   80b4c:	eb26401f 	cmp	x0, w6, uxtw
   80b50:	54000583 	b.cc	80c00 <uli2a+0xc0>  // b.lo, b.ul, b.last
    unsigned long int d = 1;
   80b54:	d2800022 	mov	x2, #0x1                   	// #1
        d *= p->base;
   80b58:	9b047c42 	mul	x2, x2, x4
    while (num / d >= p->base)
   80b5c:	9ac20803 	udiv	x3, x0, x2
   80b60:	eb04007f 	cmp	x3, x4
   80b64:	54ffffa2 	b.cs	80b58 <uli2a+0x18>  // b.hs, b.nlast
    while (d != 0) {
   80b68:	b4000462 	cbz	x2, 80bf4 <uli2a+0xb4>
    int n = 0;
   80b6c:	52800007 	mov	w7, #0x0                   	// #0
        int dgt = num / d;
        num %= d;
        d /= p->base;
        if (n || dgt > 0 || d == 0) {
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80b70:	528006eb 	mov	w11, #0x37                  	// #55
   80b74:	52800aea 	mov	w10, #0x57                  	// #87
        if (n || dgt > 0 || d == 0) {
   80b78:	710000ff 	cmp	w7, #0x0
        num %= d;
   80b7c:	9b028060 	msub	x0, x3, x2, x0
        d /= p->base;
   80b80:	9ac40848 	udiv	x8, x2, x4
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80b84:	aa0903e5 	mov	x5, x9
        if (n || dgt > 0 || d == 0) {
   80b88:	7a400860 	ccmp	w3, #0x0, #0x0, eq  // eq = none
   80b8c:	540000ec 	b.gt	80ba8 <uli2a+0x68>
   80b90:	eb02009f 	cmp	x4, x2
   80b94:	540002c9 	b.ls	80bec <uli2a+0xac>  // b.plast
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80b98:	1100c063 	add	w3, w3, #0x30
   80b9c:	380014a3 	strb	w3, [x5], #1
            ++n;
        }
    }
    *bf = 0;
   80ba0:	390000bf 	strb	wzr, [x5]
}
   80ba4:	d65f03c0 	ret
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80ba8:	7100247f 	cmp	w3, #0x9
   80bac:	52800606 	mov	w6, #0x30                  	// #48
   80bb0:	5400008d 	b.le	80bc0 <uli2a+0x80>
   80bb4:	39400026 	ldrb	w6, [x1]
   80bb8:	f27e00df 	tst	x6, #0x4
   80bbc:	1a8a1166 	csel	w6, w11, w10, ne  // ne = any
   80bc0:	0b0300c3 	add	w3, w6, w3
   80bc4:	380014a3 	strb	w3, [x5], #1
            ++n;
   80bc8:	110004e7 	add	w7, w7, #0x1
    while (d != 0) {
   80bcc:	eb02009f 	cmp	x4, x2
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80bd0:	aa0503e9 	mov	x9, x5
    while (d != 0) {
   80bd4:	54fffe68 	b.hi	80ba0 <uli2a+0x60>  // b.pmore
   80bd8:	b9400c26 	ldr	w6, [x1, #12]
   80bdc:	9ac80803 	udiv	x3, x0, x8
   80be0:	2a0603e4 	mov	w4, w6
    int n = 0;
   80be4:	aa0803e2 	mov	x2, x8
   80be8:	17ffffe4 	b	80b78 <uli2a+0x38>
   80bec:	52800007 	mov	w7, #0x0                   	// #0
   80bf0:	17fffffb 	b	80bdc <uli2a+0x9c>
    char *bf = p->bf;
   80bf4:	aa0903e5 	mov	x5, x9
    *bf = 0;
   80bf8:	390000bf 	strb	wzr, [x5]
}
   80bfc:	d65f03c0 	ret
   80c00:	aa0003e3 	mov	x3, x0
    unsigned long int d = 1;
   80c04:	d2800022 	mov	x2, #0x1                   	// #1
   80c08:	17ffffd9 	b	80b6c <uli2a+0x2c>
   80c0c:	d503201f 	nop

0000000000080c10 <ui2a>:
static void ui2a(unsigned int num, struct param *p)
{
    int n = 0;
    unsigned int d = 1;
    char *bf = p->bf;
    while (num / d >= p->base)
   80c10:	b9400c24 	ldr	w4, [x1, #12]
    char *bf = p->bf;
   80c14:	f9400826 	ldr	x6, [x1, #16]
    while (num / d >= p->base)
   80c18:	6b04001f 	cmp	w0, w4
   80c1c:	54000583 	b.cc	80ccc <ui2a+0xbc>  // b.lo, b.ul, b.last
    unsigned int d = 1;
   80c20:	52800022 	mov	w2, #0x1                   	// #1
   80c24:	d503201f 	nop
        d *= p->base;
   80c28:	1b047c42 	mul	w2, w2, w4
    while (num / d >= p->base)
   80c2c:	1ac20803 	udiv	w3, w0, w2
   80c30:	6b04007f 	cmp	w3, w4
   80c34:	54ffffa2 	b.cs	80c28 <ui2a+0x18>  // b.hs, b.nlast
    while (d != 0) {
   80c38:	34000442 	cbz	w2, 80cc0 <ui2a+0xb0>
    int n = 0;
   80c3c:	52800007 	mov	w7, #0x0                   	// #0
        int dgt = num / d;
        num %= d;
        d /= p->base;
        if (n || dgt > 0 || d == 0) {
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80c40:	528006ea 	mov	w10, #0x37                  	// #55
   80c44:	52800ae9 	mov	w9, #0x57                  	// #87
        if (n || dgt > 0 || d == 0) {
   80c48:	710000ff 	cmp	w7, #0x0
        num %= d;
   80c4c:	1b028060 	msub	w0, w3, w2, w0
        d /= p->base;
   80c50:	1ac40848 	udiv	w8, w2, w4
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80c54:	aa0603e5 	mov	x5, x6
        if (n || dgt > 0 || d == 0) {
   80c58:	7a400860 	ccmp	w3, #0x0, #0x0, eq  // eq = none
   80c5c:	540000ec 	b.gt	80c78 <ui2a+0x68>
   80c60:	6b04005f 	cmp	w2, w4
   80c64:	540002a2 	b.cs	80cb8 <ui2a+0xa8>  // b.hs, b.nlast
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80c68:	1100c063 	add	w3, w3, #0x30
   80c6c:	380014a3 	strb	w3, [x5], #1
            ++n;
        }
    }
    *bf = 0;
   80c70:	390000bf 	strb	wzr, [x5]
}
   80c74:	d65f03c0 	ret
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80c78:	7100247f 	cmp	w3, #0x9
   80c7c:	52800606 	mov	w6, #0x30                  	// #48
   80c80:	5400008d 	b.le	80c90 <ui2a+0x80>
   80c84:	39400026 	ldrb	w6, [x1]
   80c88:	f27e00df 	tst	x6, #0x4
   80c8c:	1a891146 	csel	w6, w10, w9, ne  // ne = any
   80c90:	0b0300c3 	add	w3, w6, w3
   80c94:	380014a3 	strb	w3, [x5], #1
            ++n;
   80c98:	110004e7 	add	w7, w7, #0x1
    while (d != 0) {
   80c9c:	6b04005f 	cmp	w2, w4
            *bf++ = dgt + (dgt < 10 ? '0' : (p->uc ? 'A' : 'a') - 10);
   80ca0:	aa0503e6 	mov	x6, x5
    while (d != 0) {
   80ca4:	54fffe63 	b.cc	80c70 <ui2a+0x60>  // b.lo, b.ul, b.last
   80ca8:	b9400c24 	ldr	w4, [x1, #12]
   80cac:	1ac80803 	udiv	w3, w0, w8
    int n = 0;
   80cb0:	2a0803e2 	mov	w2, w8
   80cb4:	17ffffe5 	b	80c48 <ui2a+0x38>
   80cb8:	52800007 	mov	w7, #0x0                   	// #0
   80cbc:	17fffffc 	b	80cac <ui2a+0x9c>
    char *bf = p->bf;
   80cc0:	aa0603e5 	mov	x5, x6
    *bf = 0;
   80cc4:	390000bf 	strb	wzr, [x5]
}
   80cc8:	d65f03c0 	ret
   80ccc:	2a0003e3 	mov	w3, w0
    unsigned int d = 1;
   80cd0:	52800022 	mov	w2, #0x1                   	// #1
   80cd4:	17ffffda 	b	80c3c <ui2a+0x2c>

0000000000080cd8 <putchw>:
    *nump = num;
    return ch;
}

static void putchw(void *putp, putcf putf, struct param *p)
{
   80cd8:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
   80cdc:	910003fd 	mov	x29, sp
   80ce0:	a90153f3 	stp	x19, x20, [sp, #16]
   80ce4:	aa0003f4 	mov	x20, x0
    char ch;
    int n = p->width;
   80ce8:	b9400453 	ldr	w19, [x2, #4]
    char *bf = p->bf;

    /* Number of filling characters */
    while (*bf++ && n > 0)
   80cec:	f9400840 	ldr	x0, [x2, #16]
{
   80cf0:	a9025bf5 	stp	x21, x22, [sp, #32]
   80cf4:	aa0103f5 	mov	x21, x1
   80cf8:	f9001bf7 	str	x23, [sp, #48]
   80cfc:	aa0203f7 	mov	x23, x2
    while (*bf++ && n > 0)
   80d00:	38401401 	ldrb	w1, [x0], #1
   80d04:	7100003f 	cmp	w1, #0x0
   80d08:	7a401a64 	ccmp	w19, #0x0, #0x4, ne  // ne = any
   80d0c:	540000cd 	b.le	80d24 <putchw+0x4c>
   80d10:	38401401 	ldrb	w1, [x0], #1
        n--;
   80d14:	51000673 	sub	w19, w19, #0x1
    while (*bf++ && n > 0)
   80d18:	7100003f 	cmp	w1, #0x0
   80d1c:	7a401a64 	ccmp	w19, #0x0, #0x4, ne  // ne = any
   80d20:	54ffff8c 	b.gt	80d10 <putchw+0x38>
    if (p->sign)
   80d24:	394022e1 	ldrb	w1, [x23, #8]
        n--;
    if (p->alt && p->base == 16)
   80d28:	394002e0 	ldrb	w0, [x23]
        n--;
   80d2c:	7100003f 	cmp	w1, #0x0
   80d30:	1a9f07e2 	cset	w2, ne  // ne = any
   80d34:	4b020273 	sub	w19, w19, w2
    if (p->alt && p->base == 16)
   80d38:	360800e0 	tbz	w0, #1, 80d54 <putchw+0x7c>
   80d3c:	b9400ee2 	ldr	w2, [x23, #12]
   80d40:	7100405f 	cmp	w2, #0x10
   80d44:	54000a80 	b.eq	80e94 <putchw+0x1bc>  // b.none
        n -= 2;
    else if (p->alt && p->base == 8)
        n--;
   80d48:	7100205f 	cmp	w2, #0x8
   80d4c:	1a9f17e2 	cset	w2, eq  // eq = none
   80d50:	4b020273 	sub	w19, w19, w2

    /* Fill with space to align to the right, before alternate or sign */
    if (!p->lz && !p->align_left) {
   80d54:	52800122 	mov	w2, #0x9                   	// #9
   80d58:	6a02001f 	tst	w0, w2
   80d5c:	54000181 	b.ne	80d8c <putchw+0xb4>  // b.any
        while (n-- > 0)
   80d60:	7100027f 	cmp	w19, #0x0
   80d64:	51000673 	sub	w19, w19, #0x1
   80d68:	5400012d 	b.le	80d8c <putchw+0xb4>
   80d6c:	d503201f 	nop
   80d70:	51000673 	sub	w19, w19, #0x1
            putf(putp, ' ');
   80d74:	aa1403e0 	mov	x0, x20
   80d78:	52800401 	mov	w1, #0x20                  	// #32
   80d7c:	d63f02a0 	blr	x21
        while (n-- > 0)
   80d80:	3100067f 	cmn	w19, #0x1
   80d84:	54ffff61 	b.ne	80d70 <putchw+0x98>  // b.any
   80d88:	394022e1 	ldrb	w1, [x23, #8]
    }

    /* print sign */
    if (p->sign)
   80d8c:	34000061 	cbz	w1, 80d98 <putchw+0xc0>
        putf(putp, p->sign);
   80d90:	aa1403e0 	mov	x0, x20
   80d94:	d63f02a0 	blr	x21

    /* Alternate */
    if (p->alt && p->base == 16) {
   80d98:	394002e0 	ldrb	w0, [x23]
   80d9c:	360800c0 	tbz	w0, #1, 80db4 <putchw+0xdc>
   80da0:	b9400ee1 	ldr	w1, [x23, #12]
   80da4:	7100403f 	cmp	w1, #0x10
   80da8:	540005e0 	b.eq	80e64 <putchw+0x18c>  // b.none
        putf(putp, '0');
        putf(putp, (p->uc ? 'X' : 'x'));
    } else if (p->alt && p->base == 8) {
   80dac:	7100203f 	cmp	w1, #0x8
   80db0:	54000760 	b.eq	80e9c <putchw+0x1c4>  // b.none
        putf(putp, '0');
    }

    /* Fill with zeros, after alternate or sign */
    if (p->lz) {
   80db4:	36000160 	tbz	w0, #0, 80de0 <putchw+0x108>
        while (n-- > 0)
   80db8:	7100027f 	cmp	w19, #0x0
   80dbc:	51000673 	sub	w19, w19, #0x1
   80dc0:	5400010d 	b.le	80de0 <putchw+0x108>
   80dc4:	d503201f 	nop
   80dc8:	51000673 	sub	w19, w19, #0x1
            putf(putp, '0');
   80dcc:	aa1403e0 	mov	x0, x20
   80dd0:	52800601 	mov	w1, #0x30                  	// #48
   80dd4:	d63f02a0 	blr	x21
        while (n-- > 0)
   80dd8:	3100067f 	cmn	w19, #0x1
   80ddc:	54ffff61 	b.ne	80dc8 <putchw+0xf0>  // b.any
    }

    /* Put actual buffer */
    bf = p->bf;
    while ((ch = *bf++))
   80de0:	f9400af6 	ldr	x22, [x23, #16]
   80de4:	384016c1 	ldrb	w1, [x22], #1
   80de8:	340000c1 	cbz	w1, 80e00 <putchw+0x128>
   80dec:	d503201f 	nop
        putf(putp, ch);
   80df0:	aa1403e0 	mov	x0, x20
   80df4:	d63f02a0 	blr	x21
    while ((ch = *bf++))
   80df8:	384016c1 	ldrb	w1, [x22], #1
   80dfc:	35ffffa1 	cbnz	w1, 80df0 <putchw+0x118>

    /* Fill with space to align to the left, after string */
    if (!p->lz && p->align_left) {
   80e00:	394002e1 	ldrb	w1, [x23]
   80e04:	52800120 	mov	w0, #0x9                   	// #9
   80e08:	0a010000 	and	w0, w0, w1
   80e0c:	7100201f 	cmp	w0, #0x8
   80e10:	540000c0 	b.eq	80e28 <putchw+0x150>  // b.none
        while (n-- > 0)
            putf(putp, ' ');
    }
}
   80e14:	a94153f3 	ldp	x19, x20, [sp, #16]
   80e18:	a9425bf5 	ldp	x21, x22, [sp, #32]
   80e1c:	f9401bf7 	ldr	x23, [sp, #48]
   80e20:	a8c47bfd 	ldp	x29, x30, [sp], #64
   80e24:	d65f03c0 	ret
        while (n-- > 0)
   80e28:	7100027f 	cmp	w19, #0x0
   80e2c:	51000673 	sub	w19, w19, #0x1
   80e30:	54ffff2d 	b.le	80e14 <putchw+0x13c>
   80e34:	d503201f 	nop
   80e38:	51000673 	sub	w19, w19, #0x1
            putf(putp, ' ');
   80e3c:	aa1403e0 	mov	x0, x20
   80e40:	52800401 	mov	w1, #0x20                  	// #32
   80e44:	d63f02a0 	blr	x21
        while (n-- > 0)
   80e48:	3100067f 	cmn	w19, #0x1
   80e4c:	54ffff61 	b.ne	80e38 <putchw+0x160>  // b.any
}
   80e50:	a94153f3 	ldp	x19, x20, [sp, #16]
   80e54:	a9425bf5 	ldp	x21, x22, [sp, #32]
   80e58:	f9401bf7 	ldr	x23, [sp, #48]
   80e5c:	a8c47bfd 	ldp	x29, x30, [sp], #64
   80e60:	d65f03c0 	ret
        putf(putp, '0');
   80e64:	aa1403e0 	mov	x0, x20
   80e68:	52800601 	mov	w1, #0x30                  	// #48
   80e6c:	d63f02a0 	blr	x21
        putf(putp, (p->uc ? 'X' : 'x'));
   80e70:	394002e3 	ldrb	w3, [x23]
   80e74:	52800b02 	mov	w2, #0x58                  	// #88
   80e78:	aa1403e0 	mov	x0, x20
   80e7c:	52800f01 	mov	w1, #0x78                  	// #120
   80e80:	f27e007f 	tst	x3, #0x4
   80e84:	1a811041 	csel	w1, w2, w1, ne  // ne = any
   80e88:	d63f02a0 	blr	x21
   80e8c:	394002e0 	ldrb	w0, [x23]
   80e90:	17ffffc9 	b	80db4 <putchw+0xdc>
        n -= 2;
   80e94:	51000a73 	sub	w19, w19, #0x2
   80e98:	17ffffaf 	b	80d54 <putchw+0x7c>
        putf(putp, '0');
   80e9c:	aa1403e0 	mov	x0, x20
   80ea0:	52800601 	mov	w1, #0x30                  	// #48
   80ea4:	d63f02a0 	blr	x21
   80ea8:	394002e0 	ldrb	w0, [x23]
   80eac:	17ffffc2 	b	80db4 <putchw+0xdc>

0000000000080eb0 <_vsnprintf_putcf>:
};

static void _vsnprintf_putcf(void *p, char c)
{
  struct _vsnprintf_putcf_data *data = (struct _vsnprintf_putcf_data*)p;
  if (data->num_chars < data->dest_capacity)
   80eb0:	f9400003 	ldr	x3, [x0]
{
   80eb4:	12001c21 	and	w1, w1, #0xff
  if (data->num_chars < data->dest_capacity)
   80eb8:	f9400802 	ldr	x2, [x0, #16]
   80ebc:	eb03005f 	cmp	x2, x3
   80ec0:	54000082 	b.cs	80ed0 <_vsnprintf_putcf+0x20>  // b.hs, b.nlast
    data->dest[data->num_chars] = c;
   80ec4:	f9400403 	ldr	x3, [x0, #8]
   80ec8:	38226861 	strb	w1, [x3, x2]
   80ecc:	f9400802 	ldr	x2, [x0, #16]
  data->num_chars ++;
   80ed0:	91000442 	add	x2, x2, #0x1
   80ed4:	f9000802 	str	x2, [x0, #16]
}
   80ed8:	d65f03c0 	ret
   80edc:	d503201f 	nop

0000000000080ee0 <_vsprintf_putcf>:
};

static void _vsprintf_putcf(void *p, char c)
{
  struct _vsprintf_putcf_data *data = (struct _vsprintf_putcf_data*)p;
  data->dest[data->num_chars++] = c;
   80ee0:	a9400803 	ldp	x3, x2, [x0]
   80ee4:	91000444 	add	x4, x2, #0x1
   80ee8:	f9000404 	str	x4, [x0, #8]
   80eec:	38226861 	strb	w1, [x3, x2]
}
   80ef0:	d65f03c0 	ret
   80ef4:	d503201f 	nop

0000000000080ef8 <tfp_format>:
{
   80ef8:	a9b67bfd 	stp	x29, x30, [sp, #-160]!
   80efc:	910003fd 	mov	x29, sp
   80f00:	a90573fb 	stp	x27, x28, [sp, #80]
    while ((ch = *(fmt++))) {
   80f04:	aa0203fb 	mov	x27, x2
{
   80f08:	a90153f3 	stp	x19, x20, [sp, #16]
   80f0c:	aa0103f4 	mov	x20, x1
   80f10:	aa0003f3 	mov	x19, x0
   80f14:	a9025bf5 	stp	x21, x22, [sp, #32]
   80f18:	b9401876 	ldr	w22, [x3, #24]
   80f1c:	a9046bf9 	stp	x25, x26, [sp, #64]
    p.bf = bf;
   80f20:	9101c3f9 	add	x25, sp, #0x70
    while ((ch = *(fmt++))) {
   80f24:	38401761 	ldrb	w1, [x27], #1
   80f28:	a9400075 	ldp	x21, x0, [x3]
   80f2c:	f90037e0 	str	x0, [sp, #104]
    p.bf = bf;
   80f30:	f9004ff9 	str	x25, [sp, #152]
    while ((ch = *(fmt++))) {
   80f34:	34000a81 	cbz	w1, 81084 <tfp_format+0x18c>
                p.base = 10;
   80f38:	5280015a 	mov	w26, #0xa                   	// #10
   80f3c:	a90363f7 	stp	x23, x24, [sp, #48]
    ui2a(num, p);
   80f40:	910223f7 	add	x23, sp, #0x88
            p.lz = 0;
   80f44:	12800178 	mov	w24, #0xfffffff4            	// #-12
   80f48:	14000008 	b	80f68 <tfp_format+0x70>
            putf(putp, ch);
   80f4c:	aa1303e0 	mov	x0, x19
   80f50:	d63f0280 	blr	x20
   80f54:	aa1c03e0 	mov	x0, x28
   80f58:	aa1b03fc 	mov	x28, x27
   80f5c:	aa0003fb 	mov	x27, x0
    while ((ch = *(fmt++))) {
   80f60:	39400381 	ldrb	w1, [x28]
   80f64:	340008e1 	cbz	w1, 81080 <tfp_format+0x188>
        if (ch != '%') {
   80f68:	7100943f 	cmp	w1, #0x25
   80f6c:	9100077c 	add	x28, x27, #0x1
   80f70:	54fffee1 	b.ne	80f4c <tfp_format+0x54>  // b.any
            p.lz = 0;
   80f74:	394223e0 	ldrb	w0, [sp, #136]
            while ((ch = *(fmt++))) {
   80f78:	39400363 	ldrb	w3, [x27]
            p.lz = 0;
   80f7c:	0a180000 	and	w0, w0, w24
   80f80:	390223e0 	strb	w0, [sp, #136]
            p.width = 0;
   80f84:	b9008fff 	str	wzr, [sp, #140]
            p.sign = 0;
   80f88:	390243ff 	strb	wzr, [sp, #144]
            while ((ch = *(fmt++))) {
   80f8c:	340007a3 	cbz	w3, 81080 <tfp_format+0x188>
   80f90:	52800002 	mov	w2, #0x0                   	// #0
   80f94:	52800001 	mov	w1, #0x0                   	// #0
   80f98:	52800000 	mov	w0, #0x0                   	// #0
                switch (ch) {
   80f9c:	7100b47f 	cmp	w3, #0x2d
   80fa0:	54000f00 	b.eq	81180 <tfp_format+0x288>  // b.none
   80fa4:	7100c07f 	cmp	w3, #0x30
   80fa8:	540009e0 	b.eq	810e4 <tfp_format+0x1ec>  // b.none
   80fac:	71008c7f 	cmp	w3, #0x23
   80fb0:	54000760 	b.eq	8109c <tfp_format+0x1a4>  // b.none
   80fb4:	34000080 	cbz	w0, 80fc4 <tfp_format+0xcc>
   80fb8:	394223e0 	ldrb	w0, [sp, #136]
   80fbc:	321d0000 	orr	w0, w0, #0x8
   80fc0:	390223e0 	strb	w0, [sp, #136]
   80fc4:	34000081 	cbz	w1, 80fd4 <tfp_format+0xdc>
   80fc8:	394223e0 	ldrb	w0, [sp, #136]
   80fcc:	32000000 	orr	w0, w0, #0x1
   80fd0:	390223e0 	strb	w0, [sp, #136]
   80fd4:	34000082 	cbz	w2, 80fe4 <tfp_format+0xec>
   80fd8:	394223e0 	ldrb	w0, [sp, #136]
   80fdc:	321f0000 	orr	w0, w0, #0x2
   80fe0:	390223e0 	strb	w0, [sp, #136]
            if (ch >= '0' && ch <= '9') {
   80fe4:	5100c066 	sub	w6, w3, #0x30
   80fe8:	12001cc0 	and	w0, w6, #0xff
   80fec:	7100241f 	cmp	w0, #0x9
   80ff0:	54001209 	b.ls	81230 <tfp_format+0x338>  // b.plast
            if (ch == '.') {
   80ff4:	7100b87f 	cmp	w3, #0x2e
   80ff8:	54001540 	b.eq	812a0 <tfp_format+0x3a8>  // b.none
            if (ch == 'z') {
   80ffc:	7101e87f 	cmp	w3, #0x7a
   81000:	540010e0 	b.eq	8121c <tfp_format+0x324>  // b.none
            if (ch == 'l') {
   81004:	7101b07f 	cmp	w3, #0x6c
   81008:	54001600 	b.eq	812c8 <tfp_format+0x3d0>  // b.none
            switch (ch) {
   8100c:	7101a47f 	cmp	w3, #0x69
   81010:	54002640 	b.eq	814d8 <tfp_format+0x5e0>  // b.none
            char lng = 0;  /* 1 for long, 2 for long long */
   81014:	52800000 	mov	w0, #0x0                   	// #0
            switch (ch) {
   81018:	7101a47f 	cmp	w3, #0x69
   8101c:	54000b69 	b.ls	81188 <tfp_format+0x290>  // b.plast
   81020:	7101cc7f 	cmp	w3, #0x73
   81024:	540017e0 	b.eq	81320 <tfp_format+0x428>  // b.none
   81028:	54000889 	b.ls	81138 <tfp_format+0x240>  // b.plast
   8102c:	7101d47f 	cmp	w3, #0x75
   81030:	540005e1 	b.ne	810ec <tfp_format+0x1f4>  // b.any
                p.base = 10;
   81034:	b90097fa 	str	w26, [sp, #148]
                if (2 == lng)
   81038:	7100081f 	cmp	w0, #0x2
   8103c:	540006e0 	b.eq	81118 <tfp_format+0x220>  // b.none
                  if (1 == lng)
   81040:	7100041f 	cmp	w0, #0x1
   81044:	540008e0 	b.eq	81160 <tfp_format+0x268>  // b.none
                    ui2a(va_arg(va, unsigned int), &p);
   81048:	37f81c36 	tbnz	w22, #31, 813cc <tfp_format+0x4d4>
   8104c:	91002ea1 	add	x1, x21, #0xb
   81050:	aa1503e0 	mov	x0, x21
   81054:	927df035 	and	x21, x1, #0xfffffffffffffff8
   81058:	b9400000 	ldr	w0, [x0]
   8105c:	aa1703e1 	mov	x1, x23
   81060:	97fffeec 	bl	80c10 <ui2a>
                putchw(putp, putf, &p);
   81064:	aa1403e1 	mov	x1, x20
   81068:	aa1703e2 	mov	x2, x23
   8106c:	aa1303e0 	mov	x0, x19
   81070:	97ffff1a 	bl	80cd8 <putchw>
    while ((ch = *(fmt++))) {
   81074:	39400381 	ldrb	w1, [x28]
   81078:	9100079b 	add	x27, x28, #0x1
   8107c:	35fff761 	cbnz	w1, 80f68 <tfp_format+0x70>
   81080:	a94363f7 	ldp	x23, x24, [sp, #48]
}
   81084:	a94153f3 	ldp	x19, x20, [sp, #16]
   81088:	a9425bf5 	ldp	x21, x22, [sp, #32]
   8108c:	a9446bf9 	ldp	x25, x26, [sp, #64]
   81090:	a94573fb 	ldp	x27, x28, [sp, #80]
   81094:	a8ca7bfd 	ldp	x29, x30, [sp], #160
   81098:	d65f03c0 	ret
                    p.alt = 1;
   8109c:	52800022 	mov	w2, #0x1                   	// #1
            while ((ch = *(fmt++))) {
   810a0:	38401783 	ldrb	w3, [x28], #1
   810a4:	35fff7c3 	cbnz	w3, 80f9c <tfp_format+0xa4>
   810a8:	34000080 	cbz	w0, 810b8 <tfp_format+0x1c0>
   810ac:	394223e0 	ldrb	w0, [sp, #136]
   810b0:	321d0000 	orr	w0, w0, #0x8
   810b4:	390223e0 	strb	w0, [sp, #136]
   810b8:	34fffe41 	cbz	w1, 81080 <tfp_format+0x188>
   810bc:	394223e0 	ldrb	w0, [sp, #136]
}
   810c0:	a94153f3 	ldp	x19, x20, [sp, #16]
   810c4:	32000000 	orr	w0, w0, #0x1
   810c8:	390223e0 	strb	w0, [sp, #136]
   810cc:	a9425bf5 	ldp	x21, x22, [sp, #32]
   810d0:	a94363f7 	ldp	x23, x24, [sp, #48]
   810d4:	a9446bf9 	ldp	x25, x26, [sp, #64]
   810d8:	a94573fb 	ldp	x27, x28, [sp, #80]
   810dc:	a8ca7bfd 	ldp	x29, x30, [sp], #160
   810e0:	d65f03c0 	ret
                    p.lz = 1;
   810e4:	52800021 	mov	w1, #0x1                   	// #1
   810e8:	17ffffee 	b	810a0 <tfp_format+0x1a8>
            switch (ch) {
   810ec:	7101e07f 	cmp	w3, #0x78
   810f0:	54000f61 	b.ne	812dc <tfp_format+0x3e4>  // b.any
                p.uc = (ch == 'X')?1:0;
   810f4:	7101607f 	cmp	w3, #0x58
   810f8:	394223e1 	ldrb	w1, [sp, #136]
   810fc:	1a9f17e2 	cset	w2, eq  // eq = none
                p.base = 16;
   81100:	52800203 	mov	w3, #0x10                  	// #16
   81104:	b90097e3 	str	w3, [sp, #148]
                if (2 == lng)
   81108:	7100081f 	cmp	w0, #0x2
                p.uc = (ch == 'X')?1:0;
   8110c:	331e0041 	bfi	w1, w2, #2, #1
   81110:	390223e1 	strb	w1, [sp, #136]
                if (2 == lng)
   81114:	54fff961 	b.ne	81040 <tfp_format+0x148>  // b.any
                    ulli2a(va_arg(va, unsigned long long int), &p);
   81118:	37f81836 	tbnz	w22, #31, 8141c <tfp_format+0x524>
   8111c:	91003ea1 	add	x1, x21, #0xf
   81120:	aa1503e0 	mov	x0, x21
   81124:	927df035 	and	x21, x1, #0xfffffffffffffff8
   81128:	f9400000 	ldr	x0, [x0]
   8112c:	aa1703e1 	mov	x1, x23
   81130:	97fffe50 	bl	80a70 <ulli2a>
   81134:	17ffffcc 	b	81064 <tfp_format+0x16c>
            switch (ch) {
   81138:	7101bc7f 	cmp	w3, #0x6f
   8113c:	54000d40 	b.eq	812e4 <tfp_format+0x3ec>  // b.none
   81140:	7101c07f 	cmp	w3, #0x70
   81144:	54000cc1 	b.ne	812dc <tfp_format+0x3e4>  // b.any
                p.alt = 1;
   81148:	394223e0 	ldrb	w0, [sp, #136]
                p.base = 16;
   8114c:	52800201 	mov	w1, #0x10                  	// #16
   81150:	b90097e1 	str	w1, [sp, #148]
                p.alt = 1;
   81154:	121d7400 	and	w0, w0, #0xfffffff9
   81158:	321f0000 	orr	w0, w0, #0x2
   8115c:	390223e0 	strb	w0, [sp, #136]
                    uli2a(va_arg(va, unsigned long int), &p);
   81160:	37f81476 	tbnz	w22, #31, 813ec <tfp_format+0x4f4>
   81164:	91003ea1 	add	x1, x21, #0xf
   81168:	aa1503e0 	mov	x0, x21
   8116c:	927df035 	and	x21, x1, #0xfffffffffffffff8
   81170:	f9400000 	ldr	x0, [x0]
   81174:	aa1703e1 	mov	x1, x23
   81178:	97fffe72 	bl	80b40 <uli2a>
   8117c:	17ffffba 	b	81064 <tfp_format+0x16c>
                switch (ch) {
   81180:	52800020 	mov	w0, #0x1                   	// #1
   81184:	17ffffc7 	b	810a0 <tfp_format+0x1a8>
            switch (ch) {
   81188:	7101607f 	cmp	w3, #0x58
   8118c:	54fffb40 	b.eq	810f4 <tfp_format+0x1fc>  // b.none
   81190:	54000128 	b.hi	811b4 <tfp_format+0x2bc>  // b.pmore
   81194:	34fff763 	cbz	w3, 81080 <tfp_format+0x188>
   81198:	7100947f 	cmp	w3, #0x25
   8119c:	54000a01 	b.ne	812dc <tfp_format+0x3e4>  // b.any
                putf(putp, ch);
   811a0:	9100079b 	add	x27, x28, #0x1
   811a4:	2a0303e1 	mov	w1, w3
   811a8:	aa1303e0 	mov	x0, x19
   811ac:	d63f0280 	blr	x20
   811b0:	17ffff6c 	b	80f60 <tfp_format+0x68>
            switch (ch) {
   811b4:	71018c7f 	cmp	w3, #0x63
   811b8:	54000141 	b.ne	811e0 <tfp_format+0x2e8>  // b.any
                putf(putp, (char)(va_arg(va, int)));
   811bc:	37f80cd6 	tbnz	w22, #31, 81354 <tfp_format+0x45c>
   811c0:	91002ea1 	add	x1, x21, #0xb
   811c4:	aa1503e0 	mov	x0, x21
   811c8:	927df035 	and	x21, x1, #0xfffffffffffffff8
   811cc:	39400001 	ldrb	w1, [x0]
   811d0:	9100079b 	add	x27, x28, #0x1
   811d4:	aa1303e0 	mov	x0, x19
   811d8:	d63f0280 	blr	x20
                break;
   811dc:	17ffff61 	b	80f60 <tfp_format+0x68>
            switch (ch) {
   811e0:	7101907f 	cmp	w3, #0x64
   811e4:	540007c1 	b.ne	812dc <tfp_format+0x3e4>  // b.any
                p.base = 10;
   811e8:	b90097fa 	str	w26, [sp, #148]
                if (2 == lng)
   811ec:	7100081f 	cmp	w0, #0x2
   811f0:	54001261 	b.ne	8143c <tfp_format+0x544>  // b.any
                    lli2a(va_arg(va, long long int), &p);
   811f4:	37f81456 	tbnz	w22, #31, 8147c <tfp_format+0x584>
   811f8:	91003ea1 	add	x1, x21, #0xf
   811fc:	aa1503e0 	mov	x0, x21
   81200:	927df035 	and	x21, x1, #0xfffffffffffffff8
   81204:	f9400000 	ldr	x0, [x0]
    if (num < 0) {
   81208:	b6fff920 	tbz	x0, #63, 8112c <tfp_format+0x234>
        p->sign = '-';
   8120c:	528005a1 	mov	w1, #0x2d                  	// #45
        num = -num;
   81210:	cb0003e0 	neg	x0, x0
        p->sign = '-';
   81214:	390243e1 	strb	w1, [sp, #144]
    ulli2a(num, p);
   81218:	17ffffc5 	b	8112c <tfp_format+0x234>
                ch = *(fmt++);
   8121c:	38401783 	ldrb	w3, [x28], #1
            switch (ch) {
   81220:	7101a47f 	cmp	w3, #0x69
   81224:	54001440 	b.eq	814ac <tfp_format+0x5b4>  // b.none
   81228:	52800020 	mov	w0, #0x1                   	// #1
   8122c:	17ffff7b 	b	81018 <tfp_format+0x120>
    unsigned int num = 0;
   81230:	52800002 	mov	w2, #0x0                   	// #0
   81234:	1400000b 	b	81260 <tfp_format+0x368>
    else if (ch >= 'a' && ch <= 'f')
   81238:	7100141f 	cmp	w0, #0x5
   8123c:	54000269 	b.ls	81288 <tfp_format+0x390>  // b.plast
    else if (ch >= 'A' && ch <= 'F')
   81240:	7100143f 	cmp	w1, #0x5
   81244:	54000288 	b.hi	81294 <tfp_format+0x39c>  // b.pmore
        if (digit > base)
   81248:	710028bf 	cmp	w5, #0xa
   8124c:	54000241 	b.ne	81294 <tfp_format+0x39c>  // b.any
        ch = *p++;
   81250:	38401783 	ldrb	w3, [x28], #1
        num = num * base + digit;
   81254:	0b020842 	add	w2, w2, w2, lsl #2
   81258:	5100c066 	sub	w6, w3, #0x30
   8125c:	0b0204a2 	add	w2, w5, w2, lsl #1
    else if (ch >= 'a' && ch <= 'f')
   81260:	51018460 	sub	w0, w3, #0x61
    else if (ch >= 'A' && ch <= 'F')
   81264:	51010461 	sub	w1, w3, #0x41
    if (ch >= '0' && ch <= '9')
   81268:	12001cc4 	and	w4, w6, #0xff
        return ch - 'A' + 10;
   8126c:	5100dc65 	sub	w5, w3, #0x37
    else if (ch >= 'a' && ch <= 'f')
   81270:	12001c00 	and	w0, w0, #0xff
    else if (ch >= 'A' && ch <= 'F')
   81274:	12001c21 	and	w1, w1, #0xff
    if (ch >= '0' && ch <= '9')
   81278:	7100249f 	cmp	w4, #0x9
   8127c:	54fffde8 	b.hi	81238 <tfp_format+0x340>  // b.pmore
        return ch - '0';
   81280:	2a0603e5 	mov	w5, w6
        if (digit > base)
   81284:	17fffff3 	b	81250 <tfp_format+0x358>
        return ch - 'a' + 10;
   81288:	51015c65 	sub	w5, w3, #0x57
        if (digit > base)
   8128c:	710028bf 	cmp	w5, #0xa
   81290:	54fffe00 	b.eq	81250 <tfp_format+0x358>  // b.none
    *nump = num;
   81294:	b9008fe2 	str	w2, [sp, #140]
            if (ch == '.') {
   81298:	7100b87f 	cmp	w3, #0x2e
   8129c:	54ffeb01 	b.ne	80ffc <tfp_format+0x104>  // b.any
              p.lz = 1;  /* zero-padding */
   812a0:	394223e0 	ldrb	w0, [sp, #136]
   812a4:	32000000 	orr	w0, w0, #0x1
   812a8:	390223e0 	strb	w0, [sp, #136]
   812ac:	d503201f 	nop
                ch = *(fmt++);
   812b0:	38401783 	ldrb	w3, [x28], #1
              } while ((ch >= '0') && (ch <= '9'));
   812b4:	5100c060 	sub	w0, w3, #0x30
   812b8:	12001c00 	and	w0, w0, #0xff
   812bc:	7100241f 	cmp	w0, #0x9
   812c0:	54ffff89 	b.ls	812b0 <tfp_format+0x3b8>  // b.plast
   812c4:	17ffff4e 	b	80ffc <tfp_format+0x104>
                ch = *(fmt++);
   812c8:	39400383 	ldrb	w3, [x28]
                if (ch == 'l') {
   812cc:	7101b07f 	cmp	w3, #0x6c
   812d0:	54000720 	b.eq	813b4 <tfp_format+0x4bc>  // b.none
                ch = *(fmt++);
   812d4:	9100079c 	add	x28, x28, #0x1
   812d8:	17ffffd2 	b	81220 <tfp_format+0x328>
   812dc:	9100079b 	add	x27, x28, #0x1
   812e0:	17ffff20 	b	80f60 <tfp_format+0x68>
                p.base = 8;
   812e4:	52800100 	mov	w0, #0x8                   	// #8
   812e8:	b90097e0 	str	w0, [sp, #148]
                ui2a(va_arg(va, unsigned int), &p);
   812ec:	37f80456 	tbnz	w22, #31, 81374 <tfp_format+0x47c>
   812f0:	91002ea1 	add	x1, x21, #0xb
   812f4:	aa1503e0 	mov	x0, x21
   812f8:	927df035 	and	x21, x1, #0xfffffffffffffff8
   812fc:	b9400000 	ldr	w0, [x0]
   81300:	aa1703e1 	mov	x1, x23
   81304:	9100079b 	add	x27, x28, #0x1
   81308:	97fffe42 	bl	80c10 <ui2a>
                putchw(putp, putf, &p);
   8130c:	aa1703e2 	mov	x2, x23
   81310:	aa1403e1 	mov	x1, x20
   81314:	aa1303e0 	mov	x0, x19
   81318:	97fffe70 	bl	80cd8 <putchw>
                break;
   8131c:	17ffff11 	b	80f60 <tfp_format+0x68>
                p.bf = va_arg(va, char *);
   81320:	37f803b6 	tbnz	w22, #31, 81394 <tfp_format+0x49c>
   81324:	91003ea1 	add	x1, x21, #0xf
   81328:	aa1503e0 	mov	x0, x21
   8132c:	927df035 	and	x21, x1, #0xfffffffffffffff8
   81330:	f9400003 	ldr	x3, [x0]
                putchw(putp, putf, &p);
   81334:	aa1703e2 	mov	x2, x23
   81338:	aa1403e1 	mov	x1, x20
   8133c:	aa1303e0 	mov	x0, x19
   81340:	9100079b 	add	x27, x28, #0x1
                p.bf = va_arg(va, char *);
   81344:	f9004fe3 	str	x3, [sp, #152]
                putchw(putp, putf, &p);
   81348:	97fffe64 	bl	80cd8 <putchw>
                p.bf = bf;
   8134c:	f9004ff9 	str	x25, [sp, #152]
                break;
   81350:	17ffff04 	b	80f60 <tfp_format+0x68>
                putf(putp, (char)(va_arg(va, int)));
   81354:	110022c1 	add	w1, w22, #0x8
   81358:	7100003f 	cmp	w1, #0x0
   8135c:	54000d2d 	b.le	81500 <tfp_format+0x608>
   81360:	91002ea2 	add	x2, x21, #0xb
   81364:	aa1503e0 	mov	x0, x21
   81368:	2a0103f6 	mov	w22, w1
   8136c:	927df055 	and	x21, x2, #0xfffffffffffffff8
   81370:	17ffff97 	b	811cc <tfp_format+0x2d4>
                ui2a(va_arg(va, unsigned int), &p);
   81374:	110022c1 	add	w1, w22, #0x8
   81378:	7100003f 	cmp	w1, #0x0
   8137c:	54000d2d 	b.le	81520 <tfp_format+0x628>
   81380:	91002ea2 	add	x2, x21, #0xb
   81384:	aa1503e0 	mov	x0, x21
   81388:	2a0103f6 	mov	w22, w1
   8138c:	927df055 	and	x21, x2, #0xfffffffffffffff8
   81390:	17ffffdb 	b	812fc <tfp_format+0x404>
                p.bf = va_arg(va, char *);
   81394:	110022c1 	add	w1, w22, #0x8
   81398:	7100003f 	cmp	w1, #0x0
   8139c:	54000bad 	b.le	81510 <tfp_format+0x618>
   813a0:	91003ea2 	add	x2, x21, #0xf
   813a4:	aa1503e0 	mov	x0, x21
   813a8:	2a0103f6 	mov	w22, w1
   813ac:	927df055 	and	x21, x2, #0xfffffffffffffff8
   813b0:	17ffffe0 	b	81330 <tfp_format+0x438>
                  ch = *(fmt++);
   813b4:	39400783 	ldrb	w3, [x28, #1]
   813b8:	91000b9c 	add	x28, x28, #0x2
            switch (ch) {
   813bc:	7101a47f 	cmp	w3, #0x69
   813c0:	54000d80 	b.eq	81570 <tfp_format+0x678>  // b.none
                  lng = 2;
   813c4:	52800040 	mov	w0, #0x2                   	// #2
   813c8:	17ffff14 	b	81018 <tfp_format+0x120>
                    ui2a(va_arg(va, unsigned int), &p);
   813cc:	110022c1 	add	w1, w22, #0x8
   813d0:	7100003f 	cmp	w1, #0x0
   813d4:	540001cd 	b.le	8140c <tfp_format+0x514>
   813d8:	91002ea2 	add	x2, x21, #0xb
   813dc:	aa1503e0 	mov	x0, x21
   813e0:	2a0103f6 	mov	w22, w1
   813e4:	927df055 	and	x21, x2, #0xfffffffffffffff8
   813e8:	17ffff1c 	b	81058 <tfp_format+0x160>
                    uli2a(va_arg(va, unsigned long int), &p);
   813ec:	110022c1 	add	w1, w22, #0x8
   813f0:	7100003f 	cmp	w1, #0x0
   813f4:	540003cd 	b.le	8146c <tfp_format+0x574>
   813f8:	91003ea2 	add	x2, x21, #0xf
   813fc:	aa1503e0 	mov	x0, x21
   81400:	2a0103f6 	mov	w22, w1
   81404:	927df055 	and	x21, x2, #0xfffffffffffffff8
   81408:	17ffff5a 	b	81170 <tfp_format+0x278>
                    ui2a(va_arg(va, unsigned int), &p);
   8140c:	f94037e0 	ldr	x0, [sp, #104]
   81410:	8b36c000 	add	x0, x0, w22, sxtw
   81414:	2a0103f6 	mov	w22, w1
   81418:	17ffff10 	b	81058 <tfp_format+0x160>
                    ulli2a(va_arg(va, unsigned long long int), &p);
   8141c:	110022c1 	add	w1, w22, #0x8
   81420:	7100003f 	cmp	w1, #0x0
   81424:	540003cd 	b.le	8149c <tfp_format+0x5a4>
   81428:	91003ea2 	add	x2, x21, #0xf
   8142c:	aa1503e0 	mov	x0, x21
   81430:	2a0103f6 	mov	w22, w1
   81434:	927df055 	and	x21, x2, #0xfffffffffffffff8
   81438:	17ffff3c 	b	81128 <tfp_format+0x230>
                  if (1 == lng)
   8143c:	7100041f 	cmp	w0, #0x1
   81440:	54000380 	b.eq	814b0 <tfp_format+0x5b8>  // b.none
                    i2a(va_arg(va, int), &p);
   81444:	37f804f6 	tbnz	w22, #31, 814e0 <tfp_format+0x5e8>
   81448:	91002ea1 	add	x1, x21, #0xb
   8144c:	aa1503e0 	mov	x0, x21
   81450:	927df035 	and	x21, x1, #0xfffffffffffffff8
   81454:	b9400000 	ldr	w0, [x0]
    if (num < 0) {
   81458:	36ffe020 	tbz	w0, #31, 8105c <tfp_format+0x164>
        p->sign = '-';
   8145c:	528005a1 	mov	w1, #0x2d                  	// #45
        num = -num;
   81460:	4b0003e0 	neg	w0, w0
        p->sign = '-';
   81464:	390243e1 	strb	w1, [sp, #144]
    ui2a(num, p);
   81468:	17fffefd 	b	8105c <tfp_format+0x164>
                    uli2a(va_arg(va, unsigned long int), &p);
   8146c:	f94037e0 	ldr	x0, [sp, #104]
   81470:	8b36c000 	add	x0, x0, w22, sxtw
   81474:	2a0103f6 	mov	w22, w1
   81478:	17ffff3e 	b	81170 <tfp_format+0x278>
                    lli2a(va_arg(va, long long int), &p);
   8147c:	110022c1 	add	w1, w22, #0x8
   81480:	7100003f 	cmp	w1, #0x0
   81484:	540006ed 	b.le	81560 <tfp_format+0x668>
   81488:	91003ea2 	add	x2, x21, #0xf
   8148c:	aa1503e0 	mov	x0, x21
   81490:	2a0103f6 	mov	w22, w1
   81494:	927df055 	and	x21, x2, #0xfffffffffffffff8
   81498:	17ffff5b 	b	81204 <tfp_format+0x30c>
                    ulli2a(va_arg(va, unsigned long long int), &p);
   8149c:	f94037e0 	ldr	x0, [sp, #104]
   814a0:	8b36c000 	add	x0, x0, w22, sxtw
   814a4:	2a0103f6 	mov	w22, w1
   814a8:	17ffff20 	b	81128 <tfp_format+0x230>
                p.base = 10;
   814ac:	b90097fa 	str	w26, [sp, #148]
                    li2a(va_arg(va, long int), &p);
   814b0:	37f80416 	tbnz	w22, #31, 81530 <tfp_format+0x638>
   814b4:	91003ea1 	add	x1, x21, #0xf
   814b8:	aa1503e0 	mov	x0, x21
   814bc:	927df035 	and	x21, x1, #0xfffffffffffffff8
   814c0:	f9400000 	ldr	x0, [x0]
    if (num < 0) {
   814c4:	b6ffe580 	tbz	x0, #63, 81174 <tfp_format+0x27c>
        p->sign = '-';
   814c8:	528005a1 	mov	w1, #0x2d                  	// #45
        num = -num;
   814cc:	cb0003e0 	neg	x0, x0
        p->sign = '-';
   814d0:	390243e1 	strb	w1, [sp, #144]
    uli2a(num, p);
   814d4:	17ffff28 	b	81174 <tfp_format+0x27c>
                p.base = 10;
   814d8:	b90097fa 	str	w26, [sp, #148]
                if (2 == lng)
   814dc:	17ffffda 	b	81444 <tfp_format+0x54c>
                    i2a(va_arg(va, int), &p);
   814e0:	110022c1 	add	w1, w22, #0x8
   814e4:	7100003f 	cmp	w1, #0x0
   814e8:	5400034d 	b.le	81550 <tfp_format+0x658>
   814ec:	91002ea2 	add	x2, x21, #0xb
   814f0:	aa1503e0 	mov	x0, x21
   814f4:	2a0103f6 	mov	w22, w1
   814f8:	927df055 	and	x21, x2, #0xfffffffffffffff8
   814fc:	17ffffd6 	b	81454 <tfp_format+0x55c>
                putf(putp, (char)(va_arg(va, int)));
   81500:	f94037e0 	ldr	x0, [sp, #104]
   81504:	8b36c000 	add	x0, x0, w22, sxtw
   81508:	2a0103f6 	mov	w22, w1
   8150c:	17ffff30 	b	811cc <tfp_format+0x2d4>
                p.bf = va_arg(va, char *);
   81510:	f94037e0 	ldr	x0, [sp, #104]
   81514:	8b36c000 	add	x0, x0, w22, sxtw
   81518:	2a0103f6 	mov	w22, w1
   8151c:	17ffff85 	b	81330 <tfp_format+0x438>
                ui2a(va_arg(va, unsigned int), &p);
   81520:	f94037e0 	ldr	x0, [sp, #104]
   81524:	8b36c000 	add	x0, x0, w22, sxtw
   81528:	2a0103f6 	mov	w22, w1
   8152c:	17ffff74 	b	812fc <tfp_format+0x404>
                    li2a(va_arg(va, long int), &p);
   81530:	110022c1 	add	w1, w22, #0x8
   81534:	7100003f 	cmp	w1, #0x0
   81538:	5400022d 	b.le	8157c <tfp_format+0x684>
   8153c:	91003ea2 	add	x2, x21, #0xf
   81540:	aa1503e0 	mov	x0, x21
   81544:	2a0103f6 	mov	w22, w1
   81548:	927df055 	and	x21, x2, #0xfffffffffffffff8
   8154c:	17ffffdd 	b	814c0 <tfp_format+0x5c8>
                    i2a(va_arg(va, int), &p);
   81550:	f94037e0 	ldr	x0, [sp, #104]
   81554:	8b36c000 	add	x0, x0, w22, sxtw
   81558:	2a0103f6 	mov	w22, w1
   8155c:	17ffffbe 	b	81454 <tfp_format+0x55c>
                    lli2a(va_arg(va, long long int), &p);
   81560:	f94037e0 	ldr	x0, [sp, #104]
   81564:	8b36c000 	add	x0, x0, w22, sxtw
   81568:	2a0103f6 	mov	w22, w1
   8156c:	17ffff26 	b	81204 <tfp_format+0x30c>
                p.base = 10;
   81570:	b90097fa 	str	w26, [sp, #148]
                    lli2a(va_arg(va, long long int), &p);
   81574:	36ffe436 	tbz	w22, #31, 811f8 <tfp_format+0x300>
   81578:	17ffffc1 	b	8147c <tfp_format+0x584>
                    li2a(va_arg(va, long int), &p);
   8157c:	f94037e0 	ldr	x0, [sp, #104]
   81580:	8b36c000 	add	x0, x0, w22, sxtw
   81584:	2a0103f6 	mov	w22, w1
   81588:	17ffffce 	b	814c0 <tfp_format+0x5c8>
   8158c:	d503201f 	nop

0000000000081590 <init_printf>:
    stdout_putf = putf;
   81590:	d0000082 	adrp	x2, 93000 <get_el+0xe61c>
   81594:	913c0043 	add	x3, x2, #0xf00
   81598:	f9078041 	str	x1, [x2, #3840]
    stdout_putp = putp;
   8159c:	f9000460 	str	x0, [x3, #8]
}
   815a0:	d65f03c0 	ret
   815a4:	d503201f 	nop

00000000000815a8 <tfp_printf>:
{
   815a8:	a9b77bfd 	stp	x29, x30, [sp, #-144]!
    tfp_format(stdout_putp, stdout_putf, fmt, va);
   815ac:	d0000088 	adrp	x8, 93000 <get_el+0xe61c>
   815b0:	913c010b 	add	x11, x8, #0xf00
{
   815b4:	910003fd 	mov	x29, sp
   815b8:	f9002fe1 	str	x1, [sp, #88]
   815bc:	aa0003ea 	mov	x10, x0
    tfp_format(stdout_putp, stdout_putf, fmt, va);
   815c0:	f9478101 	ldr	x1, [x8, #3840]
    va_start(va, fmt);
   815c4:	910143e9 	add	x9, sp, #0x50
    tfp_format(stdout_putp, stdout_putf, fmt, va);
   815c8:	f9400560 	ldr	x0, [x11, #8]
    va_start(va, fmt);
   815cc:	910243eb 	add	x11, sp, #0x90
   815d0:	a9032feb 	stp	x11, x11, [sp, #48]
   815d4:	128006e8 	mov	w8, #0xffffffc8            	// #-56
   815d8:	f90023e9 	str	x9, [sp, #64]
   815dc:	b9004be8 	str	w8, [sp, #72]
   815e0:	b9004fff 	str	wzr, [sp, #76]
    tfp_format(stdout_putp, stdout_putf, fmt, va);
   815e4:	a94327e8 	ldp	x8, x9, [sp, #48]
   815e8:	a90127e8 	stp	x8, x9, [sp, #16]
   815ec:	a94427e8 	ldp	x8, x9, [sp, #64]
   815f0:	a90227e8 	stp	x8, x9, [sp, #32]
{
   815f4:	a9060fe2 	stp	x2, x3, [sp, #96]
    tfp_format(stdout_putp, stdout_putf, fmt, va);
   815f8:	910043e3 	add	x3, sp, #0x10
   815fc:	aa0a03e2 	mov	x2, x10
{
   81600:	a90717e4 	stp	x4, x5, [sp, #112]
   81604:	a9081fe6 	stp	x6, x7, [sp, #128]
    tfp_format(stdout_putp, stdout_putf, fmt, va);
   81608:	97fffe3c 	bl	80ef8 <tfp_format>
}
   8160c:	a8c97bfd 	ldp	x29, x30, [sp], #144
   81610:	d65f03c0 	ret
   81614:	d503201f 	nop

0000000000081618 <tfp_vsnprintf>:
  if (size < 1)
   81618:	b5000061 	cbnz	x1, 81624 <tfp_vsnprintf+0xc>
    return 0;
   8161c:	52800000 	mov	w0, #0x0                   	// #0
}
   81620:	d65f03c0 	ret
{
   81624:	a9bb7bfd 	stp	x29, x30, [sp, #-80]!
   81628:	aa0003e5 	mov	x5, x0
  data.dest_capacity = size-1;
   8162c:	d1000424 	sub	x4, x1, #0x1
{
   81630:	910003fd 	mov	x29, sp
  tfp_format(&data, _vsnprintf_putcf, format, ap);
   81634:	a9402468 	ldp	x8, x9, [x3]
   81638:	9100e3e0 	add	x0, sp, #0x38
   8163c:	a9411c66 	ldp	x6, x7, [x3, #16]
   81640:	f0ffffe1 	adrp	x1, 80000 <_start>
   81644:	910043e3 	add	x3, sp, #0x10
   81648:	913ac021 	add	x1, x1, #0xeb0
   8164c:	a90127e8 	stp	x8, x9, [sp, #16]
   81650:	a9021fe6 	stp	x6, x7, [sp, #32]
  data.dest = str;
   81654:	a90397e4 	stp	x4, x5, [sp, #56]
  data.num_chars = 0;
   81658:	f90027ff 	str	xzr, [sp, #72]
  tfp_format(&data, _vsnprintf_putcf, format, ap);
   8165c:	97fffe27 	bl	80ef8 <tfp_format>
  if (data.num_chars < data.dest_capacity)
   81660:	f9401fe0 	ldr	x0, [sp, #56]
   81664:	f94027e1 	ldr	x1, [sp, #72]
   81668:	eb00003f 	cmp	x1, x0
   8166c:	540000c2 	b.cs	81684 <tfp_vsnprintf+0x6c>  // b.hs, b.nlast
    data.dest[data.num_chars] = '\0';
   81670:	f94023e0 	ldr	x0, [sp, #64]
   81674:	3821681f 	strb	wzr, [x0, x1]
  return data.num_chars;
   81678:	b9404be0 	ldr	w0, [sp, #72]
}
   8167c:	a8c57bfd 	ldp	x29, x30, [sp], #80
   81680:	d65f03c0 	ret
    data.dest[data.dest_capacity] = '\0';
   81684:	f94023e1 	ldr	x1, [sp, #64]
   81688:	3820683f 	strb	wzr, [x1, x0]
  return data.num_chars;
   8168c:	b9404be0 	ldr	w0, [sp, #72]
}
   81690:	a8c57bfd 	ldp	x29, x30, [sp], #80
   81694:	d65f03c0 	ret

0000000000081698 <tfp_snprintf>:
{
   81698:	a9b87bfd 	stp	x29, x30, [sp, #-128]!
  va_start(ap, format);
   8169c:	128004e8 	mov	w8, #0xffffffd8            	// #-40
{
   816a0:	910003fd 	mov	x29, sp
  va_start(ap, format);
   816a4:	910203ea 	add	x10, sp, #0x80
   816a8:	a9032bea 	stp	x10, x10, [sp, #48]
   816ac:	910143e9 	add	x9, sp, #0x50
   816b0:	f90023e9 	str	x9, [sp, #64]
   816b4:	29097fe8 	stp	w8, wzr, [sp, #72]
  retval = tfp_vsnprintf(str, size, format, ap);
   816b8:	a94327e8 	ldp	x8, x9, [sp, #48]
   816bc:	a90127e8 	stp	x8, x9, [sp, #16]
   816c0:	a94427e8 	ldp	x8, x9, [sp, #64]
   816c4:	a90227e8 	stp	x8, x9, [sp, #32]
{
   816c8:	a90593e3 	stp	x3, x4, [sp, #88]
  retval = tfp_vsnprintf(str, size, format, ap);
   816cc:	910043e3 	add	x3, sp, #0x10
{
   816d0:	a9069be5 	stp	x5, x6, [sp, #104]
   816d4:	f9003fe7 	str	x7, [sp, #120]
  retval = tfp_vsnprintf(str, size, format, ap);
   816d8:	97ffffd0 	bl	81618 <tfp_vsnprintf>
}
   816dc:	a8c87bfd 	ldp	x29, x30, [sp], #128
   816e0:	d65f03c0 	ret
   816e4:	d503201f 	nop

00000000000816e8 <tfp_vsprintf>:

int tfp_vsprintf(char *str, const char *format, va_list ap)
{
   816e8:	aa0203e4 	mov	x4, x2
   816ec:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
   816f0:	aa0003e5 	mov	x5, x0
   816f4:	910003fd 	mov	x29, sp
  struct _vsprintf_putcf_data data;
  data.dest = str;
  data.num_chars = 0;
  tfp_format(&data, _vsprintf_putcf, format, ap);
   816f8:	a9402488 	ldp	x8, x9, [x4]
   816fc:	aa0103e2 	mov	x2, x1
   81700:	a9411c86 	ldp	x6, x7, [x4, #16]
   81704:	910043e3 	add	x3, sp, #0x10
   81708:	9100c3e0 	add	x0, sp, #0x30
   8170c:	f0ffffe1 	adrp	x1, 80000 <_start>
   81710:	913b8021 	add	x1, x1, #0xee0
   81714:	a90127e8 	stp	x8, x9, [sp, #16]
   81718:	a9021fe6 	stp	x6, x7, [sp, #32]
  data.num_chars = 0;
   8171c:	a9037fe5 	stp	x5, xzr, [sp, #48]
  tfp_format(&data, _vsprintf_putcf, format, ap);
   81720:	97fffdf6 	bl	80ef8 <tfp_format>
  data.dest[data.num_chars] = '\0';
   81724:	a94303e1 	ldp	x1, x0, [sp, #48]
   81728:	3820683f 	strb	wzr, [x1, x0]
  return data.num_chars;
}
   8172c:	b9403be0 	ldr	w0, [sp, #56]
   81730:	a8c47bfd 	ldp	x29, x30, [sp], #64
   81734:	d65f03c0 	ret

0000000000081738 <tfp_sprintf>:

int tfp_sprintf(char *str, const char *format, ...)
{
   81738:	a9b57bfd 	stp	x29, x30, [sp, #-176]!
  va_list ap;
  int retval;

  va_start(ap, format);
   8173c:	128005e8 	mov	w8, #0xffffffd0            	// #-48
{
   81740:	aa0103ec 	mov	x12, x1
   81744:	910003fd 	mov	x29, sp
  va_start(ap, format);
   81748:	910203e9 	add	x9, sp, #0x80
   8174c:	9102c3ea 	add	x10, sp, #0xb0
   81750:	a9042bea 	stp	x10, x10, [sp, #64]
{
   81754:	aa0003ed 	mov	x13, x0
  tfp_format(&data, _vsprintf_putcf, format, ap);
   81758:	f0ffffe1 	adrp	x1, 80000 <_start>
  va_start(ap, format);
   8175c:	f9002be9 	str	x9, [sp, #80]
  tfp_format(&data, _vsprintf_putcf, format, ap);
   81760:	9100c3e0 	add	x0, sp, #0x30
  va_start(ap, format);
   81764:	290b7fe8 	stp	w8, wzr, [sp, #88]
  tfp_format(&data, _vsprintf_putcf, format, ap);
   81768:	913b8021 	add	x1, x1, #0xee0
   8176c:	a9442fea 	ldp	x10, x11, [sp, #64]
   81770:	a9012fea 	stp	x10, x11, [sp, #16]
   81774:	a94527e8 	ldp	x8, x9, [sp, #80]
   81778:	a90227e8 	stp	x8, x9, [sp, #32]
  data.num_chars = 0;
   8177c:	a9037fed 	stp	x13, xzr, [sp, #48]
   81780:	a9062fea 	stp	x10, x11, [sp, #96]
   81784:	a90727e8 	stp	x8, x9, [sp, #112]
{
   81788:	a9080fe2 	stp	x2, x3, [sp, #128]
  tfp_format(&data, _vsprintf_putcf, format, ap);
   8178c:	910043e3 	add	x3, sp, #0x10
   81790:	aa0c03e2 	mov	x2, x12
{
   81794:	a90917e4 	stp	x4, x5, [sp, #144]
   81798:	a90a1fe6 	stp	x6, x7, [sp, #160]
  tfp_format(&data, _vsprintf_putcf, format, ap);
   8179c:	97fffdd7 	bl	80ef8 <tfp_format>
  data.dest[data.num_chars] = '\0';
   817a0:	a94303e1 	ldp	x1, x0, [sp, #48]
   817a4:	3820683f 	strb	wzr, [x1, x0]
  retval = tfp_vsprintf(str, format, ap);
  va_end(ap);
  return retval;
}
   817a8:	b9403be0 	ldr	w0, [sp, #56]
   817ac:	a8cb7bfd 	ldp	x29, x30, [sp], #176
   817b0:	d65f03c0 	ret
   817b4:	d503201f 	nop

00000000000817b8 <panic>:
#endif

// xv6
void panic(char *s)
{
   817b8:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
  printf("panic: ");
   817bc:	f0000002 	adrp	x2, 84000 <vectors>
{
   817c0:	910003fd 	mov	x29, sp
   817c4:	f9000bf3 	str	x19, [sp, #16]
   817c8:	aa0003f3 	mov	x19, x0
  printf("panic: ");
   817cc:	91342040 	add	x0, x2, #0xd08
   817d0:	97ffff76 	bl	815a8 <tfp_printf>
  printf("%s\n", s);
   817d4:	aa1303e1 	mov	x1, x19
   817d8:	f0000000 	adrp	x0, 84000 <vectors>
   817dc:	91344000 	add	x0, x0, #0xd10
   817e0:	97ffff72 	bl	815a8 <tfp_printf>
//   panicked = 1; // freeze uart output from other CPUs
    asm volatile("msr	daifset, #0b0010 "); // disable irq
   817e4:	d50342df 	msr	daifset, #0x2
  for(;;)
   817e8:	14000000 	b	817e8 <panic+0x30>
   817ec:	d503201f 	nop

00000000000817f0 <debug_hexdump>:
}

// circle debug.cpp
// will dump at least 16 bytes....
void debug_hexdump (const void *pStart, unsigned nBytes)
{
   817f0:	d10203ff 	sub	sp, sp, #0x80
	unsigned char *pOffset = (unsigned char *) pStart;
	
	printf("Dumping 0x%x bytes starting at 0x%lx\r\n", nBytes,
   817f4:	aa0003e2 	mov	x2, x0
{
   817f8:	a9057bfd 	stp	x29, x30, [sp, #80]
   817fc:	910143fd 	add	x29, sp, #0x50
   81800:	a90653f3 	stp	x19, x20, [sp, #96]
   81804:	aa0003f4 	mov	x20, x0
	printf("Dumping 0x%x bytes starting at 0x%lx\r\n", nBytes,
   81808:	f0000000 	adrp	x0, 84000 <vectors>
   8180c:	91346000 	add	x0, x0, #0xd18
{
   81810:	a9075bf5 	stp	x21, x22, [sp, #112]
   81814:	2a0103f5 	mov	w21, w1
	printf("Dumping 0x%x bytes starting at 0x%lx\r\n", nBytes,
   81818:	97ffff64 	bl	815a8 <tfp_printf>
				(unsigned long) pOffset);
	
	while (nBytes > 0)
   8181c:	34000575 	cbz	w21, 818c8 <debug_hexdump+0xd8>
   81820:	927c6ea2 	and	x2, x21, #0xfffffff0
	unsigned char *pOffset = (unsigned char *) pStart;
   81824:	aa1403f3 	mov	x19, x20
   81828:	91004042 	add	x2, x2, #0x10
	while (nBytes > 0)
   8182c:	0b1402b5 	add	w21, w21, w20
   81830:	f0000016 	adrp	x22, 84000 <vectors>
   81834:	8b020294 	add	x20, x20, x2
	{
		printf(
   81838:	913502d6 	add	x22, x22, #0xd40
   8183c:	14000003 	b	81848 <debug_hexdump+0x58>
	while (nBytes > 0)
   81840:	6b1302bf 	cmp	w21, w19
   81844:	54000420 	b.eq	818c8 <debug_hexdump+0xd8>  // b.none
		printf(
   81848:	39402e68 	ldrb	w8, [x19, #11]
   8184c:	92403e61 	and	x1, x19, #0xffff
   81850:	39402a69 	ldrb	w9, [x19, #10]
   81854:	aa1603e0 	mov	x0, x22
   81858:	3940266a 	ldrb	w10, [x19, #9]
				(unsigned) pOffset[0],  (unsigned) pOffset[1],  (unsigned) pOffset[2],  (unsigned) pOffset[3],
				(unsigned) pOffset[4],  (unsigned) pOffset[5],  (unsigned) pOffset[6],  (unsigned) pOffset[7],
				(unsigned) pOffset[8],  (unsigned) pOffset[9],  (unsigned) pOffset[10], (unsigned) pOffset[11],
				(unsigned) pOffset[12], (unsigned) pOffset[13], (unsigned) pOffset[14], (unsigned) pOffset[15]);

		pOffset += 16;
   8185c:	91004273 	add	x19, x19, #0x10
		printf(
   81860:	385f826b 	ldurb	w11, [x19, #-8]
   81864:	385f726c 	ldurb	w12, [x19, #-9]
   81868:	385f626d 	ldurb	w13, [x19, #-10]
   8186c:	385f5267 	ldurb	w7, [x19, #-11]
   81870:	385f4266 	ldurb	w6, [x19, #-12]
   81874:	385f3265 	ldurb	w5, [x19, #-13]
   81878:	385f2264 	ldurb	w4, [x19, #-14]
   8187c:	385f1263 	ldurb	w3, [x19, #-15]
   81880:	385f0262 	ldurb	w2, [x19, #-16]
   81884:	b90003ed 	str	w13, [sp]
   81888:	b9000bec 	str	w12, [sp, #8]
   8188c:	b90013eb 	str	w11, [sp, #16]
   81890:	b9001bea 	str	w10, [sp, #24]
   81894:	b90023e9 	str	w9, [sp, #32]
   81898:	b9002be8 	str	w8, [sp, #40]
   8189c:	385ff268 	ldurb	w8, [x19, #-1]
   818a0:	385fe269 	ldurb	w9, [x19, #-2]
   818a4:	385fd26a 	ldurb	w10, [x19, #-3]
   818a8:	385fc26b 	ldurb	w11, [x19, #-4]
   818ac:	b90033eb 	str	w11, [sp, #48]
   818b0:	b9003bea 	str	w10, [sp, #56]
   818b4:	b90043e9 	str	w9, [sp, #64]
   818b8:	b9004be8 	str	w8, [sp, #72]
   818bc:	97ffff3b 	bl	815a8 <tfp_printf>
		if (nBytes >= 16)
   818c0:	eb14027f 	cmp	x19, x20
   818c4:	54fffbe1 	b.ne	81840 <debug_hexdump+0x50>  // b.any
		else
		{
			nBytes = 0;
		}
	}
}
   818c8:	a9457bfd 	ldp	x29, x30, [sp, #80]
   818cc:	a94653f3 	ldp	x19, x20, [sp, #96]
   818d0:	a9475bf5 	ldp	x21, x22, [sp, #112]
   818d4:	910203ff 	add	sp, sp, #0x80
   818d8:	d65f03c0 	ret
   818dc:	d503201f 	nop

00000000000818e0 <assertion_failed>:

// circle assert.cpp        
void assertion_failed (const char *pExpr, const char *pFile, unsigned nLine) {
   818e0:	aa0103e4 	mov	x4, x1
   818e4:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
    printf("assertion failed: %s at %s:%u\n", pExpr, pFile, nLine); 
   818e8:	aa0003e1 	mov	x1, x0
   818ec:	2a0203e3 	mov	w3, w2
   818f0:	aa0403e2 	mov	x2, x4
void assertion_failed (const char *pExpr, const char *pFile, unsigned nLine) {
   818f4:	910003fd 	mov	x29, sp
    printf("assertion failed: %s at %s:%u\n", pExpr, pFile, nLine); 
   818f8:	f0000000 	adrp	x0, 84000 <vectors>
   818fc:	91368000 	add	x0, x0, #0xda0
   81900:	97ffff2a 	bl	815a8 <tfp_printf>
    panic("kernel hangs"); 
   81904:	f0000000 	adrp	x0, 84000 <vectors>
   81908:	91370000 	add	x0, x0, #0xdc0
   8190c:	97ffffab 	bl	817b8 <panic>

0000000000081910 <memset>:

/* c: the fill value (byte); n: size, in bytes */
void *memset(void *dst, int c, uint n) {
    char *cdst = (char *)dst;
    int i;
    for (i = 0; i < n; i++) {
   81910:	34000122 	cbz	w2, 81934 <memset+0x24>
   81914:	51000442 	sub	w2, w2, #0x1
   81918:	12001c23 	and	w3, w1, #0xff
   8191c:	91000442 	add	x2, x2, #0x1
   81920:	aa0003e1 	mov	x1, x0
   81924:	8b000042 	add	x2, x2, x0
        cdst[i] = c;
   81928:	38001423 	strb	w3, [x1], #1
    for (i = 0; i < n; i++) {
   8192c:	eb02003f 	cmp	x1, x2
   81930:	54ffffc1 	b.ne	81928 <memset+0x18>  // b.any
    }
    return dst;
}
   81934:	d65f03c0 	ret

0000000000081938 <memzero>:
    for (i = 0; i < n; i++) {
   81938:	34000101 	cbz	w1, 81958 <memzero+0x20>
   8193c:	51000421 	sub	w1, w1, #0x1
   81940:	8b010002 	add	x2, x0, x1
   81944:	d503201f 	nop
        cdst[i] = c;
   81948:	3900001f 	strb	wzr, [x0]
    for (i = 0; i < n; i++) {
   8194c:	eb02001f 	cmp	x0, x2
   81950:	91000400 	add	x0, x0, #0x1
   81954:	54ffffa1 	b.ne	81948 <memzero+0x10>  // b.any

void memzero(void *dst, uint n) {
    memset(dst, 0, n);
}
   81958:	d65f03c0 	ret
   8195c:	d503201f 	nop

0000000000081960 <memcmp>:
int memcmp(const void *v1, const void *v2, uint n) {
    const uchar *s1, *s2;

    s1 = v1;
    s2 = v2;
    while (n-- > 0) {
   81960:	51000446 	sub	w6, w2, #0x1
   81964:	340001a2 	cbz	w2, 81998 <memcmp+0x38>
   81968:	d2800002 	mov	x2, #0x0                   	// #0
   8196c:	14000004 	b	8197c <memcmp+0x1c>
   81970:	eb0200df 	cmp	x6, x2
   81974:	aa0503e2 	mov	x2, x5
   81978:	54000100 	b.eq	81998 <memcmp+0x38>  // b.none
        if (*s1 != *s2)
   8197c:	38626803 	ldrb	w3, [x0, x2]
   81980:	91000445 	add	x5, x2, #0x1
   81984:	38626824 	ldrb	w4, [x1, x2]
   81988:	6b04007f 	cmp	w3, w4
   8198c:	54ffff20 	b.eq	81970 <memcmp+0x10>  // b.none
            return *s1 - *s2;
   81990:	4b040060 	sub	w0, w3, w4
        s1++, s2++;
    }

    return 0;
}
   81994:	d65f03c0 	ret
    return 0;
   81998:	52800000 	mov	w0, #0x0                   	// #0
}
   8199c:	d65f03c0 	ret

00000000000819a0 <memmove>:
/* well handles dst/src overlap */
void *memmove(void *dst, const void *src, uint n) {
    const char *s;
    char *d;

    if (n == 0)
   819a0:	34000162 	cbz	w2, 819cc <memmove+0x2c>
        return dst;

    s = src;
    d = dst;
    if (s < d && s + n > d) {
   819a4:	eb00003f 	cmp	x1, x0
   819a8:	51000445 	sub	w5, w2, #0x1
   819ac:	54000123 	b.cc	819d0 <memmove+0x30>  // b.lo, b.ul, b.last
void *memmove(void *dst, const void *src, uint n) {
   819b0:	d2800002 	mov	x2, #0x0                   	// #0
   819b4:	d503201f 	nop
        d += n;
        while (n-- > 0)
            *--d = *--s;
    } else
        while (n-- > 0)
            *d++ = *s++;
   819b8:	38626824 	ldrb	w4, [x1, x2]
        while (n-- > 0)
   819bc:	eb0200bf 	cmp	x5, x2
            *d++ = *s++;
   819c0:	38226804 	strb	w4, [x0, x2]
        while (n-- > 0)
   819c4:	91000442 	add	x2, x2, #0x1
   819c8:	54ffff81 	b.ne	819b8 <memmove+0x18>  // b.any

    return dst;
}
   819cc:	d65f03c0 	ret
    if (s < d && s + n > d) {
   819d0:	2a0203e2 	mov	w2, w2
   819d4:	8b020024 	add	x4, x1, x2
   819d8:	eb00009f 	cmp	x4, x0
   819dc:	54fffea9 	b.ls	819b0 <memmove+0x10>  // b.plast
        d += n;
   819e0:	92800021 	mov	x1, #0xfffffffffffffffe    	// #-2
   819e4:	8b020002 	add	x2, x0, x2
        while (n-- > 0)
   819e8:	cb254025 	sub	x5, x1, w5, uxtw
        d += n;
   819ec:	92800001 	mov	x1, #0xffffffffffffffff    	// #-1
            *--d = *--s;
   819f0:	38616883 	ldrb	w3, [x4, x1]
   819f4:	38216843 	strb	w3, [x2, x1]
        while (n-- > 0)
   819f8:	d1000421 	sub	x1, x1, #0x1
   819fc:	eb0100bf 	cmp	x5, x1
   81a00:	54ffff81 	b.ne	819f0 <memmove+0x50>  // b.any
}
   81a04:	d65f03c0 	ret

0000000000081a08 <memcpy>:
 * memcpy exists to satisfy GCC. Use memmove instead.
 * Note: GCC may generate code to invoke memcpy for struct assignment,
 * so the function below must handle all cases correctly (e.g., cannot assume any alignment).
 */
void *memcpy(void *dst, const void *src, uint n) {
    return memmove(dst, src, n);
   81a08:	17ffffe6 	b	819a0 <memmove>
   81a0c:	d503201f 	nop

0000000000081a10 <strncmp>:
}

int strncmp(const char *p, const char *q, uint n) {
    while (n > 0 && *p && *p == *q)
   81a10:	340001e2 	cbz	w2, 81a4c <strncmp+0x3c>
   81a14:	51000446 	sub	w6, w2, #0x1
   81a18:	d2800002 	mov	x2, #0x0                   	// #0
   81a1c:	14000005 	b	81a30 <strncmp+0x20>
   81a20:	54000121 	b.ne	81a44 <strncmp+0x34>  // b.any
   81a24:	eb0200df 	cmp	x6, x2
   81a28:	aa0503e2 	mov	x2, x5
   81a2c:	54000100 	b.eq	81a4c <strncmp+0x3c>  // b.none
   81a30:	38626803 	ldrb	w3, [x0, x2]
   81a34:	91000445 	add	x5, x2, #0x1
   81a38:	38626824 	ldrb	w4, [x1, x2]
   81a3c:	6b04007f 	cmp	w3, w4
   81a40:	35ffff03 	cbnz	w3, 81a20 <strncmp+0x10>
        n--, p++, q++;
    if (n == 0)
        return 0;
    return (uchar)*p - (uchar)*q;
   81a44:	4b040060 	sub	w0, w3, w4
}
   81a48:	d65f03c0 	ret
        return 0;
   81a4c:	52800000 	mov	w0, #0x0                   	// #0
}
   81a50:	d65f03c0 	ret
   81a54:	d503201f 	nop

0000000000081a58 <strncpy>:

char *strncpy(char *s, const char *t, int n) {
    char *os;

    os = s;
    while (n-- > 0 && (*s++ = *t++) != 0)
   81a58:	aa0103e5 	mov	x5, x1
   81a5c:	aa0003e1 	mov	x1, x0
   81a60:	14000004 	b	81a70 <strncpy+0x18>
   81a64:	384014a4 	ldrb	w4, [x5], #1
   81a68:	38001424 	strb	w4, [x1], #1
   81a6c:	340000a4 	cbz	w4, 81a80 <strncpy+0x28>
   81a70:	2a0203e3 	mov	w3, w2
   81a74:	51000442 	sub	w2, w2, #0x1
   81a78:	7100007f 	cmp	w3, #0x0
   81a7c:	54ffff4c 	b.gt	81a64 <strncpy+0xc>
        ;
    while (n-- > 0)
   81a80:	7100005f 	cmp	w2, #0x0
   81a84:	0b010063 	add	w3, w3, w1
   81a88:	540000ed 	b.le	81aa4 <strncpy+0x4c>
   81a8c:	d503201f 	nop
        *s++ = 0;
   81a90:	3800143f 	strb	wzr, [x1], #1
    while (n-- > 0)
   81a94:	2a2103e2 	mvn	w2, w1
   81a98:	0b030042 	add	w2, w2, w3
   81a9c:	7100005f 	cmp	w2, #0x0
   81aa0:	54ffff8c 	b.gt	81a90 <strncpy+0x38>
    return os;
}
   81aa4:	d65f03c0 	ret

0000000000081aa8 <safestrcpy>:
/* Like strncpy but guaranteed to NUL-terminate. */
char *safestrcpy(char *s, const char *t, int n) {
    char *os;

    os = s;
    if (n <= 0)
   81aa8:	7100005f 	cmp	w2, #0x0
   81aac:	5400016d 	b.le	81ad8 <safestrcpy+0x30>
   81ab0:	51000442 	sub	w2, w2, #0x1
   81ab4:	aa0003e3 	mov	x3, x0
   81ab8:	8b020024 	add	x4, x1, x2
   81abc:	14000004 	b	81acc <safestrcpy+0x24>
        return os;
    while (--n > 0 && (*s++ = *t++) != 0)
   81ac0:	38401422 	ldrb	w2, [x1], #1
   81ac4:	38001462 	strb	w2, [x3], #1
   81ac8:	34000062 	cbz	w2, 81ad4 <safestrcpy+0x2c>
   81acc:	eb04003f 	cmp	x1, x4
   81ad0:	54ffff81 	b.ne	81ac0 <safestrcpy+0x18>  // b.any
        ;
    *s = 0;
   81ad4:	3900007f 	strb	wzr, [x3]
    return os;
}
   81ad8:	d65f03c0 	ret
   81adc:	d503201f 	nop

0000000000081ae0 <strlen>:

int strlen(const char *s) {
    int n;

    for (n = 0; s[n]; n++)
   81ae0:	39400001 	ldrb	w1, [x0]
   81ae4:	34000101 	cbz	w1, 81b04 <strlen+0x24>
   81ae8:	d1000403 	sub	x3, x0, #0x1
   81aec:	d2800021 	mov	x1, #0x1                   	// #1
   81af0:	2a0103e0 	mov	w0, w1
   81af4:	91000421 	add	x1, x1, #0x1
   81af8:	38616862 	ldrb	w2, [x3, x1]
   81afc:	35ffffa2 	cbnz	w2, 81af0 <strlen+0x10>
        ;
    return n;
}
   81b00:	d65f03c0 	ret
    for (n = 0; s[n]; n++)
   81b04:	52800000 	mov	w0, #0x0                   	// #0
}
   81b08:	d65f03c0 	ret
   81b0c:	d503201f 	nop

0000000000081b10 <atoi>:

int atoi(const char *s) {
    int n;
    n = 0;
    while ('0' <= *s && *s <= '9')
   81b10:	39400002 	ldrb	w2, [x0]
int atoi(const char *s) {
   81b14:	aa0003e3 	mov	x3, x0
    while ('0' <= *s && *s <= '9')
   81b18:	5100c040 	sub	w0, w2, #0x30
   81b1c:	12001c00 	and	w0, w0, #0xff
   81b20:	7100241f 	cmp	w0, #0x9
    n = 0;
   81b24:	52800000 	mov	w0, #0x0                   	// #0
    while ('0' <= *s && *s <= '9')
   81b28:	54000148 	b.hi	81b50 <atoi+0x40>  // b.pmore
   81b2c:	d503201f 	nop
        n = n * 10 + *s++ - '0';
   81b30:	0b000800 	add	w0, w0, w0, lsl #2
   81b34:	0b000440 	add	w0, w2, w0, lsl #1
    while ('0' <= *s && *s <= '9')
   81b38:	38401c62 	ldrb	w2, [x3, #1]!
        n = n * 10 + *s++ - '0';
   81b3c:	5100c000 	sub	w0, w0, #0x30
    while ('0' <= *s && *s <= '9')
   81b40:	5100c041 	sub	w1, w2, #0x30
   81b44:	12001c21 	and	w1, w1, #0xff
   81b48:	7100243f 	cmp	w1, #0x9
   81b4c:	54ffff29 	b.ls	81b30 <atoi+0x20>  // b.plast
    return n;
}
   81b50:	d65f03c0 	ret
   81b54:	00000000 	udf	#0

0000000000081b58 <initlock>:

// #define SPINLOCK_DEBUG 1

void initlock(struct spinlock *lk, char *name) {
    lk->name = name;
    lk->locked = 0;
   81b58:	b900001f 	str	wzr, [x0]
    lk->cpu = 0;
   81b5c:	a900fc01 	stp	x1, xzr, [x0, #8]
}
   81b60:	d65f03c0 	ret
   81b64:	d503201f 	nop

0000000000081b68 <holding>:

/* Check whether this cpu is holding the lock.
  Interrupts must be off. */
int holding(struct spinlock *lk) {
    int r;
    r = (lk->locked && lk->cpu == mycpu());
   81b68:	b9400001 	ldr	w1, [x0]
   81b6c:	35000061 	cbnz	w1, 81b78 <holding+0x10>
   81b70:	52800000 	mov	w0, #0x0                   	// #0
    return r;
}
   81b74:	d65f03c0 	ret
int holding(struct spinlock *lk) {
   81b78:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
   81b7c:	910003fd 	mov	x29, sp
   81b80:	f9000bf3 	str	x19, [sp, #16]
    r = (lk->locked && lk->cpu == mycpu());
   81b84:	f9400813 	ldr	x19, [x0, #16]
};
extern struct cpu cpus[NCPU];		// sched.c

// irq must be disabled
extern int cpuid(void); 
static inline struct cpu* mycpu(void) {return &cpus[cpuid()];};
   81b88:	94000b8b 	bl	849b4 <cpuid>
   81b8c:	d0000081 	adrp	x1, 93000 <get_el+0xe61c>
   81b90:	52800302 	mov	w2, #0x18                  	// #24
   81b94:	f9473c21 	ldr	x1, [x1, #3704]
   81b98:	9b220400 	smaddl	x0, w0, w2, x1
   81b9c:	eb00027f 	cmp	x19, x0
   81ba0:	1a9f17e0 	cset	w0, eq  // eq = none
}
   81ba4:	f9400bf3 	ldr	x19, [sp, #16]
   81ba8:	a8c27bfd 	ldp	x29, x30, [sp], #32
   81bac:	d65f03c0 	ret

0000000000081bb0 <push_off>:
  it takes two pop_off()s to undo two push_off()s.  Also, if interrupts
  are initially off, then push_off, pop_off leaves them off.

  "intena" is the irq status (on/off) when noff (i.e. the "balance") is 0. 
  hence, the irq status must be restored when noff reaches 0 again */
void push_off(void) {
   81bb0:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
   81bb4:	910003fd 	mov	x29, sp
   81bb8:	a90153f3 	stp	x19, x20, [sp, #16]
    int old = intr_get();

    // intr_off();
    disable_irq();
    if (mycpu()->noff == 0)
   81bbc:	d0000093 	adrp	x19, 93000 <get_el+0xe61c>
void push_off(void) {
   81bc0:	f90013f5 	str	x21, [sp, #32]
void irq_vector_init( void );    
void enable_irq( void ); 
void disable_irq( void );
int is_irq_masked(void); 
/*return 1 if irq enabled, 0 otherwise*/
static inline int intr_get(void) {return 1-is_irq_masked();}; 
   81bc4:	94000b78 	bl	849a4 <is_irq_masked>
   81bc8:	2a0003f4 	mov	w20, w0
    disable_irq();
   81bcc:	94000b74 	bl	8499c <disable_irq>
   81bd0:	94000b79 	bl	849b4 <cpuid>
    if (mycpu()->noff == 0)
   81bd4:	937f7c01 	sbfiz	x1, x0, #1, #32
   81bd8:	8b20c021 	add	x1, x1, w0, sxtw
   81bdc:	f9473e75 	ldr	x21, [x19, #3704]
   81be0:	d37df021 	lsl	x1, x1, #3
   81be4:	b8616aa0 	ldr	w0, [x21, x1]
   81be8:	340001a0 	cbz	w0, 81c1c <push_off+0x6c>
   81bec:	94000b72 	bl	849b4 <cpuid>
        mycpu()->intena = old;
    mycpu()->noff += 1;
   81bf0:	937f7c01 	sbfiz	x1, x0, #1, #32
   81bf4:	8b20c020 	add	x0, x1, w0, sxtw
   81bf8:	f9473e73 	ldr	x19, [x19, #3704]
   81bfc:	d37df000 	lsl	x0, x0, #3
}
   81c00:	f94013f5 	ldr	x21, [sp, #32]
    mycpu()->noff += 1;
   81c04:	b8606a61 	ldr	w1, [x19, x0]
   81c08:	11000421 	add	w1, w1, #0x1
   81c0c:	b8206a61 	str	w1, [x19, x0]
}
   81c10:	a94153f3 	ldp	x19, x20, [sp, #16]
   81c14:	a8c37bfd 	ldp	x29, x30, [sp], #48
   81c18:	d65f03c0 	ret
   81c1c:	94000b66 	bl	849b4 <cpuid>
   81c20:	52800021 	mov	w1, #0x1                   	// #1
   81c24:	4b140034 	sub	w20, w1, w20
        mycpu()->intena = old;
   81c28:	937f7c01 	sbfiz	x1, x0, #1, #32
   81c2c:	8b20c020 	add	x0, x1, w0, sxtw
   81c30:	8b000eb5 	add	x21, x21, x0, lsl #3
   81c34:	b90006b4 	str	w20, [x21, #4]
   81c38:	17ffffed 	b	81bec <push_off+0x3c>
   81c3c:	d503201f 	nop

0000000000081c40 <acquire>:
void acquire(struct spinlock *lk) {
   81c40:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
   81c44:	910003fd 	mov	x29, sp
   81c48:	a90153f3 	stp	x19, x20, [sp, #16]
   81c4c:	aa0003f3 	mov	x19, x0
    push_off(); // disable interrupts to avoid deadlock.
   81c50:	97ffffd8 	bl	81bb0 <push_off>
    if (!lk || holding(lk)) {
   81c54:	b4000393 	cbz	x19, 81cc4 <acquire+0x84>
    r = (lk->locked && lk->cpu == mycpu());
   81c58:	b9400260 	ldr	w0, [x19]
   81c5c:	d0000094 	adrp	x20, 93000 <get_el+0xe61c>
   81c60:	35000180 	cbnz	w0, 81c90 <acquire+0x50>
    lk->locked = 1;
   81c64:	52800020 	mov	w0, #0x1                   	// #1
   81c68:	b9000260 	str	w0, [x19]
    __sync_synchronize();
   81c6c:	d5033bbf 	dmb	ish
   81c70:	94000b51 	bl	849b4 <cpuid>
   81c74:	f9473e94 	ldr	x20, [x20, #3704]
   81c78:	52800301 	mov	w1, #0x18                  	// #24
   81c7c:	9b215014 	smaddl	x20, w0, w1, x20
    lk->cpu = mycpu();
   81c80:	f9000a74 	str	x20, [x19, #16]
}
   81c84:	a94153f3 	ldp	x19, x20, [sp, #16]
   81c88:	a8c37bfd 	ldp	x29, x30, [sp], #48
   81c8c:	d65f03c0 	ret
int holding(struct spinlock *lk) {
   81c90:	f90013f5 	str	x21, [sp, #32]
    r = (lk->locked && lk->cpu == mycpu());
   81c94:	f9400a75 	ldr	x21, [x19, #16]
   81c98:	94000b47 	bl	849b4 <cpuid>
   81c9c:	f9473e81 	ldr	x1, [x20, #3704]
   81ca0:	52800302 	mov	w2, #0x18                  	// #24
   81ca4:	9b220400 	smaddl	x0, w0, w2, x1
   81ca8:	eb0002bf 	cmp	x21, x0
   81cac:	f94013f5 	ldr	x21, [sp, #32]
   81cb0:	540000c0 	b.eq	81cc8 <acquire+0x88>  // b.none
    while (lk->locked == 1)
   81cb4:	b9400260 	ldr	w0, [x19]
   81cb8:	7100041f 	cmp	w0, #0x1
   81cbc:	54fffd41 	b.ne	81c64 <acquire+0x24>  // b.any
   81cc0:	14000000 	b	81cc0 <acquire+0x80>
   81cc4:	d0000094 	adrp	x20, 93000 <get_el+0xe61c>
        printf("%s ", lk->name);
   81cc8:	f9400661 	ldr	x1, [x19, #8]
   81ccc:	f0000000 	adrp	x0, 84000 <vectors>
   81cd0:	91374000 	add	x0, x0, #0xdd0
   81cd4:	97fffe35 	bl	815a8 <tfp_printf>
        panic("acquire");
   81cd8:	f0000000 	adrp	x0, 84000 <vectors>
   81cdc:	91376000 	add	x0, x0, #0xdd8
   81ce0:	97fffeb6 	bl	817b8 <panic>
    while (lk->locked == 1)
   81ce4:	b9400260 	ldr	w0, [x19]
   81ce8:	7100041f 	cmp	w0, #0x1
   81cec:	54fffea0 	b.eq	81cc0 <acquire+0x80>  // b.none
   81cf0:	17ffffdd 	b	81c64 <acquire+0x24>
   81cf4:	d503201f 	nop

0000000000081cf8 <pop_off>:

/* pop_off must be done with a positive counter (noff)
  i.e. it's a bug if irq is already enabled and then pop_off */
void pop_off(void) {
   81cf8:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
   81cfc:	910003fd 	mov	x29, sp
   81d00:	a90153f3 	stp	x19, x20, [sp, #16]
   81d04:	a9025bf5 	stp	x21, x22, [sp, #32]
   81d08:	94000b2b 	bl	849b4 <cpuid>
   81d0c:	2a0003f3 	mov	w19, w0
   81d10:	94000b25 	bl	849a4 <is_irq_masked>
    struct cpu *c = mycpu();
    if (intr_get())
   81d14:	7100041f 	cmp	w0, #0x1
   81d18:	54000080 	b.eq	81d28 <pop_off+0x30>  // b.none
        panic("pop_off - interruptible");
   81d1c:	f0000000 	adrp	x0, 84000 <vectors>
   81d20:	91378000 	add	x0, x0, #0xde0
   81d24:	97fffea5 	bl	817b8 <panic>
    if (c->noff < 1)
   81d28:	93407e74 	sxtw	x20, w19
   81d2c:	d0000095 	adrp	x21, 93000 <get_el+0xe61c>
   81d30:	8b33c693 	add	x19, x20, w19, sxtw #1
   81d34:	f9473eb6 	ldr	x22, [x21, #3704]
   81d38:	d37df273 	lsl	x19, x19, #3
   81d3c:	b8736ac0 	ldr	w0, [x22, x19]
   81d40:	7100001f 	cmp	w0, #0x0
   81d44:	540001cd 	b.le	81d7c <pop_off+0x84>
        panic("pop_off");
    c->noff -= 1;
   81d48:	8b140694 	add	x20, x20, x20, lsl #1
   81d4c:	51000400 	sub	w0, w0, #0x1
   81d50:	f9473eb5 	ldr	x21, [x21, #3704]
   81d54:	d37df294 	lsl	x20, x20, #3
   81d58:	b8346aa0 	str	w0, [x21, x20]
    if (c->noff == 0 && c->intena)
   81d5c:	35000080 	cbnz	w0, 81d6c <pop_off+0x74>
   81d60:	8b1402b5 	add	x21, x21, x20
   81d64:	b94006a0 	ldr	w0, [x21, #4]
   81d68:	35000140 	cbnz	w0, 81d90 <pop_off+0x98>
        enable_irq();
}
   81d6c:	a94153f3 	ldp	x19, x20, [sp, #16]
   81d70:	a9425bf5 	ldp	x21, x22, [sp, #32]
   81d74:	a8c37bfd 	ldp	x29, x30, [sp], #48
   81d78:	d65f03c0 	ret
        panic("pop_off");
   81d7c:	f0000000 	adrp	x0, 84000 <vectors>
   81d80:	9137e000 	add	x0, x0, #0xdf8
   81d84:	97fffe8d 	bl	817b8 <panic>
   81d88:	b8736ac0 	ldr	w0, [x22, x19]
   81d8c:	17ffffef 	b	81d48 <pop_off+0x50>
}
   81d90:	a94153f3 	ldp	x19, x20, [sp, #16]
   81d94:	a9425bf5 	ldp	x21, x22, [sp, #32]
   81d98:	a8c37bfd 	ldp	x29, x30, [sp], #48
        enable_irq();
   81d9c:	14000afe 	b	84994 <enable_irq>

0000000000081da0 <release>:
void release(struct spinlock *lk) {
   81da0:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
   81da4:	910003fd 	mov	x29, sp
   81da8:	a90153f3 	stp	x19, x20, [sp, #16]
   81dac:	aa0003f3 	mov	x19, x0
    if (!lk || !holding(lk)) {
   81db0:	b4000060 	cbz	x0, 81dbc <release+0x1c>
    r = (lk->locked && lk->cpu == mycpu());
   81db4:	b9400000 	ldr	w0, [x0]
   81db8:	350001c0 	cbnz	w0, 81df0 <release+0x50>
        printf("%s ", lk->name);
   81dbc:	f9400661 	ldr	x1, [x19, #8]
   81dc0:	f0000000 	adrp	x0, 84000 <vectors>
   81dc4:	91374000 	add	x0, x0, #0xdd0
   81dc8:	97fffdf8 	bl	815a8 <tfp_printf>
        panic("release");
   81dcc:	f0000000 	adrp	x0, 84000 <vectors>
   81dd0:	91380000 	add	x0, x0, #0xe00
   81dd4:	97fffe79 	bl	817b8 <panic>
    lk->cpu = 0;
   81dd8:	f9000a7f 	str	xzr, [x19, #16]
    __sync_synchronize();
   81ddc:	d5033bbf 	dmb	ish
    lk->locked = 0;
   81de0:	b900027f 	str	wzr, [x19]
}
   81de4:	a94153f3 	ldp	x19, x20, [sp, #16]
   81de8:	a8c27bfd 	ldp	x29, x30, [sp], #32
    pop_off();
   81dec:	17ffffc3 	b	81cf8 <pop_off>
    r = (lk->locked && lk->cpu == mycpu());
   81df0:	f9400a74 	ldr	x20, [x19, #16]
   81df4:	94000af0 	bl	849b4 <cpuid>
   81df8:	d0000081 	adrp	x1, 93000 <get_el+0xe61c>
   81dfc:	52800302 	mov	w2, #0x18                  	// #24
   81e00:	f9473c21 	ldr	x1, [x1, #3704]
   81e04:	9b220400 	smaddl	x0, w0, w2, x1
   81e08:	eb00029f 	cmp	x20, x0
   81e0c:	54fffd81 	b.ne	81dbc <release+0x1c>  // b.any
   81e10:	17fffff2 	b	81dd8 <release+0x38>
   81e14:	00000000 	udf	#0

0000000000081e18 <adjust_sys_timer>:

// we have added/removed a virt timer, now adjust the phys timer accordingly
// caller must hold timerlock
// return 0 on success
static int adjust_sys_timer(void)
{
   81e18:	a9bb7bfd 	stp	x29, x30, [sp, #-80]!
   81e1c:	910003fd 	mov	x29, sp
   81e20:	a90363f7 	stp	x23, x24, [sp, #48]
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   81e24:	d2860098 	mov	x24, #0x3004                	// #12292
	unsigned long next = (unsigned long)-1; // upcoming firing time, to be determined
   81e28:	92800017 	mov	x23, #0xffffffffffffffff    	// #-1
{
   81e2c:	f90023f9 	str	x25, [sp, #64]
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   81e30:	d2860119 	mov	x25, #0x3008                	// #12296
   81e34:	f2a7e018 	movk	x24, #0x3f00, lsl #16
   81e38:	f2a7e019 	movk	x25, #0x3f00, lsl #16
{
   81e3c:	a90153f3 	stp	x19, x20, [sp, #16]
   81e40:	d0000093 	adrp	x19, 93000 <get_el+0xe61c>
   81e44:	d2800014 	mov	x20, #0x0                   	// #0
   81e48:	913c4273 	add	x19, x19, #0xf10
   81e4c:	a9025bf5 	stp	x21, x22, [sp, #32]
				} else // timer shall not restart
					timers[tt].handler = 0;
			} else 
				// give "next" a bit slack so current_counter() won't exceed
				// "next" before we retuen from this function
				next = timers[tt].elapseat + 10*1000 /*10ms*/;
   81e50:	d284e215 	mov	x21, #0x2710                	// #10000
					timers[tt].elapseat = current_counter() + TICKPERMS * timers[tt].delayms; 
   81e54:	52807d16 	mov	w22, #0x3e8                 	// #1000
   81e58:	1400000a 	b	81e80 <adjust_sys_timer+0x68>
				if ((*timers[tt].handler)(tt, timers[tt].param, timers[tt].context) == 1) { 
   81e5c:	a9418a61 	ldp	x1, x2, [x19, #24]
   81e60:	d63f0060 	blr	x3
   81e64:	7100041f 	cmp	w0, #0x1
   81e68:	54000500 	b.eq	81f08 <adjust_sys_timer+0xf0>  // b.none
					timers[tt].handler = 0;
   81e6c:	f900027f 	str	xzr, [x19]
	for (int tt = 0; tt < N_TIMERS; tt++) {
   81e70:	91000694 	add	x20, x20, #0x1
   81e74:	9100a273 	add	x19, x19, #0x28
   81e78:	f100529f 	cmp	x20, #0x14
   81e7c:	54000240 	b.eq	81ec4 <adjust_sys_timer+0xac>  // b.none
		if (!timers[tt].handler)
   81e80:	f9400263 	ldr	x3, [x19]
   81e84:	b4ffff63 	cbz	x3, 81e70 <adjust_sys_timer+0x58>
		if (timers[tt].elapseat < next) {
   81e88:	f9400661 	ldr	x1, [x19, #8]
   81e8c:	eb17003f 	cmp	x1, x23
   81e90:	54ffff02 	b.cs	81e70 <adjust_sys_timer+0x58>  // b.hs, b.nlast
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   81e94:	b9400322 	ldr	w2, [x25]
				if ((*timers[tt].handler)(tt, timers[tt].param, timers[tt].context) == 1) { 
   81e98:	aa1403e0 	mov	x0, x20
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   81e9c:	b9400304 	ldr	w4, [x24]
   81ea0:	2a0403e4 	mov	w4, w4
   81ea4:	aa028082 	orr	x2, x4, x2, lsl #32
			if (timers[tt].elapseat < current_counter()) {
   81ea8:	eb02003f 	cmp	x1, x2
   81eac:	54fffd83 	b.cc	81e5c <adjust_sys_timer+0x44>  // b.lo, b.ul, b.last
   81eb0:	91000694 	add	x20, x20, #0x1
				next = timers[tt].elapseat + 10*1000 /*10ms*/;
   81eb4:	8b150037 	add	x23, x1, x21
	for (int tt = 0; tt < N_TIMERS; tt++) {
   81eb8:	9100a273 	add	x19, x19, #0x28
   81ebc:	f100529f 	cmp	x20, #0x14
   81ec0:	54fffe01 	b.ne	81e80 <adjust_sys_timer+0x68>  // b.any
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   81ec4:	d2860100 	mov	x0, #0x3008                	// #12296
   81ec8:	d2860081 	mov	x1, #0x3004                	// #12292
   81ecc:	f2a7e000 	movk	x0, #0x3f00, lsl #16
   81ed0:	f2a7e001 	movk	x1, #0x3f00, lsl #16
   81ed4:	b9400000 	ldr	w0, [x0]
   81ed8:	b9400021 	ldr	w1, [x1]
   81edc:	2a0103e1 	mov	w1, w1
   81ee0:	aa008020 	orr	x0, x1, x0, lsl #32
		}
	}

	// a known bug (TBD. may occur: when qemu is very slow, or on actual hw
	// timer expired, but handler not called?? should we handle it?
	BUG_ON(current_counter() > next); 
   81ee4:	eb0002ff 	cmp	x23, x0
   81ee8:	54000223 	b.cc	81f2c <adjust_sys_timer+0x114>  // b.lo, b.ul, b.last
	// the counter. this is ok even if the low 32 bits have to wrap around 
	// in order to match TIMER_C1 (cf the isr)	
	/* Q11 STUDENT_TODO: your code here */

	return 0; 
}
   81eec:	52800000 	mov	w0, #0x0                   	// #0
   81ef0:	a94153f3 	ldp	x19, x20, [sp, #16]
   81ef4:	a9425bf5 	ldp	x21, x22, [sp, #32]
   81ef8:	a94363f7 	ldp	x23, x24, [sp, #48]
   81efc:	f94023f9 	ldr	x25, [sp, #64]
   81f00:	a8c57bfd 	ldp	x29, x30, [sp], #80
   81f04:	d65f03c0 	ret
					timers[tt].elapseat = current_counter() + TICKPERMS * timers[tt].delayms; 
   81f08:	b9401260 	ldr	w0, [x19, #16]
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   81f0c:	b9400321 	ldr	w1, [x25]
   81f10:	b9400302 	ldr	w2, [x24]
					timers[tt].elapseat = current_counter() + TICKPERMS * timers[tt].delayms; 
   81f14:	1b167c00 	mul	w0, w0, w22
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   81f18:	2a0203e2 	mov	w2, w2
   81f1c:	aa018041 	orr	x1, x2, x1, lsl #32
					timers[tt].elapseat = current_counter() + TICKPERMS * timers[tt].delayms; 
   81f20:	8b204020 	add	x0, x1, w0, uxtw
   81f24:	f9000660 	str	x0, [x19, #8]
   81f28:	17ffffd2 	b	81e70 <adjust_sys_timer+0x58>
	BUG_ON(current_counter() > next); 
   81f2c:	52801b22 	mov	w2, #0xd9                  	// #217
   81f30:	f0000001 	adrp	x1, 84000 <vectors>
   81f34:	f0000000 	adrp	x0, 84000 <vectors>
   81f38:	91382021 	add	x1, x1, #0xe08
   81f3c:	91384000 	add	x0, x0, #0xe10
   81f40:	97fffe68 	bl	818e0 <assertion_failed>
}
   81f44:	52800000 	mov	w0, #0x0                   	// #0
   81f48:	a94153f3 	ldp	x19, x20, [sp, #16]
   81f4c:	a9425bf5 	ldp	x21, x22, [sp, #32]
   81f50:	a94363f7 	ldp	x23, x24, [sp, #48]
   81f54:	f94023f9 	ldr	x25, [sp, #64]
   81f58:	a8c57bfd 	ldp	x29, x30, [sp], #80
   81f5c:	d65f03c0 	ret

0000000000081f60 <generic_timer_init>:
	asm volatile("msr CNTP_CTL_EL0, %0" : : "r"(1));
   81f60:	52800020 	mov	w0, #0x1                   	// #1
   81f64:	d51be220 	msr	cntp_ctl_el0, x0
	generic_timer_reset(interval);	// kickoff 1st time firing
   81f68:	d0000080 	adrp	x0, 93000 <get_el+0xe61c>
	asm volatile("msr CNTP_TVAL_EL0, %0" : : "r"(intv));  // TVAL is 32bit, signed
   81f6c:	b9453000 	ldr	w0, [x0, #1328]
   81f70:	d51be200 	msr	cntp_tval_el0, x0
}
   81f74:	d65f03c0 	ret

0000000000081f78 <handle_generic_timer_irq>:
	generic_timer_reset(interval);
   81f78:	d0000080 	adrp	x0, 93000 <get_el+0xe61c>
	asm volatile("msr CNTP_TVAL_EL0, %0" : : "r"(intv));  // TVAL is 32bit, signed
   81f7c:	b9453000 	ldr	w0, [x0, #1328]
   81f80:	d51be200 	msr	cntp_tval_el0, x0
}
   81f84:	d65f03c0 	ret

0000000000081f88 <current_counter>:
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   81f88:	d2860101 	mov	x1, #0x3008                	// #12296
   81f8c:	d2860080 	mov	x0, #0x3004                	// #12292
   81f90:	f2a7e001 	movk	x1, #0x3f00, lsl #16
   81f94:	f2a7e000 	movk	x0, #0x3f00, lsl #16
   81f98:	b9400021 	ldr	w1, [x1]
   81f9c:	b9400000 	ldr	w0, [x0]
   81fa0:	2a0003e0 	mov	w0, w0
}
   81fa4:	aa018000 	orr	x0, x0, x1, lsl #32
   81fa8:	d65f03c0 	ret
   81fac:	d503201f 	nop

0000000000081fb0 <ms_delay>:
	delay(cycles_per_ms * ms);
   81fb0:	52944bc1 	mov	w1, #0xa25e                	// #41566
void ms_delay(unsigned ms) {
   81fb4:	d10043ff 	sub	sp, sp, #0x10
	delay(cycles_per_ms * ms);
   81fb8:	72a000c1 	movk	w1, #0x6, lsl #16
   81fbc:	1b017c00 	mul	w0, w0, w1
	volatile unsigned long c = cycles; 
   81fc0:	f90007e0 	str	x0, [sp, #8]
	while (c!=0) c--; 
   81fc4:	f94007e0 	ldr	x0, [sp, #8]
   81fc8:	b40000e0 	cbz	x0, 81fe4 <ms_delay+0x34>
   81fcc:	d503201f 	nop
   81fd0:	f94007e0 	ldr	x0, [sp, #8]
   81fd4:	d1000400 	sub	x0, x0, #0x1
   81fd8:	f90007e0 	str	x0, [sp, #8]
   81fdc:	f94007e0 	ldr	x0, [sp, #8]
   81fe0:	b5ffff80 	cbnz	x0, 81fd0 <ms_delay+0x20>
}
   81fe4:	910043ff 	add	sp, sp, #0x10
   81fe8:	d65f03c0 	ret
   81fec:	d503201f 	nop

0000000000081ff0 <us_delay>:
void us_delay(unsigned us) {
   81ff0:	d10043ff 	sub	sp, sp, #0x10
	delay(cycles_per_us * us);
   81ff4:	52803641 	mov	w1, #0x1b2                 	// #434
   81ff8:	1b017c00 	mul	w0, w0, w1
	volatile unsigned long c = cycles; 
   81ffc:	f90007e0 	str	x0, [sp, #8]
	while (c!=0) c--; 
   82000:	f94007e0 	ldr	x0, [sp, #8]
   82004:	b40000c0 	cbz	x0, 8201c <us_delay+0x2c>
   82008:	f94007e0 	ldr	x0, [sp, #8]
   8200c:	d1000400 	sub	x0, x0, #0x1
   82010:	f90007e0 	str	x0, [sp, #8]
   82014:	f94007e0 	ldr	x0, [sp, #8]
   82018:	b5ffff80 	cbnz	x0, 82008 <us_delay+0x18>
}
   8201c:	910043ff 	add	sp, sp, #0x10
   82020:	d65f03c0 	ret
   82024:	d503201f 	nop

0000000000082028 <current_time>:
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82028:	d2860102 	mov	x2, #0x3008                	// #12296
   8202c:	d2860085 	mov	x5, #0x3004                	// #12292
   82030:	f2a7e002 	movk	x2, #0x3f00, lsl #16
   82034:	f2a7e005 	movk	x5, #0x3f00, lsl #16
	*sec =  (unsigned) (cur / TICKPERSEC); 
   82038:	d2869b63 	mov	x3, #0x34db                	// #13531
	cur -= (*sec) * TICKPERSEC; 
   8203c:	52884804 	mov	w4, #0x4240                	// #16960
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82040:	b9400042 	ldr	w2, [x2]
	*sec =  (unsigned) (cur / TICKPERSEC); 
   82044:	f2baf6c3 	movk	x3, #0xd7b6, lsl #16
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82048:	b94000a5 	ldr	w5, [x5]
	*sec =  (unsigned) (cur / TICKPERSEC); 
   8204c:	f2dbd043 	movk	x3, #0xde82, lsl #32
   82050:	f2e86363 	movk	x3, #0x431b, lsl #48
	cur -= (*sec) * TICKPERSEC; 
   82054:	72a001e4 	movk	w4, #0xf, lsl #16
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82058:	2a0503e5 	mov	w5, w5
	*msec = (unsigned) (cur / TICKPERMS);
   8205c:	d29ef9e6 	mov	x6, #0xf7cf                	// #63439
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82060:	aa0280a2 	orr	x2, x5, x2, lsl #32
	*msec = (unsigned) (cur / TICKPERMS);
   82064:	f2bc6a66 	movk	x6, #0xe353, lsl #16
   82068:	f2d374a6 	movk	x6, #0x9ba5, lsl #32
   8206c:	f2e41886 	movk	x6, #0x20c4, lsl #48
	*sec =  (unsigned) (cur / TICKPERSEC); 
   82070:	9bc37c43 	umulh	x3, x2, x3
   82074:	d352fc63 	lsr	x3, x3, #18
   82078:	b9000003 	str	w3, [x0]
	cur -= (*sec) * TICKPERSEC; 
   8207c:	1b037c83 	mul	w3, w4, w3
   82080:	cb234042 	sub	x2, x2, w3, uxtw
	*msec = (unsigned) (cur / TICKPERMS);
   82084:	d343fc42 	lsr	x2, x2, #3
   82088:	9bc67c42 	umulh	x2, x2, x6
   8208c:	d344fc42 	lsr	x2, x2, #4
   82090:	b9000022 	str	w2, [x1]
}
   82094:	d65f03c0 	ret

0000000000082098 <delay>:
void delay(unsigned long cycles) {
   82098:	d10043ff 	sub	sp, sp, #0x10
	volatile unsigned long c = cycles; 
   8209c:	f90007e0 	str	x0, [sp, #8]
	while (c!=0) c--; 
   820a0:	f94007e0 	ldr	x0, [sp, #8]
   820a4:	b40000c0 	cbz	x0, 820bc <delay+0x24>
   820a8:	f94007e0 	ldr	x0, [sp, #8]
   820ac:	d1000400 	sub	x0, x0, #0x1
   820b0:	f90007e0 	str	x0, [sp, #8]
   820b4:	f94007e0 	ldr	x0, [sp, #8]
   820b8:	b5ffff80 	cbnz	x0, 820a8 <delay+0x10>
}
   820bc:	910043ff 	add	sp, sp, #0x10
   820c0:	d65f03c0 	ret
   820c4:	d503201f 	nop

00000000000820c8 <sys_timer_init>:
{
   820c8:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
	initlock(&timerlock, "timer"); 
   820cc:	b0000080 	adrp	x0, 93000 <get_el+0xe61c>
   820d0:	d0000001 	adrp	x1, 84000 <vectors>
{
   820d4:	910003fd 	mov	x29, sp
	initlock(&timerlock, "timer"); 
   820d8:	f9473800 	ldr	x0, [x0, #3696]
   820dc:	9138c021 	add	x1, x1, #0xe30
   820e0:	97fffe9e 	bl	81b58 <initlock>
}
   820e4:	a8c17bfd 	ldp	x29, x30, [sp], #16
	memzero(timers, sizeof(timers)); 	// all field zeros	
   820e8:	b0000080 	adrp	x0, 93000 <get_el+0xe61c>
   820ec:	52806401 	mov	w1, #0x320                 	// #800
   820f0:	913c4000 	add	x0, x0, #0xf10
   820f4:	17fffe11 	b	81938 <memzero>

00000000000820f8 <ktimer_start>:

// see above
// cannot be called from TKernelTimerHandler, which will have timerlock held
// thus, deadlock 
int ktimer_start(unsigned delayms, TKernelTimerHandler *handler, 
		void *para, void *context) {
   820f8:	a9ba7bfd 	stp	x29, x30, [sp, #-96]!
   820fc:	910003fd 	mov	x29, sp
   82100:	a90363f7 	stp	x23, x24, [sp, #48]
	int ret;
	acquire(&timerlock); 
   82104:	b0000097 	adrp	x23, 93000 <get_el+0xe61c>
   82108:	b0000098 	adrp	x24, 93000 <get_el+0xe61c>
		void *para, void *context) {
   8210c:	f90023f9 	str	x25, [sp, #64]
   82110:	2a0003f9 	mov	w25, w0
	acquire(&timerlock); 
   82114:	f9473ae0 	ldr	x0, [x23, #3696]
		void *para, void *context) {
   82118:	a90153f3 	stp	x19, x20, [sp, #16]
   8211c:	aa0103f4 	mov	x20, x1
   82120:	a9025bf5 	stp	x21, x22, [sp, #32]
   82124:	aa0203f5 	mov	x21, x2
   82128:	aa0303f6 	mov	x22, x3
	acquire(&timerlock); 
   8212c:	97fffec5 	bl	81c40 <acquire>
	for (t = 0; t < N_TIMERS; t++) {
   82130:	52800013 	mov	w19, #0x0                   	// #0
   82134:	913c4300 	add	x0, x24, #0xf10
   82138:	14000004 	b	82148 <ktimer_start+0x50>
   8213c:	11000673 	add	w19, w19, #0x1
   82140:	7100527f 	cmp	w19, #0x14
   82144:	54000460 	b.eq	821d0 <ktimer_start+0xd8>  // b.none
		if (timers[t].handler == 0) 
   82148:	f9400001 	ldr	x1, [x0]
   8214c:	9100a000 	add	x0, x0, #0x28
   82150:	b5ffff61 	cbnz	x1, 8213c <ktimer_start+0x44>
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82154:	d2860101 	mov	x1, #0x3008                	// #12296
   82158:	d2860080 	mov	x0, #0x3004                	// #12292
   8215c:	f2a7e001 	movk	x1, #0x3f00, lsl #16
   82160:	f2a7e000 	movk	x0, #0x3f00, lsl #16
	BUG_ON(cur + TICKPERMS * delayms < cur); // 64bit counter wraps around??
   82164:	52807d04 	mov	w4, #0x3e8                 	// #1000
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82168:	b9400025 	ldr	w5, [x1]
   8216c:	b9400000 	ldr	w0, [x0]
	BUG_ON(cur + TICKPERMS * delayms < cur); // 64bit counter wraps around??
   82170:	1b047f26 	mul	w6, w25, w4
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82174:	2a0003e0 	mov	w0, w0
   82178:	aa058004 	orr	x4, x0, x5, lsl #32
   8217c:	ab060084 	adds	x4, x4, x6
   82180:	54000382 	b.cs	821f0 <ktimer_start+0xf8>  // b.hs, b.nlast
	timers[t].handler = handler; 
   82184:	d37e7e61 	ubfiz	x1, x19, #2, #32
   82188:	913c4318 	add	x24, x24, #0xf10
   8218c:	8b334021 	add	x1, x1, w19, uxtw
   82190:	d37df021 	lsl	x1, x1, #3
	timers[t].param = para; 
   82194:	8b010300 	add	x0, x24, x1
	timers[t].handler = handler; 
   82198:	f8216b14 	str	x20, [x24, x1]
	timers[t].elapseat = cur + TICKPERMS * delayms; 
   8219c:	f9000404 	str	x4, [x0, #8]
	timers[t].delayms = delayms; 
   821a0:	b9001019 	str	w25, [x0, #16]
	timers[t].context = context; 
   821a4:	a901d815 	stp	x21, x22, [x0, #24]
	adjust_sys_timer(); 
   821a8:	97ffff1c 	bl	81e18 <adjust_sys_timer>
	ret = ktimer_start_nolock(delayms, handler, para, context); 
	release(&timerlock); 
   821ac:	f9473ae0 	ldr	x0, [x23, #3696]
   821b0:	97fffefc 	bl	81da0 <release>
	return ret;
}
   821b4:	2a1303e0 	mov	w0, w19
   821b8:	a94153f3 	ldp	x19, x20, [sp, #16]
   821bc:	a9425bf5 	ldp	x21, x22, [sp, #32]
   821c0:	a94363f7 	ldp	x23, x24, [sp, #48]
   821c4:	f94023f9 	ldr	x25, [sp, #64]
   821c8:	a8c67bfd 	ldp	x29, x30, [sp], #96
   821cc:	d65f03c0 	ret
		E("ktimer_start failed. # max timer reached"); 
   821d0:	d0000001 	adrp	x1, 84000 <vectors>
   821d4:	d0000000 	adrp	x0, 84000 <vectors>
   821d8:	91382021 	add	x1, x1, #0xe08
   821dc:	9139a000 	add	x0, x0, #0xe68
   821e0:	52801f22 	mov	w2, #0xf9                  	// #249
		return -1; 
   821e4:	12800013 	mov	w19, #0xffffffff            	// #-1
		E("ktimer_start failed. # max timer reached"); 
   821e8:	97fffcf0 	bl	815a8 <tfp_printf>
		return -1; 
   821ec:	17fffff0 	b	821ac <ktimer_start+0xb4>
	BUG_ON(cur + TICKPERMS * delayms < cur); // 64bit counter wraps around??
   821f0:	d0000001 	adrp	x1, 84000 <vectors>
   821f4:	d0000000 	adrp	x0, 84000 <vectors>
   821f8:	91382021 	add	x1, x1, #0xe08
   821fc:	9138e000 	add	x0, x0, #0xe38
   82200:	52801fc2 	mov	w2, #0xfe                  	// #254
   82204:	f9002fe4 	str	x4, [sp, #88]
   82208:	97fffdb6 	bl	818e0 <assertion_failed>
   8220c:	f9402fe4 	ldr	x4, [sp, #88]
   82210:	17ffffdd 	b	82184 <ktimer_start+0x8c>
   82214:	d503201f 	nop

0000000000082218 <ktimer_cancel>:
// return 0 on okay, -1 if no such timer/handler, 
//	-2 if already fired (will clean anyway)
int ktimer_cancel(int t) {
	unsigned long cur; 

	if (t < 0 || t >= N_TIMERS)
   82218:	71004c1f 	cmp	w0, #0x13
   8221c:	540004c8 	b.hi	822b4 <ktimer_cancel+0x9c>  // b.pmore
int ktimer_cancel(int t) {
   82220:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82224:	d2860101 	mov	x1, #0x3008                	// #12296
   82228:	f2a7e001 	movk	x1, #0x3f00, lsl #16
int ktimer_cancel(int t) {
   8222c:	910003fd 	mov	x29, sp
   82230:	a90153f3 	stp	x19, x20, [sp, #16]
   82234:	2a0003f3 	mov	w19, w0
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82238:	d2860080 	mov	x0, #0x3004                	// #12292
   8223c:	f2a7e000 	movk	x0, #0x3f00, lsl #16
   82240:	b9400022 	ldr	w2, [x1]
		return -1; 

	cur = current_counter();
	acquire(&timerlock); 
   82244:	b0000094 	adrp	x20, 93000 <get_el+0xe61c>
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82248:	b9400001 	ldr	w1, [x0]
	acquire(&timerlock); 
   8224c:	f9473a94 	ldr	x20, [x20, #3696]
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82250:	2a0103e1 	mov	w1, w1
int ktimer_cancel(int t) {
   82254:	f90013f5 	str	x21, [sp, #32]
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82258:	aa028035 	orr	x21, x1, x2, lsl #32
	acquire(&timerlock); 
   8225c:	aa1403e0 	mov	x0, x20
   82260:	97fffe78 	bl	81c40 <acquire>

	if (!timers[t].handler) {	// invalid handler
   82264:	937e7e60 	sbfiz	x0, x19, #2, #32
   82268:	b0000081 	adrp	x1, 93000 <get_el+0xe61c>
   8226c:	8b33c013 	add	x19, x0, w19, sxtw
   82270:	913c4021 	add	x1, x1, #0xf10
   82274:	d37df273 	lsl	x19, x19, #3
   82278:	f8736820 	ldr	x0, [x1, x19]
   8227c:	b40002c0 	cbz	x0, 822d4 <ktimer_cancel+0xbc>
		release(&timerlock); 
		return -1; 
	}

	if (timers[t].elapseat < cur) { // already fired? 
   82280:	8b130022 	add	x2, x1, x19
   82284:	f9400440 	ldr	x0, [x2, #8]
   82288:	eb15001f 	cmp	x0, x21
   8228c:	54000183 	b.cc	822bc <ktimer_cancel+0xa4>  // b.lo, b.ul, b.last
		timers[t].param = 0; 
		release(&timerlock); 
		return -2; 
	}

	timers[t].handler = 0; 
   82290:	f833683f 	str	xzr, [x1, x19]
	// timers[t].context = 0; 
	// timers[t].param = 0; 
	// timers[t].elapseat = 0; 

	adjust_sys_timer(); 	
   82294:	97fffee1 	bl	81e18 <adjust_sys_timer>
	release(&timerlock);
   82298:	aa1403e0 	mov	x0, x20
   8229c:	97fffec1 	bl	81da0 <release>

	return 0;  
   822a0:	52800000 	mov	w0, #0x0                   	// #0
}
   822a4:	a94153f3 	ldp	x19, x20, [sp, #16]
   822a8:	f94013f5 	ldr	x21, [sp, #32]
   822ac:	a8c37bfd 	ldp	x29, x30, [sp], #48
   822b0:	d65f03c0 	ret
		return -1; 
   822b4:	12800000 	mov	w0, #0xffffffff            	// #-1
}
   822b8:	d65f03c0 	ret
		timers[t].handler = 0; 
   822bc:	f833683f 	str	xzr, [x1, x19]
		release(&timerlock); 
   822c0:	aa1403e0 	mov	x0, x20
		timers[t].context = 0; 
   822c4:	a901fc5f 	stp	xzr, xzr, [x2, #24]
		release(&timerlock); 
   822c8:	97fffeb6 	bl	81da0 <release>
		return -2; 
   822cc:	12800020 	mov	w0, #0xfffffffe            	// #-2
   822d0:	17fffff5 	b	822a4 <ktimer_cancel+0x8c>
		release(&timerlock); 
   822d4:	aa1403e0 	mov	x0, x20
   822d8:	97fffeb2 	bl	81da0 <release>
		return -1; 
   822dc:	12800000 	mov	w0, #0xffffffff            	// #-1
   822e0:	17fffff1 	b	822a4 <ktimer_cancel+0x8c>
   822e4:	d503201f 	nop

00000000000822e8 <sys_timer_irq>:
void sys_timer_irq(void) 
{
	V("called");	

	// timer1 must have pending match. below could happen under high load. why?
	BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   822e8:	d2860000 	mov	x0, #0x3000                	// #12288
{
   822ec:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
	BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   822f0:	f2a7e000 	movk	x0, #0x3f00, lsl #16
{
   822f4:	910003fd 	mov	x29, sp
	BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   822f8:	b9400000 	ldr	w0, [x0]
{
   822fc:	a90153f3 	stp	x19, x20, [sp, #16]
	BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   82300:	36080440 	tbz	w0, #1, 82388 <sys_timer_irq+0xa0>
	put32(TIMER_CS, TIMER_CS_M1);	// clear timer1 match
   82304:	d2860000 	mov	x0, #0x3000                	// #12288
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82308:	d2860102 	mov	x2, #0x3008                	// #12296
	put32(TIMER_CS, TIMER_CS_M1);	// clear timer1 match
   8230c:	f2a7e000 	movk	x0, #0x3f00, lsl #16
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82310:	d2860081 	mov	x1, #0x3004                	// #12292
   82314:	f2a7e002 	movk	x2, #0x3f00, lsl #16
	put32(TIMER_CS, TIMER_CS_M1);	// clear timer1 match
   82318:	52800043 	mov	w3, #0x2                   	// #2
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   8231c:	f2a7e001 	movk	x1, #0x3f00, lsl #16
	put32(TIMER_CS, TIMER_CS_M1);	// clear timer1 match
   82320:	b9000003 	str	w3, [x0]

	unsigned long cur = current_counter(); 
	int ret; 

	acquire(&timerlock); 
   82324:	b0000094 	adrp	x20, 93000 <get_el+0xe61c>
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82328:	b9400053 	ldr	w19, [x2]
   8232c:	b9400021 	ldr	w1, [x1]
	acquire(&timerlock); 
   82330:	f9473a80 	ldr	x0, [x20, #3696]
	return ((unsigned long) get32(TIMER_CHI) << 32) | get32(TIMER_CLO);
   82334:	2a0103e1 	mov	w1, w1
   82338:	aa138033 	orr	x19, x1, x19, lsl #32
	acquire(&timerlock); 
   8233c:	97fffe41 	bl	81c40 <acquire>
	for (int t = 0; t < N_TIMERS; t++) {
   82340:	b0000080 	adrp	x0, 93000 <get_el+0xe61c>
   82344:	913c4000 	add	x0, x0, #0xf10
   82348:	910c8002 	add	x2, x0, #0x320
   8234c:	d503201f 	nop
		TKernelTimerHandler *h = timers[t].handler; 
		if (h == 0) 
   82350:	f9400001 	ldr	x1, [x0]
   82354:	b40000a1 	cbz	x1, 82368 <sys_timer_irq+0x80>
			continue; 
		if (timers[t].elapseat <= cur) { // should fire  
   82358:	f9400401 	ldr	x1, [x0, #8]
   8235c:	eb13003f 	cmp	x1, x19
   82360:	54000048 	b.hi	82368 <sys_timer_irq+0x80>  // b.pmore
ret = 0; /* STUDENT_TODO: replace this */
			if (ret==1) { // restart the ktimer in place
timers[t].elapseat = 0; /* STUDENT_TODO: replace this */
				adjust_sys_timer(); 
			} else 
				timers[t].handler = 0; 
   82364:	f900001f 	str	xzr, [x0]
   82368:	9100a000 	add	x0, x0, #0x28
	for (int t = 0; t < N_TIMERS; t++) {
   8236c:	eb02001f 	cmp	x0, x2
   82370:	54ffff01 	b.ne	82350 <sys_timer_irq+0x68>  // b.any
		}		
	}
	adjust_sys_timer(); 
   82374:	97fffea9 	bl	81e18 <adjust_sys_timer>
	release(&timerlock);
   82378:	f9473a80 	ldr	x0, [x20, #3696]
}
   8237c:	a94153f3 	ldp	x19, x20, [sp, #16]
   82380:	a8c27bfd 	ldp	x29, x30, [sp], #32
	release(&timerlock);
   82384:	17fffe87 	b	81da0 <release>
	BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   82388:	d0000001 	adrp	x1, 84000 <vectors>
   8238c:	d0000000 	adrp	x0, 84000 <vectors>
   82390:	91382021 	add	x1, x1, #0xe08
   82394:	913aa000 	add	x0, x0, #0xea8
   82398:	52802822 	mov	w2, #0x141                 	// #321
   8239c:	97fffd51 	bl	818e0 <assertion_failed>
   823a0:	17ffffd9 	b	82304 <sys_timer_irq+0x1c>
   823a4:	00000000 	udf	#0

00000000000823a8 <mbox_call>:
 * Spin wait for mailbox hardware.
 * Returns 0 on failure, non-zero on success.
 *
 * Caller must hold mboxlock.
 */
int mbox_call(unsigned char ch) {
   823a8:	a9bb7bfd 	stp	x29, x30, [sp, #-80]!
    // the buf addr (pa) w/ ch (chan id) in LSB 
    unsigned int r = (((unsigned int)((unsigned long)&mbox) & ~0xF) | (ch & 0xF));
    r = BUS_ADDRESS(r); 
    /* wait until we can write to the mailbox */
    do { asm volatile("nop"); } while (*MBOX_STATUS & MBOX_FULL);
   823ac:	d2971301 	mov	x1, #0xb898                	// #47256
   823b0:	f2a7e001 	movk	x1, #0x3f00, lsl #16
int mbox_call(unsigned char ch) {
   823b4:	910003fd 	mov	x29, sp
   823b8:	a90363f7 	stp	x23, x24, [sp, #48]
    unsigned int r = (((unsigned int)((unsigned long)&mbox) & ~0xF) | (ch & 0xF));
   823bc:	b0000098 	adrp	x24, 93000 <get_el+0xe61c>
int mbox_call(unsigned char ch) {
   823c0:	a90153f3 	stp	x19, x20, [sp, #16]
    unsigned int r = (((unsigned int)((unsigned long)&mbox) & ~0xF) | (ch & 0xF));
   823c4:	12000c14 	and	w20, w0, #0xf
   823c8:	f9473700 	ldr	x0, [x24, #3688]
int mbox_call(unsigned char ch) {
   823cc:	a9025bf5 	stp	x21, x22, [sp, #32]
    unsigned int r = (((unsigned int)((unsigned long)&mbox) & ~0xF) | (ch & 0xF));
   823d0:	2a000294 	orr	w20, w20, w0
int mbox_call(unsigned char ch) {
   823d4:	f90023f9 	str	x25, [sp, #64]
    r = BUS_ADDRESS(r); 
   823d8:	32020694 	orr	w20, w20, #0xc0000000
   823dc:	d503201f 	nop
    do { asm volatile("nop"); } while (*MBOX_STATUS & MBOX_FULL);
   823e0:	d503201f 	nop
   823e4:	b9400020 	ldr	w0, [x1]
   823e8:	37ffffc0 	tbnz	w0, #31, 823e0 <mbox_call+0x38>
    __asm__ volatile ("dmb sy" ::: "memory");    // mem barrier, ensuring msg in mem
   823ec:	d5033fbf 	dmb	sy

    /* write the address of our message to the mailbox with channel identifier */
    *MBOX_WRITE = r; 
   823f0:	d2971400 	mov	x0, #0xb8a0                	// #47264
   823f4:	d0000019 	adrp	x25, 84000 <vectors>
   823f8:	f2a7e000 	movk	x0, #0x3f00, lsl #16
            V("r is 0x%x", r); 
            /* is it a valid successful response? (strange it's benign) */
            if (mbox[1] != MBOX_RESPONSE) I("mbox[1] is %08x", mbox[1]);            
            return mbox[1] == MBOX_RESPONSE;
        } else {
            W("got an irrelevant msg. bug?"); 
   823fc:	d0000015 	adrp	x21, 84000 <vectors>
        do { asm volatile("nop"); } while (*MBOX_STATUS & MBOX_EMPTY);
   82400:	d2971313 	mov	x19, #0xb898                	// #47256
        if (r == *MBOX_READ) {
   82404:	d2971016 	mov	x22, #0xb880                	// #47232
            W("got an irrelevant msg. bug?"); 
   82408:	913be337 	add	x23, x25, #0xef8
   8240c:	913d02b5 	add	x21, x21, #0xf40
        do { asm volatile("nop"); } while (*MBOX_STATUS & MBOX_EMPTY);
   82410:	f2a7e013 	movk	x19, #0x3f00, lsl #16
        if (r == *MBOX_READ) {
   82414:	f2a7e016 	movk	x22, #0x3f00, lsl #16
    *MBOX_WRITE = r; 
   82418:	b9000014 	str	w20, [x0]
   8241c:	d503201f 	nop
        do { asm volatile("nop"); } while (*MBOX_STATUS & MBOX_EMPTY);
   82420:	d503201f 	nop
   82424:	b9400260 	ldr	w0, [x19]
   82428:	37f7ffc0 	tbnz	w0, #30, 82420 <mbox_call+0x78>
        if (r == *MBOX_READ) {
   8242c:	b94002c3 	ldr	w3, [x22]
            W("got an irrelevant msg. bug?"); 
   82430:	aa1703e1 	mov	x1, x23
   82434:	aa1503e0 	mov	x0, x21
   82438:	52800862 	mov	w2, #0x43                  	// #67
        if (r == *MBOX_READ) {
   8243c:	6b14007f 	cmp	w3, w20
   82440:	54000060 	b.eq	8244c <mbox_call+0xa4>  // b.none
            W("got an irrelevant msg. bug?"); 
   82444:	97fffc59 	bl	815a8 <tfp_printf>
    while (1) {
   82448:	17fffff6 	b	82420 <mbox_call+0x78>
            V("r is 0x%x", r); 
   8244c:	913be339 	add	x25, x25, #0xef8
   82450:	528007c2 	mov	w2, #0x3e                  	// #62
   82454:	aa1903e1 	mov	x1, x25
   82458:	2a1403e3 	mov	w3, w20
   8245c:	d0000000 	adrp	x0, 84000 <vectors>
   82460:	913c0000 	add	x0, x0, #0xf00
   82464:	97fffc51 	bl	815a8 <tfp_printf>
            if (mbox[1] != MBOX_RESPONSE) I("mbox[1] is %08x", mbox[1]);            
   82468:	f9473700 	ldr	x0, [x24, #3688]
   8246c:	52b00001 	mov	w1, #0x80000000            	// #-2147483648
   82470:	b9400402 	ldr	w2, [x0, #4]
   82474:	6b01005f 	cmp	w2, w1
   82478:	540000e0 	b.eq	82494 <mbox_call+0xec>  // b.none
   8247c:	b9400403 	ldr	w3, [x0, #4]
   82480:	aa1903e1 	mov	x1, x25
   82484:	d0000000 	adrp	x0, 84000 <vectors>
   82488:	52800802 	mov	w2, #0x40                  	// #64
   8248c:	913c6000 	add	x0, x0, #0xf18
   82490:	97fffc46 	bl	815a8 <tfp_printf>
            return mbox[1] == MBOX_RESPONSE;
   82494:	f9473718 	ldr	x24, [x24, #3688]
   82498:	52b00000 	mov	w0, #0x80000000            	// #-2147483648
        }
    }
    return 0;
}
   8249c:	a94153f3 	ldp	x19, x20, [sp, #16]
            return mbox[1] == MBOX_RESPONSE;
   824a0:	b9400701 	ldr	w1, [x24, #4]
}
   824a4:	a9425bf5 	ldp	x21, x22, [sp, #32]
            return mbox[1] == MBOX_RESPONSE;
   824a8:	6b00003f 	cmp	w1, w0
   824ac:	1a9f17e0 	cset	w0, eq  // eq = none
}
   824b0:	a94363f7 	ldp	x23, x24, [sp, #48]
   824b4:	f94023f9 	ldr	x25, [sp, #64]
   824b8:	a8c57bfd 	ldp	x29, x30, [sp], #80
   824bc:	d65f03c0 	ret

00000000000824c0 <fb_detect_scr_dim>:
 * Return: 0 on success.
 *
 * FXL's 720p monitor: 1360x768
 * QEMU: 640x480 (initial; subject to reconfig for larger fb)
 */
int fb_detect_scr_dim(uint *w, uint *h) {
   824c0:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
    mbox[0] = 8*4;     // size of the whole buf that follows
   824c4:	52800404 	mov	w4, #0x20                  	// #32
    mbox[1] = MBOX_REQUEST; // cpu->gpu request
        mbox[2] = 0x40003;     // rls framebuffer
   824c8:	52800063 	mov	w3, #0x3                   	// #3
int fb_detect_scr_dim(uint *w, uint *h) {
   824cc:	910003fd 	mov	x29, sp
   824d0:	a90153f3 	stp	x19, x20, [sp, #16]
    mbox[0] = 8*4;     // size of the whole buf that follows
   824d4:	b0000093 	adrp	x19, 93000 <get_el+0xe61c>
        mbox[2] = 0x40003;     // rls framebuffer
   824d8:	72a00083 	movk	w3, #0x4, lsl #16
    mbox[0] = 8*4;     // size of the whole buf that follows
   824dc:	f9473673 	ldr	x19, [x19, #3688]
int fb_detect_scr_dim(uint *w, uint *h) {
   824e0:	f90013f5 	str	x21, [sp, #32]
        mbox[3] = 8;           // total buf size
   824e4:	52800102 	mov	w2, #0x8                   	// #8
int fb_detect_scr_dim(uint *w, uint *h) {
   824e8:	aa0003f4 	mov	x20, x0
   824ec:	aa0103f5 	mov	x21, x1
        mbox[4] = 0;           // req para size
        mbox[5] = 0;           // resp: width
        mbox[6] = 0;           // resp: height
    mbox[7] = MBOX_TAG_LAST;

    if(!mbox_call(MBOX_CH_PROP)) {
   824f0:	2a0203e0 	mov	w0, w2
    mbox[0] = 8*4;     // size of the whole buf that follows
   824f4:	b9000264 	str	w4, [x19]
    mbox[1] = MBOX_REQUEST; // cpu->gpu request
   824f8:	b900067f 	str	wzr, [x19, #4]
        mbox[2] = 0x40003;     // rls framebuffer
   824fc:	b9000a63 	str	w3, [x19, #8]
        mbox[3] = 8;           // total buf size
   82500:	b9000e62 	str	w2, [x19, #12]
        mbox[4] = 0;           // req para size
   82504:	b900127f 	str	wzr, [x19, #16]
        mbox[5] = 0;           // resp: width
   82508:	b900167f 	str	wzr, [x19, #20]
        mbox[6] = 0;           // resp: height
   8250c:	b9001a7f 	str	wzr, [x19, #24]
    mbox[7] = MBOX_TAG_LAST;
   82510:	b9001e7f 	str	wzr, [x19, #28]
    if(!mbox_call(MBOX_CH_PROP)) {
   82514:	97ffffa5 	bl	823a8 <mbox_call>
   82518:	34000220 	cbz	w0, 8255c <fb_detect_scr_dim+0x9c>
        E("failed to get screen dim");
        return -1;
    } 

    *w=mbox[5];*h=mbox[6]; I("detected screen dim %d %d", *w, *h);    
   8251c:	b9401660 	ldr	w0, [x19, #20]
   82520:	d0000001 	adrp	x1, 84000 <vectors>
   82524:	b9000280 	str	w0, [x20]
   82528:	913be021 	add	x1, x1, #0xef8
   8252c:	52801562 	mov	w2, #0xab                  	// #171
   82530:	d0000000 	adrp	x0, 84000 <vectors>
   82534:	b9401a64 	ldr	w4, [x19, #24]
   82538:	913e8000 	add	x0, x0, #0xfa0
   8253c:	b90002a4 	str	w4, [x21]
   82540:	b9400283 	ldr	w3, [x20]
   82544:	97fffc19 	bl	815a8 <tfp_printf>
    return 0; 
   82548:	52800000 	mov	w0, #0x0                   	// #0
}
   8254c:	a94153f3 	ldp	x19, x20, [sp, #16]
   82550:	f94013f5 	ldr	x21, [sp, #32]
   82554:	a8c37bfd 	ldp	x29, x30, [sp], #48
   82558:	d65f03c0 	ret
        E("failed to get screen dim");
   8255c:	d0000001 	adrp	x1, 84000 <vectors>
   82560:	d0000000 	adrp	x0, 84000 <vectors>
   82564:	913be021 	add	x1, x1, #0xef8
   82568:	913dc000 	add	x0, x0, #0xf70
   8256c:	528014e2 	mov	w2, #0xa7                  	// #167
   82570:	97fffc0e 	bl	815a8 <tfp_printf>
        return -1;
   82574:	12800000 	mov	w0, #0xffffffff            	// #-1
   82578:	17fffff5 	b	8254c <fb_detect_scr_dim+0x8c>
   8257c:	d503201f 	nop

0000000000082580 <fb_set_voffsets>:
/* 
 * Set virt offset
 * Caller must hold mboxlock
 * Return 0 on success 
 */
int fb_set_voffsets(int offsetx, int offsety) {
   82580:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!

    mbox[0] = 8*4;
   82584:	52800404 	mov	w4, #0x20                  	// #32
    mbox[1] = MBOX_REQUEST;
    
    mbox[2] = 0x48009; 
   82588:	52900123 	mov	w3, #0x8009                	// #32777
int fb_set_voffsets(int offsetx, int offsety) {
   8258c:	910003fd 	mov	x29, sp
   82590:	a9025bf5 	stp	x21, x22, [sp, #32]
    mbox[0] = 8*4;
   82594:	b0000096 	adrp	x22, 93000 <get_el+0xe61c>
    mbox[2] = 0x48009; 
   82598:	72a00083 	movk	w3, #0x4, lsl #16
int fb_set_voffsets(int offsetx, int offsety) {
   8259c:	a90153f3 	stp	x19, x20, [sp, #16]
    mbox[3] = 8;
   825a0:	52800102 	mov	w2, #0x8                   	// #8
int fb_set_voffsets(int offsetx, int offsety) {
   825a4:	2a0003f4 	mov	w20, w0
    mbox[0] = 8*4;
   825a8:	f94736d3 	ldr	x19, [x22, #3688]
int fb_set_voffsets(int offsetx, int offsety) {
   825ac:	2a0103f5 	mov	w21, w1
    mbox[5] =  offsetx;           //FrameBufferInfo.x_offset
    mbox[6] =  offsety;           //FrameBufferInfo.y.offset    

    mbox[7] = MBOX_TAG_LAST;

    if(!mbox_call(MBOX_CH_PROP)) {
   825b0:	2a0203e0 	mov	w0, w2
    mbox[0] = 8*4;
   825b4:	b9000264 	str	w4, [x19]
    mbox[1] = MBOX_REQUEST;
   825b8:	b900067f 	str	wzr, [x19, #4]
    mbox[2] = 0x48009; 
   825bc:	b9000a63 	str	w3, [x19, #8]
    mbox[3] = 8;
   825c0:	b9000e62 	str	w2, [x19, #12]
    mbox[4] = 8;
   825c4:	b9001262 	str	w2, [x19, #16]
    mbox[5] =  offsetx;           //FrameBufferInfo.x_offset
   825c8:	b9001674 	str	w20, [x19, #20]
    mbox[6] =  offsety;           //FrameBufferInfo.y.offset    
   825cc:	b9001a61 	str	w1, [x19, #24]
    mbox[7] = MBOX_TAG_LAST;
   825d0:	b9001e7f 	str	wzr, [x19, #28]
    if(!mbox_call(MBOX_CH_PROP)) {
   825d4:	97ffff75 	bl	823a8 <mbox_call>
   825d8:	34000460 	cbz	w0, 82664 <fb_set_voffsets+0xe4>
        E("failed to set virt offsets, requested x=%d y=%d", offsetx, offsety);
        return -1;
    }     
     if (mbox[5] != offsetx || mbox[6] != offsety) {
   825dc:	b9401660 	ldr	w0, [x19, #20]
   825e0:	6b00029f 	cmp	w20, w0
   825e4:	54000261 	b.ne	82630 <fb_set_voffsets+0xb0>  // b.any
   825e8:	b9401a60 	ldr	w0, [x19, #24]
   825ec:	6b0002bf 	cmp	w21, w0
   825f0:	54000201 	b.ne	82630 <fb_set_voffsets+0xb0>  // b.any
        E("failed set: offsetx %u offsety %u res: offsetx %u offsety %u", 
            offsetx, offsety, mbox[5], mbox[6]);
        return -1;     
     }
     V("set OK: offsetx %u offsety %u res: offsetx %u offsety %u", 
   825f4:	b9401665 	ldr	w5, [x19, #20]
   825f8:	2a1503e4 	mov	w4, w21
   825fc:	b9401a66 	ldr	w6, [x19, #24]
   82600:	2a1403e3 	mov	w3, w20
   82604:	d0000001 	adrp	x1, 84000 <vectors>
   82608:	f0000000 	adrp	x0, 85000 <get_el+0x61c>
   8260c:	913be021 	add	x1, x1, #0xef8
   82610:	9101a000 	add	x0, x0, #0x68
   82614:	52801942 	mov	w2, #0xca                  	// #202
   82618:	97fffbe4 	bl	815a8 <tfp_printf>
            offsetx, offsety, mbox[5], mbox[6]);
     return 0; 
   8261c:	52800000 	mov	w0, #0x0                   	// #0
}
   82620:	a94153f3 	ldp	x19, x20, [sp, #16]
   82624:	a9425bf5 	ldp	x21, x22, [sp, #32]
   82628:	a8c37bfd 	ldp	x29, x30, [sp], #48
   8262c:	d65f03c0 	ret
        E("failed set: offsetx %u offsety %u res: offsetx %u offsety %u", 
   82630:	f94736d6 	ldr	x22, [x22, #3688]
   82634:	2a1503e4 	mov	w4, w21
   82638:	2a1403e3 	mov	w3, w20
   8263c:	d0000001 	adrp	x1, 84000 <vectors>
   82640:	f0000000 	adrp	x0, 85000 <get_el+0x61c>
   82644:	913be021 	add	x1, x1, #0xef8
   82648:	b94016c5 	ldr	w5, [x22, #20]
   8264c:	91006000 	add	x0, x0, #0x18
   82650:	b9401ac6 	ldr	w6, [x22, #24]
   82654:	528018c2 	mov	w2, #0xc6                  	// #198
   82658:	97fffbd4 	bl	815a8 <tfp_printf>
        return -1;     
   8265c:	12800000 	mov	w0, #0xffffffff            	// #-1
   82660:	17fffff0 	b	82620 <fb_set_voffsets+0xa0>
        E("failed to set virt offsets, requested x=%d y=%d", offsetx, offsety);
   82664:	2a1503e4 	mov	w4, w21
   82668:	2a1403e3 	mov	w3, w20
   8266c:	d0000001 	adrp	x1, 84000 <vectors>
   82670:	d0000000 	adrp	x0, 84000 <vectors>
   82674:	913be021 	add	x1, x1, #0xef8
   82678:	913f4000 	add	x0, x0, #0xfd0
   8267c:	52801842 	mov	w2, #0xc2                  	// #194
   82680:	97fffbca 	bl	815a8 <tfp_printf>
        return -1;
   82684:	12800000 	mov	w0, #0xffffffff            	// #-1
   82688:	17ffffe6 	b	82620 <fb_set_voffsets+0xa0>
   8268c:	d503201f 	nop

0000000000082690 <fb_fini>:
    return ret; 
}

/* Finalize the framebuffer and clean up.
    Return 0 on success (display will go blank). */
int fb_fini(void) {
   82690:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
   82694:	910003fd 	mov	x29, sp
   82698:	a90153f3 	stp	x19, x20, [sp, #16]
    int ret = 0;

    acquire(&mboxlock);
    if (!the_fb.fb || !the_fb.size) {
   8269c:	b0000093 	adrp	x19, 93000 <get_el+0xe61c>
    acquire(&mboxlock);
   826a0:	b0000094 	adrp	x20, 93000 <get_el+0xe61c>
   826a4:	91392280 	add	x0, x20, #0xe48
   826a8:	97fffd66 	bl	81c40 <acquire>
    if (!the_fb.fb || !the_fb.size) {
   826ac:	f9429e60 	ldr	x0, [x19, #1336]
   826b0:	b4000460 	cbz	x0, 8273c <fb_fini+0xac>
   826b4:	9114e261 	add	x1, x19, #0x538
   826b8:	b9403422 	ldr	w2, [x1, #52]
   826bc:	34000402 	cbz	w2, 8273c <fb_fini+0xac>
        ret = -1;
        goto out;
    }

#ifdef PLAT_RPI3QEMU // avoid artifacts: qemu does not clear old fb
    memset(the_fb.fb, 0, the_fb.size);
   826c0:	52800001 	mov	w1, #0x0                   	// #0
   826c4:	97fffc93 	bl	81910 <memset>
#endif

    mbox[0] = 6 * 4;        // size of the whole buf that follows
   826c8:	b0000081 	adrp	x1, 93000 <get_el+0xe61c>
   826cc:	52800303 	mov	w3, #0x18                  	// #24
    mbox[1] = MBOX_REQUEST; // cpu->gpu request

    mbox[2] = 0x48001; // rls framebuffer
   826d0:	52900022 	mov	w2, #0x8001                	// #32769
    mbox[3] = 0;       // total buf size
    mbox[4] = 0;       // req para size

    mbox[5] = MBOX_TAG_LAST;

    if (!mbox_call(MBOX_CH_PROP))
   826d4:	52800100 	mov	w0, #0x8                   	// #8
    mbox[0] = 6 * 4;        // size of the whole buf that follows
   826d8:	f9473421 	ldr	x1, [x1, #3688]
    mbox[2] = 0x48001; // rls framebuffer
   826dc:	72a00082 	movk	w2, #0x4, lsl #16
    mbox[0] = 6 * 4;        // size of the whole buf that follows
   826e0:	b9000023 	str	w3, [x1]
    mbox[1] = MBOX_REQUEST; // cpu->gpu request
   826e4:	b900043f 	str	wzr, [x1, #4]
    mbox[2] = 0x48001; // rls framebuffer
   826e8:	b9000822 	str	w2, [x1, #8]
    mbox[3] = 0;       // total buf size
   826ec:	b9000c3f 	str	wzr, [x1, #12]
    mbox[4] = 0;       // req para size
   826f0:	b900103f 	str	wzr, [x1, #16]
    mbox[5] = MBOX_TAG_LAST;
   826f4:	b900143f 	str	wzr, [x1, #20]
    if (!mbox_call(MBOX_CH_PROP))
   826f8:	97ffff2c 	bl	823a8 <mbox_call>
   826fc:	34000120 	cbz	w0, 82720 <fb_fini+0x90>
    // wont need this until flavor simple/rich user
    // if (free_phys_region(VA2PA(the_fb.fb), the_fb.size)) {
    //     E("failed to free fb memory. bug?");
    //     ret = -2;
    // }
    the_fb.fb = 0;
   82700:	f9029e7f 	str	xzr, [x19, #1336]
    int ret = 0;
   82704:	52800013 	mov	w19, #0x0                   	// #0
out:
    release(&mboxlock);
   82708:	91392280 	add	x0, x20, #0xe48
   8270c:	97fffda5 	bl	81da0 <release>
    return ret;
}
   82710:	2a1303e0 	mov	w0, w19
   82714:	a94153f3 	ldp	x19, x20, [sp, #16]
   82718:	a8c27bfd 	ldp	x29, x30, [sp], #32
   8271c:	d65f03c0 	ret
        I("failed to rls fb with GPU.");
   82720:	d0000001 	adrp	x1, 84000 <vectors>
   82724:	f0000000 	adrp	x0, 85000 <get_el+0x61c>
   82728:	913be021 	add	x1, x1, #0xef8
   8272c:	9102c000 	add	x0, x0, #0xb0
   82730:	52802b02 	mov	w2, #0x158                 	// #344
   82734:	97fffb9d 	bl	815a8 <tfp_printf>
   82738:	17fffff2 	b	82700 <fb_fini+0x70>
        ret = -1;
   8273c:	12800013 	mov	w19, #0xffffffff            	// #-1
   82740:	17fffff2 	b	82708 <fb_fini+0x78>
   82744:	d503201f 	nop

0000000000082748 <fb_print>:
    unsigned char *fb = the_fb.fb;

    // get our font
    psf_t *font = (psf_t *)&_binary_font_psf_start;
    // draw next character if it's not zero
    while (*s) {
   82748:	39400043 	ldrb	w3, [x2]
    unsigned pitch = the_fb.pitch;
   8274c:	b0000084 	adrp	x4, 93000 <get_el+0xe61c>
   82750:	9114e085 	add	x5, x4, #0x538
    unsigned char *fb = the_fb.fb;
   82754:	f9429c8f 	ldr	x15, [x4, #1336]
    unsigned pitch = the_fb.pitch;
   82758:	b94018ab 	ldr	w11, [x5, #24]
    while (*s) {
   8275c:	34000923 	cbz	w3, 82880 <fb_print+0x138>
void fb_print(int *x, int *y, char *s) {
   82760:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
        /* get offset of the glyph. Need to adjust this to support unicode table */
        unsigned char *glyph = (unsigned char *)&_binary_font_psf_start +
                               font->headersize + (*((unsigned char *)s) < font->numglyph ? *s : 0) * font->bytesperglyph;
   82764:	b0000084 	adrp	x4, 93000 <get_el+0xe61c>
            } else {
                // display a character
                for (j = 0; j < font->height; j++) {
                    // display one row
                    line = offs;
                    mask = 1 << (font->width - 1);
   82768:	5280002e 	mov	w14, #0x1                   	// #1
void fb_print(int *x, int *y, char *s) {
   8276c:	910003fd 	mov	x29, sp
                               font->headersize + (*((unsigned char *)s) < font->numglyph ? *s : 0) * font->bytesperglyph;
   82770:	f9474884 	ldr	x4, [x4, #3728]
   82774:	910011f1 	add	x17, x15, #0x4
                    for (i = 0; i < font->width; i++) {
                        // if bit set, we use white color, otherwise black
                        *((unsigned int *)(fb + line)) = ((int)*glyph) & mask ? 0xFFFFFF : 0;
   82778:	12bfe008 	mov	w8, #0xffffff              	// #16777215
void fb_print(int *x, int *y, char *s) {
   8277c:	a90153f3 	stp	x19, x20, [sp, #16]
        unsigned char *glyph = (unsigned char *)&_binary_font_psf_start +
   82780:	aa0403f4 	mov	x20, x4
                               font->headersize + (*((unsigned char *)s) < font->numglyph ? *s : 0) * font->bytesperglyph;
   82784:	b940088d 	ldr	w13, [x4, #8]
   82788:	b940109e 	ldr	w30, [x4, #16]
   8278c:	b9401492 	ldr	w18, [x4, #20]
   82790:	2a0d03ed 	mov	w13, w13
        int i, j, line, mask, bytesperline = (font->width + 7) / 8;
   82794:	b9401c8a 	ldr	w10, [x4, #28]
                for (j = 0; j < font->height; j++) {
   82798:	b9401889 	ldr	w9, [x4, #24]
        int i, j, line, mask, bytesperline = (font->width + 7) / 8;
   8279c:	11001d4c 	add	w12, w10, #0x7
                    mask = 1 << (font->width - 1);
   827a0:	51000550 	sub	w16, w10, #0x1
   827a4:	0b0e0153 	add	w19, w10, w14
void fb_print(int *x, int *y, char *s) {
   827a8:	a9025bf5 	stp	x21, x22, [sp, #32]
   827ac:	53037d8c 	lsr	w12, w12, #3
                    mask = 1 << (font->width - 1);
   827b0:	1ad021ce 	lsl	w14, w14, w16
   827b4:	14000009 	b	827d8 <fb_print+0x90>
            if (*s == '\n') {
   827b8:	7100287f 	cmp	w3, #0xa
   827bc:	54000281 	b.ne	8280c <fb_print+0xc4>  // b.any
                *x = 0;
   827c0:	b900001f 	str	wzr, [x0]
                *y += font->height;
   827c4:	b9400023 	ldr	w3, [x1]
   827c8:	0b090063 	add	w3, w3, w9
   827cc:	b9000023 	str	w3, [x1]
    while (*s) {
   827d0:	38401c43 	ldrb	w3, [x2, #1]!
   827d4:	34000143 	cbz	w3, 827fc <fb_print+0xb4>
        unsigned char *glyph = (unsigned char *)&_binary_font_psf_start +
   827d8:	1b127c66 	mul	w6, w3, w18
   827dc:	6b1e007f 	cmp	w3, w30
   827e0:	8b0d00c6 	add	x6, x6, x13
   827e4:	9a8d30c6 	csel	x6, x6, x13, cc  // cc = lo, ul, last
        if (*s == '\r') {
   827e8:	7100347f 	cmp	w3, #0xd
   827ec:	54fffe61 	b.ne	827b8 <fb_print+0x70>  // b.any
            *x = 0;
   827f0:	b900001f 	str	wzr, [x0]
    while (*s) {
   827f4:	38401c43 	ldrb	w3, [x2, #1]!
   827f8:	35ffff03 	cbnz	w3, 827d8 <fb_print+0x90>
                *x += (font->width + 1);
            }
        // next character
        s++;
    }
}
   827fc:	a94153f3 	ldp	x19, x20, [sp, #16]
   82800:	a9425bf5 	ldp	x21, x22, [sp, #32]
   82804:	a8c37bfd 	ldp	x29, x30, [sp], #48
   82808:	d65f03c0 	ret
        int offs = (*y * pitch) + (*x * 4);
   8280c:	b9400003 	ldr	w3, [x0]
                for (j = 0; j < font->height; j++) {
   82810:	34000329 	cbz	w9, 82874 <fb_print+0x12c>
        int offs = (*y * pitch) + (*x * 4);
   82814:	b9400035 	ldr	w21, [x1]
   82818:	531e7463 	lsl	w3, w3, #2
        unsigned char *glyph = (unsigned char *)&_binary_font_psf_start +
   8281c:	8b1400c6 	add	x6, x6, x20
                for (j = 0; j < font->height; j++) {
   82820:	52800016 	mov	w22, #0x0                   	// #0
        int offs = (*y * pitch) + (*x * 4);
   82824:	1b150d75 	madd	w21, w11, w21, w3
                    for (i = 0; i < font->width; i++) {
   82828:	340001aa 	cbz	w10, 8285c <fb_print+0x114>
   8282c:	93407ea3 	sxtw	x3, w21
                    mask = 1 << (font->width - 1);
   82830:	2a0e03e4 	mov	w4, w14
   82834:	8b304867 	add	x7, x3, w16, uxtw #2
   82838:	8b0301e3 	add	x3, x15, x3
   8283c:	8b1100e7 	add	x7, x7, x17
                        *((unsigned int *)(fb + line)) = ((int)*glyph) & mask ? 0xFFFFFF : 0;
   82840:	394000c5 	ldrb	w5, [x6]
   82844:	6a0400bf 	tst	w5, w4
                        mask >>= 1;
   82848:	13017c84 	asr	w4, w4, #1
                        *((unsigned int *)(fb + line)) = ((int)*glyph) & mask ? 0xFFFFFF : 0;
   8284c:	1a9f1105 	csel	w5, w8, wzr, ne  // ne = any
   82850:	b8004465 	str	w5, [x3], #4
                    for (i = 0; i < font->width; i++) {
   82854:	eb07007f 	cmp	x3, x7
   82858:	54ffff41 	b.ne	82840 <fb_print+0xf8>  // b.any
                for (j = 0; j < font->height; j++) {
   8285c:	110006d6 	add	w22, w22, #0x1
                    glyph += bytesperline;
   82860:	8b0c00c6 	add	x6, x6, x12
                for (j = 0; j < font->height; j++) {
   82864:	6b0902df 	cmp	w22, w9
   82868:	0b0b02b5 	add	w21, w21, w11
   8286c:	54fffde1 	b.ne	82828 <fb_print+0xe0>  // b.any
   82870:	b9400003 	ldr	w3, [x0]
                *x += (font->width + 1);
   82874:	0b130063 	add	w3, w3, w19
   82878:	b9000003 	str	w3, [x0]
   8287c:	17ffffd5 	b	827d0 <fb_print+0x88>
   82880:	d65f03c0 	ret
   82884:	d503201f 	nop

0000000000082888 <fb_showpicture>:
#define IMG_DATA header_data      
#define IMG_HEIGHT height
#define IMG_WIDTH width

void fb_showpicture()
{
   82888:	a9bb7bfd 	stp	x29, x30, [sp, #-80]!
    unsigned char *ptr=the_fb.fb;
    char *data=IMG_DATA, pixel[4];
    char res[16]; 

    // fill framebuf. crop img data per the framebuf size
    unsigned int img_fb_height = the_fb.vheight < IMG_HEIGHT ? the_fb.vheight : IMG_HEIGHT; 
   8288c:	52800ecd 	mov	w13, #0x76                  	// #118
    unsigned int img_fb_width = the_fb.vwidth < IMG_WIDTH ? the_fb.vwidth : IMG_WIDTH; 
   82890:	52800e8b 	mov	w11, #0x74                  	// #116
{
   82894:	910003fd 	mov	x29, sp
   82898:	a90153f3 	stp	x19, x20, [sp, #16]
    unsigned char *ptr=the_fb.fb;
   8289c:	b0000093 	adrp	x19, 93000 <get_el+0xe61c>
   828a0:	9114e26a 	add	x10, x19, #0x538
   828a4:	f9429e66 	ldr	x6, [x19, #1336]
{
   828a8:	a9025bf5 	stp	x21, x22, [sp, #32]

    // copy the image pixels to the start (top) of framebuf    
    ptr += (the_fb.vwidth-img_fb_width)/2*PIXELSIZE;  // top center
    ptr += (the_fb.vheight-img_fb_height)/2*the_fb.pitch; 
   828ac:	b9401940 	ldr	w0, [x10, #24]
    unsigned int img_fb_height = the_fb.vheight < IMG_HEIGHT ? the_fb.vheight : IMG_HEIGHT; 
   828b0:	2942054e 	ldp	w14, w1, [x10, #16]
    
    // Q6 quest: OS logo
    for(y=0;y<img_fb_height;y++) {
   828b4:	b9003fff 	str	wzr, [sp, #60]
    unsigned int img_fb_height = the_fb.vheight < IMG_HEIGHT ? the_fb.vheight : IMG_HEIGHT; 
   828b8:	6b0d003f 	cmp	w1, w13
   828bc:	1a8d902d 	csel	w13, w1, w13, ls  // ls = plast
    unsigned int img_fb_width = the_fb.vwidth < IMG_WIDTH ? the_fb.vwidth : IMG_WIDTH; 
   828c0:	6b0b01df 	cmp	w14, w11
    ptr += (the_fb.vheight-img_fb_height)/2*the_fb.pitch; 
   828c4:	4b0d0023 	sub	w3, w1, w13
    unsigned int img_fb_width = the_fb.vwidth < IMG_WIDTH ? the_fb.vwidth : IMG_WIDTH; 
   828c8:	1a8b91cb 	csel	w11, w14, w11, ls  // ls = plast
    ptr += (the_fb.vwidth-img_fb_width)/2*PIXELSIZE;  // top center
   828cc:	4b0b01c4 	sub	w4, w14, w11
    ptr += (the_fb.vheight-img_fb_height)/2*the_fb.pitch; 
   828d0:	53017c63 	lsr	w3, w3, #1
    ptr += (the_fb.vwidth-img_fb_width)/2*PIXELSIZE;  // top center
   828d4:	53017c84 	lsr	w4, w4, #1
    ptr += (the_fb.vheight-img_fb_height)/2*the_fb.pitch; 
   828d8:	1b007c60 	mul	w0, w3, w0
    ptr += (the_fb.vwidth-img_fb_width)/2*PIXELSIZE;  // top center
   828dc:	531e7482 	lsl	w2, w4, #2
    ptr += (the_fb.vheight-img_fb_height)/2*the_fb.pitch; 
   828e0:	8b020000 	add	x0, x0, x2
   828e4:	8b0000c6 	add	x6, x6, x0
    for(y=0;y<img_fb_height;y++) {
   828e8:	340007c1 	cbz	w1, 829e0 <fb_showpicture+0x158>
    char *data=IMG_DATA, pixel[4];
   828ec:	f0000004 	adrp	x4, 85000 <get_el+0x61c>
   828f0:	91038084 	add	x4, x4, #0xe0
            else{
                ptr[offset + 0] = pixel[0];
                ptr[offset + 1] = pixel[1];
                ptr[offset + 2] = pixel[2];
            }
            ptr[offset + 3] = 0xFF;
   828f4:	1280000c 	mov	w12, #0xffffffff            	// #-1
        for(x=0;x<img_fb_width;x++) {
   828f8:	b9003bff 	str	wzr, [sp, #56]
   828fc:	340005ae 	cbz	w14, 829b0 <fb_showpicture+0x128>
   82900:	52800000 	mov	w0, #0x0                   	// #0
   82904:	1400000a 	b	8292c <fb_showpicture+0xa4>
                ptr[offset + 0] = pixel[2];
   82908:	3820c8c1 	strb	w1, [x6, w0, sxtw]
                ptr[offset + 1] = pixel[1];
   8290c:	382868c2 	strb	w2, [x6, x8]
                ptr[offset + 2] = pixel[0];
   82910:	382568c3 	strb	w3, [x6, x5]
            ptr[offset + 3] = 0xFF;
   82914:	39000cec 	strb	w12, [x7, #3]
        for(x=0;x<img_fb_width;x++) {
   82918:	b9403be0 	ldr	w0, [sp, #56]
   8291c:	11000400 	add	w0, w0, #0x1
   82920:	b9003be0 	str	w0, [sp, #56]
   82924:	6b0b001f 	cmp	w0, w11
   82928:	54000442 	b.cs	829b0 <fb_showpicture+0x128>  // b.hs, b.nlast
            HEADER_PIXEL(data, pixel);
   8292c:	39400482 	ldrb	w2, [x4, #1]
            int offset = x * 4;
   82930:	531e7400 	lsl	w0, w0, #2
            HEADER_PIXEL(data, pixel);
   82934:	39400881 	ldrb	w1, [x4, #2]
   82938:	91001084 	add	x4, x4, #0x4
   8293c:	385fc083 	ldurb	w3, [x4, #-4]
   82940:	51008442 	sub	w2, w2, #0x21
   82944:	51008421 	sub	w1, w1, #0x21
   82948:	385ff085 	ldurb	w5, [x4, #-1]
            if(the_fb.isrgb){
   8294c:	b9402949 	ldr	w9, [x10, #40]
            HEADER_PIXEL(data, pixel);
   82950:	51008463 	sub	w3, w3, #0x21
   82954:	13047c48 	asr	w8, w2, #4
   82958:	13027c27 	asr	w7, w1, #2
   8295c:	510084a5 	sub	w5, w5, #0x21
   82960:	2a030903 	orr	w3, w8, w3, lsl #2
   82964:	2a0210e2 	orr	w2, w7, w2, lsl #4
   82968:	2a0118a1 	orr	w1, w5, w1, lsl #6
   8296c:	93407c05 	sxtw	x5, w0
   82970:	12001c63 	and	w3, w3, #0xff
   82974:	8b0500c7 	add	x7, x6, x5
   82978:	910004a8 	add	x8, x5, #0x1
   8297c:	12001c42 	and	w2, w2, #0xff
   82980:	12001c21 	and	w1, w1, #0xff
            if(the_fb.isrgb){
   82984:	910008a5 	add	x5, x5, #0x2
   82988:	35fffc09 	cbnz	w9, 82908 <fb_showpicture+0x80>
                ptr[offset + 0] = pixel[0];
   8298c:	3820c8c3 	strb	w3, [x6, w0, sxtw]
                ptr[offset + 1] = pixel[1];
   82990:	382868c2 	strb	w2, [x6, x8]
                ptr[offset + 2] = pixel[2];
   82994:	382568c1 	strb	w1, [x6, x5]
            ptr[offset + 3] = 0xFF;
   82998:	39000cec 	strb	w12, [x7, #3]
        for(x=0;x<img_fb_width;x++) {
   8299c:	b9403be0 	ldr	w0, [sp, #56]
   829a0:	11000400 	add	w0, w0, #0x1
   829a4:	b9003be0 	str	w0, [sp, #56]
   829a8:	6b0b001f 	cmp	w0, w11
   829ac:	54fffc03 	b.cc	8292c <fb_showpicture+0xa4>  // b.lo, b.ul, b.last
    for(y=0;y<img_fb_height;y++) {
   829b0:	b9403fe0 	ldr	w0, [sp, #60]
        }
        // advance ptr to the start of the next line of the pixels
        /* STUDENT_TODO: your code here */
        ptr += the_fb.pitch;
   829b4:	b9401941 	ldr	w1, [x10, #24]
    for(y=0;y<img_fb_height;y++) {
   829b8:	11000400 	add	w0, w0, #0x1
   829bc:	b9003fe0 	str	w0, [sp, #60]
        ptr += the_fb.pitch;
   829c0:	8b0100c6 	add	x6, x6, x1
    for(y=0;y<img_fb_height;y++) {
   829c4:	6b0d001f 	cmp	w0, w13
   829c8:	54fff983 	b.cc	828f8 <fb_showpicture+0x70>  // b.lo, b.ul, b.last
   829cc:	29420d44 	ldp	w4, w3, [x10, #16]
   829d0:	4b0b0084 	sub	w4, w4, w11
   829d4:	4b0d0063 	sub	w3, w3, w13
   829d8:	53017c84 	lsr	w4, w4, #1
   829dc:	53017c63 	lsr	w3, w3, #1

    x = (the_fb.vwidth - img_fb_width) / 2;
    y = (the_fb.vheight - img_fb_height) / 2;

    fb_print(&x, &y, "UVA OS");    
    sprintf(res, " %dx%d", the_fb.width, the_fb.height); // debug info 
   829e0:	9114e273 	add	x19, x19, #0x538
    fb_print(&x, &y, "UVA OS");    
   829e4:	9100f3f5 	add	x21, sp, #0x3c
   829e8:	9100e3f4 	add	x20, sp, #0x38
   829ec:	aa1503e1 	mov	x1, x21
   829f0:	aa1403e0 	mov	x0, x20
   829f4:	90000082 	adrp	x2, 92000 <get_el+0xd61c>
   829f8:	911b2042 	add	x2, x2, #0x6c8
    y = (the_fb.vheight - img_fb_height) / 2;
   829fc:	29070fe4 	stp	w4, w3, [sp, #56]
    fb_print(&x, &y, "UVA OS");    
   82a00:	97ffff52 	bl	82748 <fb_print>
    sprintf(res, " %dx%d", the_fb.width, the_fb.height); // debug info 
   82a04:	910103f6 	add	x22, sp, #0x40
   82a08:	29410e62 	ldp	w2, w3, [x19, #8]
   82a0c:	aa1603e0 	mov	x0, x22
   82a10:	90000081 	adrp	x1, 92000 <get_el+0xd61c>
   82a14:	911b4021 	add	x1, x1, #0x6d0
   82a18:	97fffb48 	bl	81738 <tfp_sprintf>
    fb_print(&x, &y, res);
   82a1c:	aa1603e2 	mov	x2, x22
   82a20:	aa1503e1 	mov	x1, x21
   82a24:	aa1403e0 	mov	x0, x20
   82a28:	97ffff48 	bl	82748 <fb_print>
}
   82a2c:	a94153f3 	ldp	x19, x20, [sp, #16]
   82a30:	a9425bf5 	ldp	x21, x22, [sp, #32]
   82a34:	a8c57bfd 	ldp	x29, x30, [sp], #80
   82a38:	d65f03c0 	ret
   82a3c:	d503201f 	nop

0000000000082a40 <fb_init>:
int fb_init(void) {
   82a40:	d10143ff 	sub	sp, sp, #0x50
   82a44:	a9017bfd 	stp	x29, x30, [sp, #16]
   82a48:	910043fd 	add	x29, sp, #0x10
   82a4c:	a90463f7 	stp	x23, x24, [sp, #64]
    mbox[0] = 35 * 4;       // size of the whole buf that follows
   82a50:	b0000097 	adrp	x23, 93000 <get_el+0xe61c>
int fb_init(void) {
   82a54:	a90253f3 	stp	x19, x20, [sp, #32]
   82a58:	a9035bf5 	stp	x21, x22, [sp, #48]
    acquire(&mboxlock);
   82a5c:	b0000096 	adrp	x22, 93000 <get_el+0xe61c>
   82a60:	913922c0 	add	x0, x22, #0xe48
   82a64:	97fffc77 	bl	81c40 <acquire>
    mbox[5] = fbs->width;  //(val) FrameBufferInfo.width
   82a68:	b0000095 	adrp	x21, 93000 <get_el+0xe61c>
    mbox[0] = 35 * 4;       // size of the whole buf that follows
   82a6c:	f94736f3 	ldr	x19, [x23, #3688]
   82a70:	52801182 	mov	w2, #0x8c                  	// #140
    mbox[5] = fbs->width;  //(val) FrameBufferInfo.width
   82a74:	9114e2b4 	add	x20, x21, #0x538
    mbox[2] = 0x48003;     // set phy width & height
   82a78:	52900060 	mov	w0, #0x8003                	// #32771
   82a7c:	72a00080 	movk	w0, #0x4, lsl #16
    mbox[3] = 8;           // total buf size of this tag
   82a80:	52800101 	mov	w1, #0x8                   	// #8
    mbox[0] = 35 * 4;       // size of the whole buf that follows
   82a84:	b9000262 	str	w2, [x19]
    mbox[7] = 0x48004; // set virt width & height
   82a88:	52900089 	mov	w9, #0x8004                	// #32772
    mbox[1] = MBOX_REQUEST; // cpu->gpu request
   82a8c:	b900067f 	str	wzr, [x19, #4]
    mbox[7] = 0x48004; // set virt width & height
   82a90:	72a00089 	movk	w9, #0x4, lsl #16
    mbox[2] = 0x48003;     // set phy width & height
   82a94:	b9000a60 	str	w0, [x19, #8]
    mbox[12] = 0x48009; // set virt offset
   82a98:	52900128 	mov	w8, #0x8009                	// #32777
    mbox[3] = 8;           // total buf size of this tag
   82a9c:	b9000e61 	str	w1, [x19, #12]
    mbox[12] = 0x48009; // set virt offset
   82aa0:	72a00088 	movk	w8, #0x4, lsl #16
    mbox[5] = fbs->width;  //(val) FrameBufferInfo.width
   82aa4:	b9400a80 	ldr	w0, [x20, #8]
    mbox[17] = 0x48005; // set depth
   82aa8:	529000a7 	mov	w7, #0x8005                	// #32773
    mbox[4] = 8;           // req val size (needed?), to be overwritten as resp val size
   82aac:	b9001261 	str	w1, [x19, #16]
    mbox[17] = 0x48005; // set depth
   82ab0:	72a00087 	movk	w7, #0x4, lsl #16
    mbox[5] = fbs->width;  //(val) FrameBufferInfo.width
   82ab4:	b9001660 	str	w0, [x19, #20]
    mbox[18] = 4;
   82ab8:	52800082 	mov	w2, #0x4                   	// #4
    mbox[6] = fbs->height; //(val) FrameBufferInfo.height
   82abc:	b9400e80 	ldr	w0, [x20, #12]
    mbox[21] = 0x48006; // set pixel order
   82ac0:	529000c6 	mov	w6, #0x8006                	// #32774
    mbox[6] = fbs->height; //(val) FrameBufferInfo.height
   82ac4:	b9001a60 	str	w0, [x19, #24]
    mbox[21] = 0x48006; // set pixel order
   82ac8:	72a00086 	movk	w6, #0x4, lsl #16
    mbox[7] = 0x48004; // set virt width & height
   82acc:	b9001e69 	str	w9, [x19, #28]
    mbox[25] = 0x40001; // get framebuffer, gets alignment on request
   82ad0:	52800025 	mov	w5, #0x1                   	// #1
    mbox[8] = 8;
   82ad4:	b9002261 	str	w1, [x19, #32]
    mbox[25] = 0x40001; // get framebuffer, gets alignment on request
   82ad8:	72a00085 	movk	w5, #0x4, lsl #16
    mbox[10] = fbs->vwidth;  // FrameBufferInfo.virtual_width
   82adc:	b9401289 	ldr	w9, [x20, #16]
    mbox[28] = 4096; // req: alignment; resp: FrameBufferInfo.pointer
   82ae0:	52820004 	mov	w4, #0x1000                	// #4096
    mbox[9] = 8;
   82ae4:	b9002661 	str	w1, [x19, #36]
    mbox[30] = 0x40008; // get pitch
   82ae8:	52800103 	mov	w3, #0x8                   	// #8
    mbox[10] = fbs->vwidth;  // FrameBufferInfo.virtual_width
   82aec:	b9002a69 	str	w9, [x19, #40]
    mbox[30] = 0x40008; // get pitch
   82af0:	72a00083 	movk	w3, #0x4, lsl #16
    mbox[11] = fbs->vheight; // FrameBufferInfo.virtual_height
   82af4:	b9401689 	ldr	w9, [x20, #20]
    if(mbox_call(MBOX_CH_PROP) 
   82af8:	2a0103e0 	mov	w0, w1
    mbox[11] = fbs->vheight; // FrameBufferInfo.virtual_height
   82afc:	b9002e69 	str	w9, [x19, #44]
    mbox[12] = 0x48009; // set virt offset
   82b00:	b9003268 	str	w8, [x19, #48]
    mbox[13] = 8;
   82b04:	b9003661 	str	w1, [x19, #52]
    mbox[15] = fbs->offsetx;
   82b08:	b9402e88 	ldr	w8, [x20, #44]
    mbox[14] = 8;
   82b0c:	b9003a61 	str	w1, [x19, #56]
    mbox[15] = fbs->offsetx;
   82b10:	b9003e68 	str	w8, [x19, #60]
    mbox[16] = fbs->offsety;
   82b14:	b9403288 	ldr	w8, [x20, #48]
   82b18:	b9004268 	str	w8, [x19, #64]
    mbox[17] = 0x48005; // set depth
   82b1c:	b9004667 	str	w7, [x19, #68]
    mbox[18] = 4;
   82b20:	b9004a62 	str	w2, [x19, #72]
    mbox[20] = fbs->depth;
   82b24:	b9402687 	ldr	w7, [x20, #36]
    mbox[19] = 4;
   82b28:	b9004e62 	str	w2, [x19, #76]
    mbox[20] = fbs->depth;
   82b2c:	b9005267 	str	w7, [x19, #80]
    mbox[21] = 0x48006; // set pixel order
   82b30:	b9005666 	str	w6, [x19, #84]
    mbox[22] = 4;
   82b34:	b9005a62 	str	w2, [x19, #88]
    mbox[23] = 4;
   82b38:	b9005e62 	str	w2, [x19, #92]
    mbox[24] = fbs->isrgb; // RGB, not BGR preferably
   82b3c:	b9402a86 	ldr	w6, [x20, #40]
   82b40:	b9006266 	str	w6, [x19, #96]
    mbox[25] = 0x40001; // get framebuffer, gets alignment on request
   82b44:	b9006665 	str	w5, [x19, #100]
    mbox[26] = 8;
   82b48:	b9006a61 	str	w1, [x19, #104]
    mbox[27] = 8;    // should be 4?? (req para size)
   82b4c:	b9006e61 	str	w1, [x19, #108]
    mbox[28] = 4096; // req: alignment; resp: FrameBufferInfo.pointer
   82b50:	b9007264 	str	w4, [x19, #112]
    mbox[29] = 0;    // resp: FrameBufferInfo.size
   82b54:	b900767f 	str	wzr, [x19, #116]
    mbox[30] = 0x40008; // get pitch
   82b58:	b9007a63 	str	w3, [x19, #120]
    mbox[31] = 4;
   82b5c:	b9007e62 	str	w2, [x19, #124]
    mbox[32] = 4;
   82b60:	b9008262 	str	w2, [x19, #128]
    mbox[33] = 0; // FrameBufferInfo.pitch
   82b64:	b900867f 	str	wzr, [x19, #132]
    mbox[34] = MBOX_TAG_LAST; // the end of tag seq
   82b68:	b9008a7f 	str	wzr, [x19, #136]
    if(mbox_call(MBOX_CH_PROP) 
   82b6c:	97fffe0f 	bl	823a8 <mbox_call>
   82b70:	34000a20 	cbz	w0, 82cb4 <fb_init+0x274>
        && mbox[20]==fbs->depth /*depth*/ 
   82b74:	b9405261 	ldr	w1, [x19, #80]
   82b78:	b9402680 	ldr	w0, [x20, #36]
   82b7c:	6b00003f 	cmp	w1, w0
   82b80:	540009a1 	b.ne	82cb4 <fb_init+0x274>  // b.any
        && mbox[28]!=0 /*framebuf*/) {
   82b84:	b9407260 	ldr	w0, [x19, #112]
   82b88:	34000960 	cbz	w0, 82cb4 <fb_init+0x274>
        mbox[28]&=0x3FFFFFFF;  
   82b8c:	b9407260 	ldr	w0, [x19, #112]
   82b90:	d0000018 	adrp	x24, 84000 <vectors>
   82b94:	12007400 	and	w0, w0, #0x3fffffff
   82b98:	b9007260 	str	w0, [x19, #112]
            fbs->fb = (void*)((unsigned long)mbox[28]); //set framebuffer
   82b9c:	b9407260 	ldr	w0, [x19, #112]
        fbs->width=mbox[5];
   82ba0:	b9401664 	ldr	w4, [x19, #20]
        fbs->height = mbox[6]; //set height
   82ba4:	b9401a65 	ldr	w5, [x19, #24]
            fbs->fb = (void*)((unsigned long)mbox[28]); //set framebuffer
   82ba8:	2a0003e0 	mov	w0, w0
        fbs->vwidth=mbox[10];
   82bac:	b9402a66 	ldr	w6, [x19, #40]
        fbs->vheight=mbox[11];        
   82bb0:	b9402e67 	ldr	w7, [x19, #44]
        fbs->depth=mbox[20]; 
   82bb4:	b9405261 	ldr	w1, [x19, #80]
        fbs->isrgb=mbox[24];     // channel order
   82bb8:	b9406268 	ldr	w8, [x19, #96]
        fbs->pitch = mbox[33]; // sets pitch
   82bbc:	b9408662 	ldr	w2, [x19, #132]
        if(fbs->pitch * fbs->vheight > mbox[29])  // possible that pitch*vheight < actual allocation
   82bc0:	b9407663 	ldr	w3, [x19, #116]
            fbs->fb = (void*)((unsigned long)mbox[28]); //set framebuffer
   82bc4:	f9029ea0 	str	x0, [x21, #1336]
        fbs->height = mbox[6]; //set height
   82bc8:	29011684 	stp	w4, w5, [x20, #8]
        if(fbs->pitch * fbs->vheight > mbox[29])  // possible that pitch*vheight < actual allocation
   82bcc:	1b027ce0 	mul	w0, w7, w2
        fbs->vheight=mbox[11];        
   82bd0:	29021e86 	stp	w6, w7, [x20, #16]
        fbs->pitch = mbox[33]; // sets pitch
   82bd4:	b9001a82 	str	w2, [x20, #24]
        fbs->isrgb=mbox[24];     // channel order
   82bd8:	2904a281 	stp	w1, w8, [x20, #36]
        if(fbs->pitch * fbs->vheight > mbox[29])  // possible that pitch*vheight < actual allocation
   82bdc:	6b03001f 	cmp	w0, w3
   82be0:	54000308 	b.hi	82c40 <fb_init+0x200>  // b.pmore
        I("OK. fb pa: 0x%08x w %u h %u vw %u vh %u pitch %u isrgb %u", 
   82be4:	f94736f7 	ldr	x23, [x23, #3688]
        fbs->size = PGROUNDUP(fbs->pitch * fbs->vheight);  // roundup b/c we'll reserve pages for it
   82be8:	113ffc00 	add	w0, w0, #0xfff
   82bec:	9114e2b5 	add	x21, x21, #0x538
        I("OK. fb pa: 0x%08x w %u h %u vw %u vh %u pitch %u isrgb %u", 
   82bf0:	913be301 	add	x1, x24, #0xef8
   82bf4:	b94072e3 	ldr	w3, [x23, #112]
   82bf8:	b9000be8 	str	w8, [sp, #8]
        fbs->size = PGROUNDUP(fbs->pitch * fbs->vheight);  // roundup b/c we'll reserve pages for it
   82bfc:	12144c08 	and	w8, w0, #0xfffff000
        I("OK. fb pa: 0x%08x w %u h %u vw %u vh %u pitch %u isrgb %u", 
   82c00:	b90003e2 	str	w2, [sp]
   82c04:	52802502 	mov	w2, #0x128                 	// #296
   82c08:	90000080 	adrp	x0, 92000 <get_el+0xd61c>
   82c0c:	911c4000 	add	x0, x0, #0x710
        fbs->size = PGROUNDUP(fbs->pitch * fbs->vheight);  // roundup b/c we'll reserve pages for it
   82c10:	b90036a8 	str	w8, [x21, #52]
        I("OK. fb pa: 0x%08x w %u h %u vw %u vh %u pitch %u isrgb %u", 
   82c14:	97fffa65 	bl	815a8 <tfp_printf>
    release(&mboxlock); 
   82c18:	913922c0 	add	x0, x22, #0xe48
   82c1c:	97fffc61 	bl	81da0 <release>
    if (ret==0 && once)
   82c20:	b9403aa0 	ldr	w0, [x21, #56]
   82c24:	35000360 	cbnz	w0, 82c90 <fb_init+0x250>
}
   82c28:	a9417bfd 	ldp	x29, x30, [sp, #16]
   82c2c:	a94253f3 	ldp	x19, x20, [sp, #32]
   82c30:	a9435bf5 	ldp	x21, x22, [sp, #48]
   82c34:	a94463f7 	ldp	x23, x24, [sp, #64]
   82c38:	910143ff 	add	sp, sp, #0x50
   82c3c:	d65f03c0 	ret
            {W("pitch %d x vheight %d!= mbox[29] %u", fbs->pitch, fbs->vheight, mbox[29]);BUG();}
   82c40:	b9407665 	ldr	w5, [x19, #116]
   82c44:	2a0703e4 	mov	w4, w7
   82c48:	2a0203e3 	mov	w3, w2
   82c4c:	913be313 	add	x19, x24, #0xef8
   82c50:	aa1303e1 	mov	x1, x19
   82c54:	528024c2 	mov	w2, #0x126                 	// #294
   82c58:	90000080 	adrp	x0, 92000 <get_el+0xd61c>
   82c5c:	911b6000 	add	x0, x0, #0x6d8
   82c60:	97fffa52 	bl	815a8 <tfp_printf>
   82c64:	528024c2 	mov	w2, #0x126                 	// #294
   82c68:	aa1303e1 	mov	x1, x19
   82c6c:	d0000000 	adrp	x0, 84000 <vectors>
   82c70:	912ac000 	add	x0, x0, #0xab0
   82c74:	97fffb1b 	bl	818e0 <assertion_failed>
   82c78:	29421e86 	ldp	w6, w7, [x20, #16]
   82c7c:	b9401a82 	ldr	w2, [x20, #24]
   82c80:	29411684 	ldp	w4, w5, [x20, #8]
   82c84:	b9402a88 	ldr	w8, [x20, #40]
   82c88:	1b077c40 	mul	w0, w2, w7
   82c8c:	17ffffd6 	b	82be4 <fb_init+0x1a4>
        {fb_showpicture(); once=0;}
   82c90:	97fffefe 	bl	82888 <fb_showpicture>
   82c94:	b9003abf 	str	wzr, [x21, #56]
    return 0;
   82c98:	52800000 	mov	w0, #0x0                   	// #0
}
   82c9c:	a9417bfd 	ldp	x29, x30, [sp, #16]
   82ca0:	a94253f3 	ldp	x19, x20, [sp, #32]
   82ca4:	a9435bf5 	ldp	x21, x22, [sp, #48]
   82ca8:	a94463f7 	ldp	x23, x24, [sp, #64]
   82cac:	910143ff 	add	sp, sp, #0x50
   82cb0:	d65f03c0 	ret
        E("Unable to set scr res to %d x %d\n", fbs->width, fbs->height);
   82cb4:	9114e2b5 	add	x21, x21, #0x538
   82cb8:	d0000001 	adrp	x1, 84000 <vectors>
   82cbc:	90000080 	adrp	x0, 92000 <get_el+0xd61c>
   82cc0:	913be021 	add	x1, x1, #0xef8
   82cc4:	911d8000 	add	x0, x0, #0x760
   82cc8:	52802582 	mov	w2, #0x12c                 	// #300
   82ccc:	294112a3 	ldp	w3, w4, [x21, #8]
   82cd0:	97fffa36 	bl	815a8 <tfp_printf>
        return -2; 
   82cd4:	12800020 	mov	w0, #0xfffffffe            	// #-2
   82cd8:	17ffffd4 	b	82c28 <fb_init+0x1e8>
   82cdc:	00000000 	udf	#0

0000000000082ce0 <canvas_init>:
static inline void setpixel(unsigned char *buf, int x, int y, int pit, PIXEL p) {
    assert(x >= 0 && y >= 0);
    *(PIXEL *)(buf + y * pit + x * PIXELSIZE) = p;
}

static void canvas_init(void) {
   82ce0:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
   82ce4:	910003fd 	mov	x29, sp
    fb_fini();
   82ce8:	97fffe6a 	bl	82690 <fb_fini>
    // acquire(&mboxlock);      //it's a test. so no lock

    the_fb.width = NN;
   82cec:	b0000080 	adrp	x0, 93000 <get_el+0xe61c>
   82cf0:	d2805001 	mov	x1, #0x280                 	// #640
   82cf4:	f2c05001 	movk	x1, #0x280, lsl #32
   82cf8:	f9474000 	ldr	x0, [x0, #3712]
    the_fb.height = NN;

    the_fb.vwidth = NN;
   82cfc:	a9008401 	stp	x1, x1, [x0, #8]
    the_fb.vheight = NN;

    if (fb_init() != 0)
   82d00:	97ffff50 	bl	82a40 <fb_init>
   82d04:	35000060 	cbnz	w0, 82d10 <canvas_init+0x30>
        BUG();
}
   82d08:	a8c17bfd 	ldp	x29, x30, [sp], #16
   82d0c:	d65f03c0 	ret
   82d10:	a8c17bfd 	ldp	x29, x30, [sp], #16
        BUG();
   82d14:	90000081 	adrp	x1, 92000 <get_el+0xd61c>
   82d18:	d0000000 	adrp	x0, 84000 <vectors>
   82d1c:	911ea021 	add	x1, x1, #0x7a8
   82d20:	912ac000 	add	x0, x0, #0xab0
   82d24:	528004a2 	mov	w2, #0x25                  	// #37
   82d28:	17fffaee 	b	818e0 <assertion_failed>
   82d2c:	d503201f 	nop

0000000000082d30 <draw_frame>:
static int _;

static PIXEL int2rgb (int value); 

// ktimer callback. NB: called in irq context
static int draw_frame(TKernelTimerHandle hTimer, void *param, void *context) {    
   82d30:	a9b97bfd 	stp	x29, x30, [sp, #-112]!
    memset(b, 0, 1760);  // text buffer 0: black bkgnd
   82d34:	d0000080 	adrp	x0, 94000 <timers+0xf0>
   82d38:	9108c003 	add	x3, x0, #0x230
static int draw_frame(TKernelTimerHandle hTimer, void *param, void *context) {    
   82d3c:	910003fd 	mov	x29, sp
    memset(b, 0, 1760);  // text buffer 0: black bkgnd
   82d40:	aa0303e0 	mov	x0, x3
   82d44:	5280dc02 	mov	w2, #0x6e0                 	// #1760
   82d48:	52800001 	mov	w1, #0x0                   	// #0
static int draw_frame(TKernelTimerHandle hTimer, void *param, void *context) {    
   82d4c:	a90153f3 	stp	x19, x20, [sp, #16]
   82d50:	a9025bf5 	stp	x21, x22, [sp, #32]
   82d54:	52801ff6 	mov	w22, #0xff                  	// #255
   82d58:	a90363f7 	stp	x23, x24, [sp, #48]
    memset(z, 127, 1760); // z buffer
   82d5c:	911b8078 	add	x24, x3, #0x6e0
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
                y = 12 + 15 * (cB * x4 + sB * x1) / x6,
                // N = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5) >> 7;
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
                // range likely: <0..~1408, scale to 0..255
                lumince = lumince<0? 0 : lumince/5; 
   82d60:	528cccf7 	mov	w23, #0x6667                	// #26215
static int draw_frame(TKernelTimerHandle hTimer, void *param, void *context) {    
   82d64:	a9046bf9 	stp	x25, x26, [sp, #64]
                lumince = lumince<0? 0 : lumince/5; 
   82d68:	72acccd7 	movk	w23, #0x6666, lsl #16
    int sj = 0, cj = 1024;
   82d6c:	52808019 	mov	w25, #0x400                 	// #1024
static int draw_frame(TKernelTimerHandle hTimer, void *param, void *context) {    
   82d70:	a90573fb 	stp	x27, x28, [sp, #80]
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82d74:	52800b5c 	mov	w28, #0x5a                  	// #90
    int sj = 0, cj = 1024;
   82d78:	5280001b 	mov	w27, #0x0                   	// #0
    memset(z, 127, 1760); // z buffer
   82d7c:	f90037e3 	str	x3, [sp, #104]
    memset(b, 0, 1760);  // text buffer 0: black bkgnd
   82d80:	97fffae4 	bl	81910 <memset>
    memset(z, 127, 1760); // z buffer
   82d84:	52800fe1 	mov	w1, #0x7f                  	// #127
   82d88:	aa1803e0 	mov	x0, x24
   82d8c:	5280dc02 	mov	w2, #0x6e0                 	// #1760
   82d90:	97fffae0 	bl	81910 <memset>
                x2 = cA * sj >> 10,
   82d94:	f94037e3 	ldr	x3, [sp, #104]
                x4 = R1 * x2 - (sA * x3 >> 10),
   82d98:	b0000080 	adrp	x0, 93000 <get_el+0xe61c>
   82d9c:	b0000081 	adrp	x1, 93000 <get_el+0xe61c>
   82da0:	9115d000 	add	x0, x0, #0x574
                lumince = lumince<255? lumince : 255; 

            int o = x + 80 * y; // fxl: 80 chars per row
            signed char zz = (x6 - K2) >> 15;
            if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) { // fxl: z depth will control visibility
   82da4:	aa0303fa 	mov	x26, x3
                // now we lookup the character corresponding to the
                // luminance and plot it in our output:
                // b[o] = ".,-~:;=!*#$@"[N > 0 ? N : 0];
                b[o] = lumince;                    
            }
            R(5, 8, ci, si) // rotate i
   82da8:	52a00612 	mov	w18, #0x300000              	// #3145728
                x4 = R1 * x2 - (sA * x3 >> 10),
   82dac:	b945743e 	ldr	w30, [x1, #1396]
                x2 = cA * sj >> 10,
   82db0:	b94dc073 	ldr	w19, [x3, #3520]
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82db4:	b940040e 	ldr	w14, [x0, #4]
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82db8:	4b1e03f4 	neg	w20, w30
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82dbc:	b94dc46b 	ldr	w11, [x3, #3524]
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82dc0:	4b1303f5 	neg	w21, w19
                x5 = sA * sj >> 10,
   82dc4:	1b1b7fc7 	mul	w7, w30, w27
        int si = 0, ci = 1024; // sine and cosine of angle i
   82dc8:	52808000 	mov	w0, #0x400                 	// #1024
                x2 = cA * sj >> 10,
   82dcc:	1b1b7e68 	mul	w8, w19, w27
   82dd0:	11200329 	add	w9, w25, #0x800
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82dd4:	1b197dca 	mul	w10, w14, w25
                x6 = K2 + R1 * 1024 * x5 + cA * x3,
   82dd8:	121654ec 	and	w12, w7, #0xfffffc00
   82ddc:	1154018c 	add	w12, w12, #0x500, lsl #12
                x5 = sA * sj >> 10,
   82de0:	130a7ce7 	asr	w7, w7, #10
                x2 = cA * sj >> 10,
   82de4:	130a7d08 	asr	w8, w8, #10
   82de8:	2a0003ed 	mov	w13, w0
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82dec:	130a7d4a 	asr	w10, w10, #10
   82df0:	52802886 	mov	w6, #0x144                 	// #324
        int si = 0, ci = 1024; // sine and cosine of angle i
   82df4:	52800001 	mov	w1, #0x0                   	// #0
                x3 = si * x0 >> 10,
   82df8:	1b097c23 	mul	w3, w1, w9
            R(5, 8, ci, si) // rotate i
   82dfc:	0b010830 	add	w16, w1, w1, lsl #2
                x1 = ci * x0 >> 10,
   82e00:	1b097db1 	mul	w17, w13, w9
            R(5, 8, ci, si) // rotate i
   82e04:	0b0d09a2 	add	w2, w13, w13, lsl #2
   82e08:	4b9021b0 	sub	w16, w13, w16, asr #8
                x7 = cj * si >> 10,
   82e0c:	4b012c64 	sub	w4, w3, w1, lsl #11
                x3 = si * x0 >> 10,
   82e10:	130a7c63 	asr	w3, w3, #10
            R(5, 8, ci, si) // rotate i
   82e14:	0b822021 	add	w1, w1, w2, asr #8
                x1 = ci * x0 >> 10,
   82e18:	130a7e31 	asr	w17, w17, #10
                x7 = cj * si >> 10,
   82e1c:	130a7c84 	asr	w4, w4, #10
            R(5, 8, ci, si) // rotate i
   82e20:	1b10ca02 	msub	w2, w16, w16, w18
                x4 = R1 * x2 - (sA * x3 >> 10),
   82e24:	1b037fc5 	mul	w5, w30, w3
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82e28:	1b117d6f 	mul	w15, w11, w17
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82e2c:	1b047e80 	mul	w0, w20, w4
                x4 = R1 * x2 - (sA * x3 >> 10),
   82e30:	4b852905 	sub	w5, w8, w5, asr #10
            R(5, 8, ci, si) // rotate i
   82e34:	1b018822 	msub	w2, w1, w1, w2
                y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   82e38:	1b117dd1 	mul	w17, w14, w17
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82e3c:	0b802900 	add	w0, w8, w0, asr #10
   82e40:	1b047ea4 	mul	w4, w21, w4
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82e44:	1b05bdcf 	msub	w15, w14, w5, w15
            R(5, 8, ci, si) // rotate i
   82e48:	130b7c42 	asr	w2, w2, #11
                y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   82e4c:	1b054565 	madd	w5, w11, w5, w17
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82e50:	1b0b9000 	msub	w0, w0, w11, w4
   82e54:	52800004 	mov	w4, #0x0                   	// #0
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82e58:	531c6df1 	lsl	w17, w15, #4
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82e5c:	1b0d8140 	msub	w0, w10, w13, w0
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82e60:	4b0f022f 	sub	w15, w17, w15
                x6 = K2 + R1 * 1024 * x5 + cA * x3,
   82e64:	1b033263 	madd	w3, w19, w3, w12
                y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   82e68:	531c6cb1 	lsl	w17, w5, #4
            R(5, 8, ci, si) // rotate i
   82e6c:	1b107c4d 	mul	w13, w2, w16
                y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   82e70:	4b050225 	sub	w5, w17, w5
                lumince = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5); 
   82e74:	130a7c00 	asr	w0, w0, #10
            R(5, 8, ci, si) // rotate i
   82e78:	1b017c41 	mul	w1, w2, w1
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82e7c:	531f79ef 	lsl	w15, w15, #1
                lumince = lumince<0? 0 : lumince/5; 
   82e80:	6b070000 	subs	w0, w0, w7
            R(5, 8, ci, si) // rotate i
   82e84:	130a7dad 	asr	w13, w13, #10
                y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   82e88:	1ac30ca5 	sdiv	w5, w5, w3
                lumince = lumince<0? 0 : lumince/5; 
   82e8c:	540000c4 	b.mi	82ea4 <draw_frame+0x174>  // b.first
   82e90:	9b377c04 	smull	x4, w0, w23
   82e94:	9361fc84 	asr	x4, x4, #33
   82e98:	4b807c84 	sub	w4, w4, w0, asr #31
   82e9c:	7103fc9f 	cmp	w4, #0xff
   82ea0:	1a96d084 	csel	w4, w4, w22, le
            if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) { // fxl: z depth will control visibility
   82ea4:	11002ca0 	add	w0, w5, #0xb
            R(5, 8, ci, si) // rotate i
   82ea8:	130a7c21 	asr	w1, w1, #10
            if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) { // fxl: z depth will control visibility
   82eac:	7100501f 	cmp	w0, #0x14
   82eb0:	54000208 	b.hi	82ef0 <draw_frame+0x1c0>  // b.pmore
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82eb4:	1ac30def 	sdiv	w15, w15, w3
                y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   82eb8:	110030a2 	add	w2, w5, #0xc
            signed char zz = (x6 - K2) >> 15;
   82ebc:	51540063 	sub	w3, w3, #0x500, lsl #12
            int o = x + 80 * y; // fxl: 80 chars per row
   82ec0:	0b020842 	add	w2, w2, w2, lsl #2
            signed char zz = (x6 - K2) >> 15;
   82ec4:	934f5863 	sbfx	x3, x3, #15, #8
                x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   82ec8:	110065e0 	add	w0, w15, #0x19
            if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) { // fxl: z depth will control visibility
   82ecc:	110061ef 	add	w15, w15, #0x18
   82ed0:	710139ff 	cmp	w15, #0x4e
   82ed4:	540000e8 	b.hi	82ef0 <draw_frame+0x1c0>  // b.pmore
            int o = x + 80 * y; // fxl: 80 chars per row
   82ed8:	0b021002 	add	w2, w0, w2, lsl #4
            if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) { // fxl: z depth will control visibility
   82edc:	38e2cb00 	ldrsb	w0, [x24, w2, sxtw]
   82ee0:	6b03001f 	cmp	w0, w3
   82ee4:	5400006d 	b.le	82ef0 <draw_frame+0x1c0>
                z[o] = zz;
   82ee8:	3822cb03 	strb	w3, [x24, w2, sxtw]
                b[o] = lumince;                    
   82eec:	3822cb44 	strb	w4, [x26, w2, sxtw]
        for (int i = 0; i < 324; i++) {
   82ef0:	710004c6 	subs	w6, w6, #0x1
   82ef4:	54fff821 	b.ne	82df8 <draw_frame+0xc8>  // b.any
        }
        R(9, 7, cj, sj) // rotate j
   82ef8:	0b1b0f60 	add	w0, w27, w27, lsl #3
   82efc:	0b190f21 	add	w1, w25, w25, lsl #3
    for (int j = 0; j < 90; j++) {
   82f00:	7100079c 	subs	w28, w28, #0x1
        R(9, 7, cj, sj) // rotate j
   82f04:	4b801f39 	sub	w25, w25, w0, asr #7
   82f08:	0b811f7b 	add	w27, w27, w1, asr #7
   82f0c:	1b19cb20 	msub	w0, w25, w25, w18
   82f10:	1b1b8360 	msub	w0, w27, w27, w0
   82f14:	130b7c00 	asr	w0, w0, #11
   82f18:	1b197c19 	mul	w25, w0, w25
   82f1c:	1b1b7c00 	mul	w0, w0, w27
   82f20:	130a7f39 	asr	w25, w25, #10
   82f24:	130a7c1b 	asr	w27, w0, #10
    for (int j = 0; j < 90; j++) {
   82f28:	54fff4e1 	b.ne	82dc4 <draw_frame+0x94>  // b.any
    }
    R(5, 7, cA, sA);
    R(5, 8, cB, sB);
   82f2c:	0b0e09c0 	add	w0, w14, w14, lsl #2
    R(5, 7, cA, sA);
   82f30:	0b1e0bc1 	add	w1, w30, w30, lsl #2
    R(5, 8, cB, sB);
   82f34:	0b0b0962 	add	w2, w11, w11, lsl #2
    R(5, 7, cA, sA);
   82f38:	0b130a63 	add	w3, w19, w19, lsl #2
    R(5, 8, cB, sB);
   82f3c:	4b80216b 	sub	w11, w11, w0, asr #8
    R(5, 7, cA, sA);
   82f40:	4b811e73 	sub	w19, w19, w1, asr #7
    R(5, 8, cB, sB);
   82f44:	0b8221ce 	add	w14, w14, w2, asr #8
    R(5, 7, cA, sA);
   82f48:	d0000080 	adrp	x0, 94000 <timers+0xf0>
   82f4c:	0b831fde 	add	w30, w30, w3, asr #7
   82f50:	9108c00c 	add	x12, x0, #0x230
   82f54:	b0000080 	adrp	x0, 93000 <get_el+0xe61c>
   82f58:	9115d00d 	add	x13, x0, #0x574
    R(5, 8, cB, sB);
   82f5c:	1b0bc960 	msub	w0, w11, w11, w18
            if (x < 50) {
                // to display, scale x by K, y by 2K (so we have a round donut)
                int K=6, xx=x*K, yy=y*K*2;
                // PIXEL clr = b[k]; // blue only, simple
                PIXEL clr = int2rgb(b[k]); // to a color spectrum
                setpixel(the_fb.fb, xx, yy, the_fb.pitch, clr);
   82f60:	b000008a 	adrp	x10, 93000 <get_el+0xe61c>
    R(5, 7, cA, sA);
   82f64:	1b13ca69 	msub	w9, w19, w19, w18
                setpixel(the_fb.fb, xx, yy, the_fb.pitch, clr);
   82f68:	529999a5 	mov	w5, #0xcccd                	// #52429
    R(5, 8, cB, sB);
   82f6c:	1b0e81c0 	msub	w0, w14, w14, w0
        if (k % 80) {
   82f70:	52866664 	mov	w4, #0x3333                	// #13107
    R(5, 7, cA, sA);
   82f74:	1b1ea7c9 	msub	w9, w30, w30, w9
                PIXEL clr = int2rgb(b[k]); // to a color spectrum
   82f78:	aa0c03e7 	mov	x7, x12
                setpixel(the_fb.fb, xx, yy, the_fb.pitch, clr);
   82f7c:	f947414a 	ldr	x10, [x10, #3712]
    R(5, 8, cB, sB);
   82f80:	130b7c00 	asr	w0, w0, #11
    R(5, 7, cA, sA);
   82f84:	130b7d29 	asr	w9, w9, #11
                setpixel(the_fb.fb, xx, yy, the_fb.pitch, clr);
   82f88:	d2800001 	mov	x1, #0x0                   	// #0
   82f8c:	aa0a03e8 	mov	x8, x10
    int y = 0, x = 0;
   82f90:	52800002 	mov	w2, #0x0                   	// #0
    R(5, 8, cB, sB);
   82f94:	1b007d6b 	mul	w11, w11, w0
    int y = 0, x = 0;
   82f98:	52800003 	mov	w3, #0x0                   	// #0
    R(5, 7, cA, sA);
   82f9c:	1b097fde 	mul	w30, w30, w9
                setpixel(the_fb.fb, xx, yy, the_fb.pitch, clr);
   82fa0:	72b99985 	movk	w5, #0xcccc, lsl #16
    R(5, 7, cA, sA);
   82fa4:	1b097e73 	mul	w19, w19, w9
        if (k % 80) {
   82fa8:	72a06664 	movk	w4, #0x333, lsl #16
    R(5, 8, cB, sB);
   82fac:	1b007dce 	mul	w14, w14, w0
   82fb0:	130a7d60 	asr	w0, w11, #10
    R(5, 7, cA, sA);
   82fb4:	b000008b 	adrp	x11, 93000 <get_el+0xe61c>
   82fb8:	130a7fc9 	asr	w9, w30, #10
                setpixel(the_fb.fb, xx, yy, the_fb.pitch, clr);
   82fbc:	f940014a 	ldr	x10, [x10]
    R(5, 7, cA, sA);
   82fc0:	130a7e66 	asr	w6, w19, #10
   82fc4:	b9057569 	str	w9, [x11, #1396]
    R(5, 8, cB, sB);
   82fc8:	130a7dc9 	asr	w9, w14, #10
   82fcc:	b90005a9 	str	w9, [x13, #4]
    R(5, 7, cA, sA);
   82fd0:	b90dc186 	str	w6, [x12, #3520]
    R(5, 8, cB, sB);
   82fd4:	b90dc580 	str	w0, [x12, #3524]
                setpixel(the_fb.fb, xx, yy, the_fb.pitch, clr);
   82fd8:	1b057c20 	mul	w0, w1, w5
   82fdc:	13801000 	ror	w0, w0, #4
        if (k % 80) {
   82fe0:	6b04001f 	cmp	w0, w4
   82fe4:	54000589 	b.ls	83094 <draw_frame+0x364>  // b.plast
            if (x < 50) {
   82fe8:	7100c45f 	cmp	w2, #0x31
   82fec:	540001ad 	b.le	83020 <draw_frame+0x2f0>
                setpixel(the_fb.fb, xx+1, yy, the_fb.pitch, clr);
                setpixel(the_fb.fb, xx, yy+1, the_fb.pitch, clr);
                setpixel(the_fb.fb, xx+1, yy+1, the_fb.pitch, clr);
            }
            x++;
   82ff0:	11000442 	add	w2, w2, #0x1
    for (int k = 0; 1761 > k; k++) {
   82ff4:	91000421 	add	x1, x1, #0x1
   82ff8:	f11b843f 	cmp	x1, #0x6e1
   82ffc:	54fffee1 	b.ne	82fd8 <draw_frame+0x2a8>  // b.any
            x = 1;
        }
    }

    return 1; // restart timer 
}
   83000:	52800020 	mov	w0, #0x1                   	// #1
   83004:	a94153f3 	ldp	x19, x20, [sp, #16]
   83008:	a9425bf5 	ldp	x21, x22, [sp, #32]
   8300c:	a94363f7 	ldp	x23, x24, [sp, #48]
   83010:	a9446bf9 	ldp	x25, x26, [sp, #64]
   83014:	a94573fb 	ldp	x27, x28, [sp, #80]
   83018:	a8c77bfd 	ldp	x29, x30, [sp], #112
   8301c:	d65f03c0 	ret
                int K=6, xx=x*K, yy=y*K*2;
   83020:	531f7849 	lsl	w9, w2, #1
                PIXEL clr = int2rgb(b[k]); // to a color spectrum
   83024:	38676820 	ldrb	w0, [x1, x7]
                int K=6, xx=x*K, yy=y*K*2;
   83028:	0b03046b 	add	w11, w3, w3, lsl #1
   8302c:	0b020126 	add	w6, w9, w2

// map luminance [0..255] to rgb color
// value: 0..255, PIXEL: argb
static PIXEL int2rgb (int value) {
    int r,g,b;     
    if (value >= 0 && value <= 85) {
   83030:	7101541f 	cmp	w0, #0x55
                int K=6, xx=x*K, yy=y*K*2;
   83034:	531e756b 	lsl	w11, w11, #2
   83038:	531f78c6 	lsl	w6, w6, #1
    if (value >= 0 && value <= 85) {
   8303c:	54000328 	b.hi	830a0 <draw_frame+0x370>  // b.pmore
        // Black to Yellow (R stays 0, G increases, B stays 0)
        r = 0;
        g = (value * 3);
   83040:	0b000400 	add	w0, w0, w0, lsl #1
   83044:	53185c00 	lsl	w0, w0, #8
    *(PIXEL *)(buf + y * pit + x * PIXELSIZE) = p;
   83048:	b940190c 	ldr	w12, [x8, #24]
   8304c:	0b020129 	add	w9, w9, w2
                setpixel(the_fb.fb, xx+1, yy, the_fb.pitch, clr);
   83050:	110004c6 	add	w6, w6, #0x1
    *(PIXEL *)(buf + y * pit + x * PIXELSIZE) = p;
   83054:	531d7129 	lsl	w9, w9, #3
   83058:	531e74c6 	lsl	w6, w6, #2
   8305c:	1b0c7d6c 	mul	w12, w11, w12
   83060:	8b29c149 	add	x9, x10, w9, sxtw
   83064:	8b26c146 	add	x6, x10, w6, sxtw
   83068:	b82cc920 	str	w0, [x9, w12, sxtw]
   8306c:	b940190c 	ldr	w12, [x8, #24]
   83070:	1b0c7d6c 	mul	w12, w11, w12
   83074:	b82cc8c0 	str	w0, [x6, w12, sxtw]
   83078:	b940190c 	ldr	w12, [x8, #24]
   8307c:	1b0c316c 	madd	w12, w11, w12, w12
   83080:	b82cc920 	str	w0, [x9, w12, sxtw]
   83084:	b9401909 	ldr	w9, [x8, #24]
   83088:	1b092569 	madd	w9, w11, w9, w9
   8308c:	b829c8c0 	str	w0, [x6, w9, sxtw]
}
   83090:	17ffffd8 	b	82ff0 <draw_frame+0x2c0>
            y++;
   83094:	11000463 	add	w3, w3, #0x1
            x = 1;
   83098:	52800022 	mov	w2, #0x1                   	// #1
   8309c:	17ffffd6 	b	82ff4 <draw_frame+0x2c4>
        b = 0;
    } else if (value > 85 && value <= 170) {
   830a0:	5101580c 	sub	w12, w0, #0x56
   830a4:	7101519f 	cmp	w12, #0x54
   830a8:	54000108 	b.hi	830c8 <draw_frame+0x398>  // b.pmore
        // Yellow to Cyan (G stays 255, R decreases, B increases)
        r = 255 - ((value - 85) * 3);
   830ac:	51015400 	sub	w0, w0, #0x55
   830b0:	4b00080c 	sub	w12, w0, w0, lsl #2
        g = 255;
        b = (value - 85) * 3;
   830b4:	0b000400 	add	w0, w0, w0, lsl #1
        r = 255 - ((value - 85) * 3);
   830b8:	1103fd8c 	add	w12, w12, #0xff
   830bc:	2a0c4000 	orr	w0, w0, w12, lsl #16
   830c0:	32181c00 	orr	w0, w0, #0xff00
   830c4:	17ffffe1 	b	83048 <draw_frame+0x318>
    } else if (value > 170 && value <= 255) {
        // Cyan to Blue (G decreases, B stays 255, R stays 0)
        r = 0;
        g = 255 - ((value - 170) * 3);
   830c8:	5102a800 	sub	w0, w0, #0xaa
   830cc:	4b000800 	sub	w0, w0, w0, lsl #2
   830d0:	1103fc00 	add	w0, w0, #0xff
   830d4:	53185c00 	lsl	w0, w0, #8
   830d8:	32001c00 	orr	w0, w0, #0xff
   830dc:	17ffffdb 	b	83048 <draw_frame+0x318>

00000000000830e0 <donut>:
void donut(void) {
   830e0:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
   830e4:	910003fd 	mov	x29, sp
    canvas_init();
   830e8:	97fffefe 	bl	82ce0 <canvas_init>
    ret = ktimer_start(100, /*firing interval, ms*/
   830ec:	f0ffffe1 	adrp	x1, 82000 <us_delay+0x10>
   830f0:	d2800003 	mov	x3, #0x0                   	// #0
   830f4:	9134c021 	add	x1, x1, #0xd30
   830f8:	d2800002 	mov	x2, #0x0                   	// #0
   830fc:	52800c80 	mov	w0, #0x64                  	// #100
   83100:	97fffbfe 	bl	820f8 <ktimer_start>
    BUG_ON(ret<0);     
   83104:	37f80060 	tbnz	w0, #31, 83110 <donut+0x30>
}
   83108:	a8c17bfd 	ldp	x29, x30, [sp], #16
   8310c:	d65f03c0 	ret
   83110:	a8c17bfd 	ldp	x29, x30, [sp], #16
    BUG_ON(ret<0);     
   83114:	f0000061 	adrp	x1, 92000 <get_el+0xd61c>
   83118:	f0000060 	adrp	x0, 92000 <get_el+0xd61c>
   8311c:	911ea021 	add	x1, x1, #0x7a8
   83120:	911ec000 	add	x0, x0, #0x7b0
   83124:	52801022 	mov	w2, #0x81                  	// #129
   83128:	17fff9ee 	b	818e0 <assertion_failed>
   8312c:	d503201f 	nop

0000000000083130 <donut_simple>:
void donut_simple(void) {
   83130:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
   83134:	910003fd 	mov	x29, sp
    canvas_init();
   83138:	97fffeea 	bl	82ce0 <canvas_init>
    put32(TIMER_C1, 100 * 1000);	// in us
   8313c:	d2860200 	mov	x0, #0x3010                	// #12304
   83140:	5290d401 	mov	w1, #0x86a0                	// #34464
   83144:	f2a7e000 	movk	x0, #0x3f00, lsl #16
   83148:	72a00021 	movk	w1, #0x1, lsl #16
   8314c:	b9000001 	str	w1, [x0]
}
   83150:	a8c17bfd 	ldp	x29, x30, [sp], #16
   83154:	d65f03c0 	ret

0000000000083158 <sys_timer_irq_simple>:
    BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   83158:	d2860000 	mov	x0, #0x3000                	// #12288
{
   8315c:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
    BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   83160:	f2a7e000 	movk	x0, #0x3f00, lsl #16
{
   83164:	910003fd 	mov	x29, sp
    BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   83168:	b9400000 	ldr	w0, [x0]
   8316c:	36080160 	tbz	w0, #1, 83198 <sys_timer_irq_simple+0x40>
	put32(TIMER_CS, TIMER_CS_M1);	// clear timer1 match
   83170:	d2860000 	mov	x0, #0x3000                	// #12288
   83174:	52800043 	mov	w3, #0x2                   	// #2
   83178:	f2a7e000 	movk	x0, #0x3f00, lsl #16
    draw_frame(0, 0, 0); 
   8317c:	d2800002 	mov	x2, #0x0                   	// #0
   83180:	d2800001 	mov	x1, #0x0                   	// #0
	put32(TIMER_CS, TIMER_CS_M1);	// clear timer1 match
   83184:	b9000003 	str	w3, [x0]
    draw_frame(0, 0, 0); 
   83188:	d2800000 	mov	x0, #0x0                   	// #0
   8318c:	97fffee9 	bl	82d30 <draw_frame>
}
   83190:	a8c17bfd 	ldp	x29, x30, [sp], #16
    cur = current_counter(); 
   83194:	17fffb7d 	b	81f88 <current_counter>
    BUG_ON(!(get32(TIMER_CS) & TIMER_CS_M1));  
   83198:	f0000061 	adrp	x1, 92000 <get_el+0xd61c>
   8319c:	b0000000 	adrp	x0, 84000 <vectors>
   831a0:	911ea021 	add	x1, x1, #0x7a8
   831a4:	913aa000 	add	x0, x0, #0xea8
   831a8:	52801302 	mov	w2, #0x98                  	// #152
   831ac:	97fff9cd 	bl	818e0 <assertion_failed>
   831b0:	17fffff0 	b	83170 <sys_timer_irq_simple+0x18>
   831b4:	d503201f 	nop

00000000000831b8 <donut_text>:
void donut_text(void) {
   831b8:	a9ba7bfd 	stp	x29, x30, [sp, #-96]!
   831bc:	910003fd 	mov	x29, sp
   831c0:	a9046bf9 	stp	x25, x26, [sp, #64]
   831c4:	b0000099 	adrp	x25, 94000 <timers+0xf0>
        memset(b, 32, 1760);  // text buffer
   831c8:	9108c339 	add	x25, x25, #0x230
void donut_text(void) {
   831cc:	a9025bf5 	stp	x21, x22, [sp, #32]
    int sA = 1024, cA = 0, sB = 1024, cB = 0, _;
   831d0:	52808015 	mov	w21, #0x400                 	// #1024
   831d4:	52800016 	mov	w22, #0x0                   	// #0
void donut_text(void) {
   831d8:	a90363f7 	stp	x23, x24, [sp, #48]
        memset(z, 127, 1760); // z buffer
   831dc:	911b8338 	add	x24, x25, #0x6e0
    int sA = 1024, cA = 0, sB = 1024, cB = 0, _;
   831e0:	2a1503f7 	mov	w23, w21
void donut_text(void) {
   831e4:	a90153f3 	stp	x19, x20, [sp, #16]
    int sA = 1024, cA = 0, sB = 1024, cB = 0, _;
   831e8:	52800014 	mov	w20, #0x0                   	// #0
   831ec:	f0000073 	adrp	x19, 92000 <get_el+0xd61c>
void donut_text(void) {
   831f0:	a90573fb 	stp	x27, x28, [sp, #80]
        memset(b, 32, 1760);  // text buffer
   831f4:	5280dc02 	mov	w2, #0x6e0                 	// #1760
   831f8:	52800401 	mov	w1, #0x20                  	// #32
   831fc:	aa1903e0 	mov	x0, x25
   83200:	97fff9c4 	bl	81910 <memset>
        memset(z, 127, 1760); // z buffer
   83204:	4b1603fc 	neg	w28, w22
   83208:	aa1803e0 	mov	x0, x24
   8320c:	5280dc02 	mov	w2, #0x6e0                 	// #1760
   83210:	52800fe1 	mov	w1, #0x7f                  	// #127
   83214:	4b1703fb 	neg	w27, w23
   83218:	97fff9be 	bl	81910 <memset>
                    b[o] = ".,-~:;=!*#$@"[N > 0 ? N : 0];
   8321c:	911f227a 	add	x26, x19, #0x7c8
        memset(z, 127, 1760); // z buffer
   83220:	52800b5e 	mov	w30, #0x5a                  	// #90
        int sj = 0, cj = 1024;
   83224:	52808012 	mov	w18, #0x400                 	// #1024
   83228:	52800011 	mov	w17, #0x0                   	// #0
                R(5, 8, ci, si) // rotate i
   8322c:	52a0060e 	mov	w14, #0x300000              	// #3145728
                    x5 = sA * sj >> 10,
   83230:	1b117eef 	mul	w15, w23, w17
   83234:	1120024b 	add	w11, w18, #0x800
                    x2 = cA * sj >> 10,
   83238:	1b117ecc 	mul	w12, w22, w17
                    N = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5) >> 7;
   8323c:	5280288a 	mov	w10, #0x144                 	// #324
   83240:	1b127eb0 	mul	w16, w21, w18
                    x6 = K2 + R1 * 1024 * x5 + cA * x3,
   83244:	121655ed 	and	w13, w15, #0xfffffc00
   83248:	115401ad 	add	w13, w13, #0x500, lsl #12
                    x5 = sA * sj >> 10,
   8324c:	130a7def 	asr	w15, w15, #10
                    x2 = cA * sj >> 10,
   83250:	130a7d8c 	asr	w12, w12, #10
            int si = 0, ci = 1024; // sine and cosine of angle i
   83254:	52808007 	mov	w7, #0x400                 	// #1024
                    N = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5) >> 7;
   83258:	130a7e10 	asr	w16, w16, #10
            int si = 0, ci = 1024; // sine and cosine of angle i
   8325c:	52800003 	mov	w3, #0x0                   	// #0
                    x3 = si * x0 >> 10,
   83260:	1b0b7c69 	mul	w9, w3, w11
                R(5, 8, ci, si) // rotate i
   83264:	0b030860 	add	w0, w3, w3, lsl #2
                    x1 = ci * x0 >> 10,
   83268:	1b0b7ce2 	mul	w2, w7, w11
                R(5, 8, ci, si) // rotate i
   8326c:	0b0708e4 	add	w4, w7, w7, lsl #2
   83270:	4b8020e0 	sub	w0, w7, w0, asr #8
                    x3 = si * x0 >> 10,
   83274:	130a7d26 	asr	w6, w9, #10
                R(5, 8, ci, si) // rotate i
   83278:	0b842064 	add	w4, w3, w4, asr #8
                    x1 = ci * x0 >> 10,
   8327c:	130a7c42 	asr	w2, w2, #10
                R(5, 8, ci, si) // rotate i
   83280:	1b00b801 	msub	w1, w0, w0, w14
                    x4 = R1 * x2 - (sA * x3 >> 10),
   83284:	1b067ee5 	mul	w5, w23, w6
                    x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   83288:	1b027e88 	mul	w8, w20, w2
                    y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   8328c:	1b027ea2 	mul	w2, w21, w2
                    x4 = R1 * x2 - (sA * x3 >> 10),
   83290:	4b852985 	sub	w5, w12, w5, asr #10
                    x6 = K2 + R1 * 1024 * x5 + cA * x3,
   83294:	1b0636c6 	madd	w6, w22, w6, w13
                R(5, 8, ci, si) // rotate i
   83298:	1b048481 	msub	w1, w4, w4, w1
                    x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   8329c:	1b05a2a8 	msub	w8, w21, w5, w8
                    y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   832a0:	1b050a82 	madd	w2, w20, w5, w2
                R(5, 8, ci, si) // rotate i
   832a4:	130b7c21 	asr	w1, w1, #11
                    x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   832a8:	531c6d05 	lsl	w5, w8, #4
   832ac:	4b0800a8 	sub	w8, w5, w8
                    y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   832b0:	531c6c45 	lsl	w5, w2, #4
   832b4:	4b0200a2 	sub	w2, w5, w2
                R(5, 8, ci, si) // rotate i
   832b8:	1b017c00 	mul	w0, w0, w1
   832bc:	1b017c81 	mul	w1, w4, w1
                    x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   832c0:	531f7908 	lsl	w8, w8, #1
                    y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   832c4:	1ac60c42 	sdiv	w2, w2, w6
                if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) {
   832c8:	11002c44 	add	w4, w2, #0xb
   832cc:	7100509f 	cmp	w4, #0x14
   832d0:	540003c8 	b.hi	83348 <donut_text+0x190>  // b.pmore
                    x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   832d4:	1ac60d08 	sdiv	w8, w8, w6
                    y = 12 + 15 * (cB * x4 + sB * x1) / x6,
   832d8:	11003042 	add	w2, w2, #0xc
                signed char zz = (x6 - K2) >> 15;
   832dc:	515400c4 	sub	w4, w6, #0x500, lsl #12
                int o = x + 80 * y; // fxl: 80 chars per row
   832e0:	0b020842 	add	w2, w2, w2, lsl #2
                signed char zz = (x6 - K2) >> 15;
   832e4:	934f5884 	sbfx	x4, x4, #15, #8
                    x = 25 + 30 * (cB * x1 - sB * x4) / x6,
   832e8:	11006505 	add	w5, w8, #0x19
                if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) {
   832ec:	11006108 	add	w8, w8, #0x18
                int o = x + 80 * y; // fxl: 80 chars per row
   832f0:	0b0210a2 	add	w2, w5, w2, lsl #4
                if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) {
   832f4:	7101391f 	cmp	w8, #0x4e
   832f8:	54000288 	b.hi	83348 <donut_text+0x190>  // b.pmore
   832fc:	38e2cb05 	ldrsb	w5, [x24, w2, sxtw]
                    x7 = cj * si >> 10,
   83300:	4b032d23 	sub	w3, w9, w3, lsl #11
                if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) {
   83304:	6b0400bf 	cmp	w5, w4
                    x7 = cj * si >> 10,
   83308:	130a7c63 	asr	w3, w3, #10
                if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) {
   8330c:	540001ed 	b.le	83348 <donut_text+0x190>
                    N = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5) >> 7;
   83310:	1b1b7c65 	mul	w5, w3, w27
                    z[o] = zz;
   83314:	3822cb04 	strb	w4, [x24, w2, sxtw]
                    N = (((-cA * x7 - cB * ((-sA * x7 >> 10) + x2) - ci * (cj * sB >> 10)) >> 10) - x5) >> 7;
   83318:	1b1c7c63 	mul	w3, w3, w28
   8331c:	0b852984 	add	w4, w12, w5, asr #10
   83320:	1b148c83 	msub	w3, w4, w20, w3
   83324:	1b078e03 	msub	w3, w16, w7, w3
   83328:	130a7c63 	asr	w3, w3, #10
   8332c:	4b0f0063 	sub	w3, w3, w15
   83330:	13077c63 	asr	w3, w3, #7
                    b[o] = ".,-~:;=!*#$@"[N > 0 ? N : 0];
   83334:	7100007f 	cmp	w3, #0x0
   83338:	1a9fa063 	csel	w3, w3, wzr, ge  // ge = tcont
   8333c:	3863cb43 	ldrb	w3, [x26, w3, sxtw]
   83340:	3822cb23 	strb	w3, [x25, w2, sxtw]
   83344:	d503201f 	nop
                R(5, 8, ci, si) // rotate i
   83348:	130a7c07 	asr	w7, w0, #10
   8334c:	130a7c23 	asr	w3, w1, #10
            for (int i = 0; i < 324; i++) {
   83350:	7100054a 	subs	w10, w10, #0x1
   83354:	54fff861 	b.ne	83260 <donut_text+0xa8>  // b.any
            R(9, 7, cj, sj) // rotate j
   83358:	0b110e21 	add	w1, w17, w17, lsl #3
   8335c:	0b120e40 	add	w0, w18, w18, lsl #3
        for (int j = 0; j < 90; j++) {
   83360:	710007de 	subs	w30, w30, #0x1
            R(9, 7, cj, sj) // rotate j
   83364:	4b811e52 	sub	w18, w18, w1, asr #7
   83368:	0b801e31 	add	w17, w17, w0, asr #7
   8336c:	1b12ba40 	msub	w0, w18, w18, w14
   83370:	1b118220 	msub	w0, w17, w17, w0
   83374:	130b7c00 	asr	w0, w0, #11
   83378:	1b007e52 	mul	w18, w18, w0
   8337c:	1b007e31 	mul	w17, w17, w0
   83380:	130a7e52 	asr	w18, w18, #10
   83384:	130a7e31 	asr	w17, w17, #10
        for (int j = 0; j < 90; j++) {
   83388:	54fff541 	b.ne	83230 <donut_text+0x78>  // b.any
        R(5, 7, cA, sA);
   8338c:	0b170ae3 	add	w3, w23, w23, lsl #2
        R(5, 8, cB, sB);
   83390:	0b150aa1 	add	w1, w21, w21, lsl #2
        R(5, 7, cA, sA);
   83394:	0b160ac2 	add	w2, w22, w22, lsl #2
        R(5, 8, cB, sB);
   83398:	0b140a80 	add	w0, w20, w20, lsl #2
        R(5, 7, cA, sA);
   8339c:	4b831ed6 	sub	w22, w22, w3, asr #7
        R(5, 8, cB, sB);
   833a0:	4b812294 	sub	w20, w20, w1, asr #8
        R(5, 7, cA, sA);
   833a4:	0b821ef7 	add	w23, w23, w2, asr #7
        R(5, 8, cB, sB);
   833a8:	0b8022b5 	add	w21, w21, w0, asr #8
   833ac:	529999ba 	mov	w26, #0xcccd                	// #52429
   833b0:	d280003c 	mov	x28, #0x1                   	// #1
        R(5, 7, cA, sA);
   833b4:	1b16bac2 	msub	w2, w22, w22, w14
        R(5, 8, cB, sB);
   833b8:	72b9999a 	movk	w26, #0xcccc, lsl #16
   833bc:	1b14ba80 	msub	w0, w20, w20, w14
            putc(0, k % 80 ? b[k] : 10);
   833c0:	52800141 	mov	w1, #0xa                   	// #10
        R(5, 7, cA, sA);
   833c4:	1b178ae2 	msub	w2, w23, w23, w2
            putc(0, k % 80 ? b[k] : 10);
   833c8:	5286667b 	mov	w27, #0x3333                	// #13107
        R(5, 8, cB, sB);
   833cc:	1b1582a0 	msub	w0, w21, w21, w0
            putc(0, k % 80 ? b[k] : 10);
   833d0:	72a0667b 	movk	w27, #0x333, lsl #16
        R(5, 7, cA, sA);
   833d4:	130b7c42 	asr	w2, w2, #11
        R(5, 8, cB, sB);
   833d8:	130b7c00 	asr	w0, w0, #11
        R(5, 7, cA, sA);
   833dc:	1b027ed6 	mul	w22, w22, w2
   833e0:	1b027ef7 	mul	w23, w23, w2
        R(5, 8, cB, sB);
   833e4:	1b007e94 	mul	w20, w20, w0
   833e8:	1b007eb5 	mul	w21, w21, w0
            putc(0, k % 80 ? b[k] : 10);
   833ec:	d2800000 	mov	x0, #0x0                   	// #0
   833f0:	940001b8 	bl	83ad0 <putc>
        R(5, 7, cA, sA);
   833f4:	130a7ed6 	asr	w22, w22, #10
        R(5, 8, cB, sB);
   833f8:	1b1c7f40 	mul	w0, w26, w28
        R(5, 7, cA, sA);
   833fc:	130a7ef7 	asr	w23, w23, #10
        R(5, 8, cB, sB);
   83400:	130a7e94 	asr	w20, w20, #10
   83404:	130a7eb5 	asr	w21, w21, #10
        for (int k = 0; 1761 > k; k++)
   83408:	f11b879f 	cmp	x28, #0x6e1
   8340c:	54000180 	b.eq	8343c <donut_text+0x284>  // b.none
            putc(0, k % 80 ? b[k] : 10);
   83410:	52800141 	mov	w1, #0xa                   	// #10
        R(5, 8, cB, sB);
   83414:	13801000 	ror	w0, w0, #4
            putc(0, k % 80 ? b[k] : 10);
   83418:	6b1b001f 	cmp	w0, w27
   8341c:	54000049 	b.ls	83424 <donut_text+0x26c>  // b.plast
   83420:	38796b81 	ldrb	w1, [x28, x25]
   83424:	9100079c 	add	x28, x28, #0x1
   83428:	d2800000 	mov	x0, #0x0                   	// #0
   8342c:	940001a9 	bl	83ad0 <putc>
        for (int k = 0; 1761 > k; k++)
   83430:	f11b879f 	cmp	x28, #0x6e1
        R(5, 8, cB, sB);
   83434:	1b1c7f40 	mul	w0, w26, w28
        for (int k = 0; 1761 > k; k++)
   83438:	54fffec1 	b.ne	83410 <donut_text+0x258>  // b.any
        printf("\x1b[23A");  // clear console 
   8343c:	f0000060 	adrp	x0, 92000 <get_el+0xd61c>
   83440:	911f0000 	add	x0, x0, #0x7c0
   83444:	97fff859 	bl	815a8 <tfp_printf>
        ms_delay(10);  // can delay in this way, but inefficient
   83448:	52800140 	mov	w0, #0xa                   	// #10
   8344c:	97fffad9 	bl	81fb0 <ms_delay>
    while (1) {
   83450:	17ffff69 	b	831f4 <donut_text+0x3c>
   83454:	00000000 	udf	#0

0000000000083458 <handler>:

#include "plat.h"
#include "utils.h"
#include "debug.h"

static int handler(TKernelTimerHandle hTimer, void *param, void *context) {
   83458:	d10183ff 	sub	sp, sp, #0x60
   8345c:	a9017bfd 	stp	x29, x30, [sp, #16]
   83460:	910043fd 	add	x29, sp, #0x10
   83464:	a90253f3 	stp	x19, x20, [sp, #32]
   83468:	aa0003f3 	mov	x19, x0
   8346c:	aa0103f4 	mov	x20, x1
	unsigned sec, msec; 
	current_time(&sec, &msec);
   83470:	910163e0 	add	x0, sp, #0x58
   83474:	910173e1 	add	x1, sp, #0x5c
static int handler(TKernelTimerHandle hTimer, void *param, void *context) {
   83478:	a9035bf5 	stp	x21, x22, [sp, #48]
   8347c:	aa0203f5 	mov	x21, x2
   83480:	f90023f7 	str	x23, [sp, #64]
	current_time(&sec, &msec);
   83484:	97fffae9 	bl	82028 <current_time>
	I("%u.%03u: fired. on cpu %d. htimer %ld, param %lx, contex %lx", sec, msec,
   83488:	294b5ff6 	ldp	w22, w23, [sp, #88]
   8348c:	9400054a 	bl	849b4 <cpuid>
   83490:	f90003f5 	str	x21, [sp]
   83494:	aa1403e7 	mov	x7, x20
   83498:	aa1303e6 	mov	x6, x19
   8349c:	2a1703e4 	mov	w4, w23
   834a0:	2a1603e3 	mov	w3, w22
   834a4:	2a0003e5 	mov	w5, w0
   834a8:	52800182 	mov	w2, #0xc                   	// #12
   834ac:	f0000061 	adrp	x1, 92000 <get_el+0xd61c>
   834b0:	f0000060 	adrp	x0, 92000 <get_el+0xd61c>
   834b4:	911f6021 	add	x1, x1, #0x7d8
   834b8:	911fa000 	add	x0, x0, #0x7e8
   834bc:	97fff83b 	bl	815a8 <tfp_printf>
		cpuid(), hTimer, (unsigned long)param, (unsigned long)context); 
    return 0; // don't restart the timer
}
   834c0:	52800000 	mov	w0, #0x0                   	// #0
   834c4:	a9417bfd 	ldp	x29, x30, [sp, #16]
   834c8:	a94253f3 	ldp	x19, x20, [sp, #32]
   834cc:	a9435bf5 	ldp	x21, x22, [sp, #48]
   834d0:	f94023f7 	ldr	x23, [sp, #64]
   834d4:	910183ff 	add	sp, sp, #0x60
   834d8:	d65f03c0 	ret
   834dc:	d503201f 	nop

00000000000834e0 <test_ktimer2_handler>:
    press 0 to kill all timers
    each ktimer has different firing period
*/    

static int test_ktimer2_handler(TKernelTimerHandle hTimer, void *param, 
    void *context) {
   834e0:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
   834e4:	910003fd 	mov	x29, sp
   834e8:	a90153f3 	stp	x19, x20, [sp, #16]
   834ec:	aa0003f4 	mov	x20, x0
   834f0:	aa0103f3 	mov	x19, x1
	unsigned sec, msec; 
	current_time(&sec, &msec);
   834f4:	9100e3e0 	add	x0, sp, #0x38
   834f8:	9100f3e1 	add	x1, sp, #0x3c
    void *context) {
   834fc:	a9025bf5 	stp	x21, x22, [sp, #32]
	current_time(&sec, &msec);
   83500:	97fffaca 	bl	82028 <current_time>
	printf("%s %u.%03u: fired. on cpu %d. htimer %ld\n" _k2clr_none, 
   83504:	29475bf5 	ldp	w21, w22, [sp, #56]
   83508:	9400052b 	bl	849b4 <cpuid>
   8350c:	aa1403e5 	mov	x5, x20
   83510:	aa1303e1 	mov	x1, x19
   83514:	2a1603e3 	mov	w3, w22
   83518:	2a1503e2 	mov	w2, w21
   8351c:	2a0003e4 	mov	w4, w0
   83520:	f0000060 	adrp	x0, 92000 <get_el+0xd61c>
   83524:	9120e000 	add	x0, x0, #0x838
   83528:	97fff820 	bl	815a8 <tfp_printf>
        (char *)param, sec, msec, cpuid(), hTimer); 
    return 1; // restart the timer 
}
   8352c:	52800020 	mov	w0, #0x1                   	// #1
   83530:	a94153f3 	ldp	x19, x20, [sp, #16]
   83534:	a9425bf5 	ldp	x21, x22, [sp, #32]
   83538:	a8c47bfd 	ldp	x29, x30, [sp], #64
   8353c:	d65f03c0 	ret

0000000000083540 <test_ktimer>:
void test_ktimer() {
   83540:	a9bb7bfd 	stp	x29, x30, [sp, #-80]!
   83544:	910003fd 	mov	x29, sp
   83548:	a90153f3 	stp	x19, x20, [sp, #16]
	current_time(&sec, &msec); 
   8354c:	910123f4 	add	x20, sp, #0x48
   83550:	aa1403e0 	mov	x0, x20
void test_ktimer() {
   83554:	a9025bf5 	stp	x21, x22, [sp, #32]
	current_time(&sec, &msec); 
   83558:	910133f5 	add	x21, sp, #0x4c
   8355c:	aa1503e1 	mov	x1, x21
void test_ktimer() {
   83560:	f9001bf7 	str	x23, [sp, #48]
	current_time(&sec, &msec); 
   83564:	97fffab1 	bl	82028 <current_time>
	I("%u.%03u start delaying 500ms...", sec, msec); 
   83568:	294913e3 	ldp	w3, w4, [sp, #72]
   8356c:	f0000077 	adrp	x23, 92000 <get_el+0xd61c>
   83570:	911f62f3 	add	x19, x23, #0x7d8
   83574:	528002c2 	mov	w2, #0x16                  	// #22
   83578:	aa1303e1 	mov	x1, x19
   8357c:	f0000060 	adrp	x0, 92000 <get_el+0xd61c>
   83580:	9121a000 	add	x0, x0, #0x868
   83584:	97fff809 	bl	815a8 <tfp_printf>
	ms_delay(500); 
   83588:	52803e80 	mov	w0, #0x1f4                 	// #500
   8358c:	97fffa89 	bl	81fb0 <ms_delay>
	current_time(&sec, &msec);
   83590:	aa1503e1 	mov	x1, x21
   83594:	aa1403e0 	mov	x0, x20
   83598:	97fffaa4 	bl	82028 <current_time>
	int t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   8359c:	90000015 	adrp	x21, 83000 <draw_frame+0x2d0>
	I("%u.%03u ended delaying 500ms", sec, msec); 
   835a0:	294913e3 	ldp	w3, w4, [sp, #72]
   835a4:	aa1303e1 	mov	x1, x19
   835a8:	52800322 	mov	w2, #0x19                  	// #25
   835ac:	f0000060 	adrp	x0, 92000 <get_el+0xd61c>
   835b0:	91228000 	add	x0, x0, #0x8a0
	int t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   835b4:	911162b5 	add	x21, x21, #0x458
	I("%u.%03u ended delaying 500ms", sec, msec); 
   835b8:	97fff7fc 	bl	815a8 <tfp_printf>
	I("timer start. timer id %u", t); 
   835bc:	f0000074 	adrp	x20, 92000 <get_el+0xd61c>
	int t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   835c0:	d29bdda3 	mov	x3, #0xdeed                	// #57069
   835c4:	d297dde2 	mov	x2, #0xbeef                	// #48879
   835c8:	aa1503e1 	mov	x1, x21
   835cc:	f2bbd5a3 	movk	x3, #0xdead, lsl #16
   835d0:	f2bbd5a2 	movk	x2, #0xdead, lsl #16
   835d4:	52803e80 	mov	w0, #0x1f4                 	// #500
   835d8:	97fffac8 	bl	820f8 <ktimer_start>
	I("timer start. timer id %u", t); 
   835dc:	2a0003e3 	mov	w3, w0
   835e0:	aa1303e1 	mov	x1, x19
   835e4:	91234294 	add	x20, x20, #0x8d0
   835e8:	528003a2 	mov	w2, #0x1d                  	// #29
	int t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   835ec:	2a0003f6 	mov	w22, w0
	I("timer start. timer id %u", t); 
   835f0:	aa1403e0 	mov	x0, x20
   835f4:	97fff7ed 	bl	815a8 <tfp_printf>
	ms_delay(1000);
   835f8:	52807d00 	mov	w0, #0x3e8                 	// #1000
   835fc:	97fffa6d 	bl	81fb0 <ms_delay>
	I("timer %d should have fired", t); 
   83600:	2a1603e3 	mov	w3, w22
   83604:	aa1303e1 	mov	x1, x19
   83608:	528003e2 	mov	w2, #0x1f                  	// #31
   8360c:	f0000060 	adrp	x0, 92000 <get_el+0xd61c>
   83610:	91240000 	add	x0, x0, #0x900
   83614:	97fff7e5 	bl	815a8 <tfp_printf>
	t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   83618:	d29bdda3 	mov	x3, #0xdeed                	// #57069
   8361c:	d297dde2 	mov	x2, #0xbeef                	// #48879
   83620:	aa1503e1 	mov	x1, x21
   83624:	f2bbd5a3 	movk	x3, #0xdead, lsl #16
   83628:	f2bbd5a2 	movk	x2, #0xdead, lsl #16
   8362c:	52803e80 	mov	w0, #0x1f4                 	// #500
   83630:	97fffab2 	bl	820f8 <ktimer_start>
	I("timer start. timer id %u", t); 
   83634:	2a0003e3 	mov	w3, w0
   83638:	aa1303e1 	mov	x1, x19
   8363c:	aa1403e0 	mov	x0, x20
   83640:	52800462 	mov	w2, #0x23                  	// #35
   83644:	97fff7d9 	bl	815a8 <tfp_printf>
	t = ktimer_start(1000, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   83648:	d29bdda3 	mov	x3, #0xdeed                	// #57069
   8364c:	d297dde2 	mov	x2, #0xbeef                	// #48879
   83650:	aa1503e1 	mov	x1, x21
   83654:	f2bbd5a3 	movk	x3, #0xdead, lsl #16
   83658:	f2bbd5a2 	movk	x2, #0xdead, lsl #16
   8365c:	52807d00 	mov	w0, #0x3e8                 	// #1000
   83660:	97fffaa6 	bl	820f8 <ktimer_start>
	I("timer start. timer id %u", t); 
   83664:	2a0003e3 	mov	w3, w0
   83668:	aa1303e1 	mov	x1, x19
   8366c:	528004a2 	mov	w2, #0x25                  	// #37
   83670:	aa1403e0 	mov	x0, x20
   83674:	97fff7cd 	bl	815a8 <tfp_printf>
	ms_delay(2000); 
   83678:	5280fa00 	mov	w0, #0x7d0                 	// #2000
   8367c:	97fffa4d 	bl	81fb0 <ms_delay>
	I("both timers should have fired"); 
   83680:	aa1303e1 	mov	x1, x19
   83684:	528004e2 	mov	w2, #0x27                  	// #39
   83688:	f0000060 	adrp	x0, 92000 <get_el+0xd61c>
   8368c:	9124c000 	add	x0, x0, #0x930
   83690:	97fff7c6 	bl	815a8 <tfp_printf>
	t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   83694:	d29bdda3 	mov	x3, #0xdeed                	// #57069
   83698:	d297dde2 	mov	x2, #0xbeef                	// #48879
   8369c:	aa1503e1 	mov	x1, x21
   836a0:	f2bbd5a3 	movk	x3, #0xdead, lsl #16
   836a4:	f2bbd5a2 	movk	x2, #0xdead, lsl #16
   836a8:	52803e80 	mov	w0, #0x1f4                 	// #500
   836ac:	97fffa93 	bl	820f8 <ktimer_start>
	I("timer start. timer id %u", t);
   836b0:	2a0003e3 	mov	w3, w0
   836b4:	aa1303e1 	mov	x1, x19
   836b8:	52800562 	mov	w2, #0x2b                  	// #43
	t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
   836bc:	2a0003f5 	mov	w21, w0
	I("timer start. timer id %u", t);
   836c0:	aa1403e0 	mov	x0, x20
   836c4:	97fff7b9 	bl	815a8 <tfp_printf>
	ms_delay(100); 
   836c8:	52800c80 	mov	w0, #0x64                  	// #100
   836cc:	97fffa39 	bl	81fb0 <ms_delay>
	int c = ktimer_cancel(t); 
   836d0:	2a1503e0 	mov	w0, w21
   836d4:	97fffad1 	bl	82218 <ktimer_cancel>
	I("timer cancel return val = %d", c);
   836d8:	aa1303e1 	mov	x1, x19
	int c = ktimer_cancel(t); 
   836dc:	2a0003f4 	mov	w20, w0
	I("timer cancel return val = %d", c);
   836e0:	2a0003e3 	mov	w3, w0
   836e4:	528005c2 	mov	w2, #0x2e                  	// #46
   836e8:	f0000060 	adrp	x0, 92000 <get_el+0xd61c>
   836ec:	9125a000 	add	x0, x0, #0x968
   836f0:	97fff7ae 	bl	815a8 <tfp_printf>
	BUG_ON(c < 0);
   836f4:	37f80174 	tbnz	w20, #31, 83720 <test_ktimer+0x1e0>
	I("there shouldn't be more callback"); 
   836f8:	911f62e1 	add	x1, x23, #0x7d8
   836fc:	52800622 	mov	w2, #0x31                  	// #49
   83700:	f0000060 	adrp	x0, 92000 <get_el+0xd61c>
   83704:	9126a000 	add	x0, x0, #0x9a8
   83708:	97fff7a8 	bl	815a8 <tfp_printf>
}
   8370c:	a94153f3 	ldp	x19, x20, [sp, #16]
   83710:	a9425bf5 	ldp	x21, x22, [sp, #32]
   83714:	f9401bf7 	ldr	x23, [sp, #48]
   83718:	a8c57bfd 	ldp	x29, x30, [sp], #80
   8371c:	d65f03c0 	ret
	BUG_ON(c < 0);
   83720:	aa1303e1 	mov	x1, x19
   83724:	f0000060 	adrp	x0, 92000 <get_el+0xd61c>
   83728:	528005e2 	mov	w2, #0x2f                  	// #47
   8372c:	91266000 	add	x0, x0, #0x998
   83730:	97fff86c 	bl	818e0 <assertion_failed>
   83734:	17fffff1 	b	836f8 <test_ktimer+0x1b8>

0000000000083738 <test_ktimer2>:
    
/* 
    c: char received from uart, support 1..9; 0 to kill all timers
    to be called in uart rx irq handler 
*/
void test_ktimer2(int c) {
   83738:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
   8373c:	910003fd 	mov	x29, sp
   83740:	a90153f3 	stp	x19, x20, [sp, #16]
    if (c<'0' || c>'9') return; 
   83744:	5100c014 	sub	w20, w0, #0x30
   83748:	7100269f 	cmp	w20, #0x9
   8374c:	540002e8 	b.hi	837a8 <test_ktimer2+0x70>  // b.pmore
   83750:	a9025bf5 	stp	x21, x22, [sp, #32]
    int ret; 
    if (c=='0') {
   83754:	7100c01f 	cmp	w0, #0x30
   83758:	540002e0 	b.eq	837b4 <test_ktimer2+0x7c>  // b.none
                timers[i]=-1;
                W("ktimer_cancel idx %d", i+1); 
            }
        }
    } else {
        int idx = c-'1'; 
   8375c:	5100c400 	sub	w0, w0, #0x31
        if (timers[idx]!=-1) { // cancel the timer
   83760:	90000096 	adrp	x22, 93000 <get_el+0xe61c>
   83764:	911602d5 	add	x21, x22, #0x580
   83768:	93407c13 	sxtw	x19, w0
   8376c:	b8737aa0 	ldr	w0, [x21, x19, lsl #2]
   83770:	3100041f 	cmn	w0, #0x1
   83774:	540005c0 	b.eq	8382c <test_ktimer2+0xf4>  // b.none
            W("ktimer_cancel %d", idx+1); 
   83778:	2a1403e3 	mov	w3, w20
   8377c:	52800c62 	mov	w2, #0x63                  	// #99
   83780:	f0000061 	adrp	x1, 92000 <get_el+0xd61c>
   83784:	f0000060 	adrp	x0, 92000 <get_el+0xd61c>
   83788:	911f6021 	add	x1, x1, #0x7d8
   8378c:	91286000 	add	x0, x0, #0xa18
   83790:	97fff786 	bl	815a8 <tfp_printf>
            ret = ktimer_cancel(timers[idx]); 
   83794:	b8737aa0 	ldr	w0, [x21, x19, lsl #2]
   83798:	97fffaa0 	bl	82218 <ktimer_cancel>
            // BUG_ON(ret == -1); // no such timer (maybe benign? like just fired?
            timers[idx]=-1;
   8379c:	12800000 	mov	w0, #0xffffffff            	// #-1
   837a0:	b8337aa0 	str	w0, [x21, x19, lsl #2]
   837a4:	a9425bf5 	ldp	x21, x22, [sp, #32]
                test_ktimer2_handler, (void*)colors[idx] /*args*/, 0 /* context */); 
            BUG_ON(ret<0); 
            timers[idx]=ret; 
        }
    }
}
   837a8:	a94153f3 	ldp	x19, x20, [sp, #16]
   837ac:	a8c47bfd 	ldp	x29, x30, [sp], #64
   837b0:	d65f03c0 	ret
   837b4:	90000093 	adrp	x19, 93000 <get_el+0xe61c>
   837b8:	f0000076 	adrp	x22, 92000 <get_el+0xd61c>
                W("ktimer_cancel idx %d", i+1); 
   837bc:	f0000075 	adrp	x21, 92000 <get_el+0xd61c>
   837c0:	91160273 	add	x19, x19, #0x580
   837c4:	9127c2b5 	add	x21, x21, #0x9f0
   837c8:	a90363f7 	stp	x23, x24, [sp, #48]
                BUG_ON(ret == -1); // no such timer
   837cc:	911f62d8 	add	x24, x22, #0x7d8
        for (int i=0;i<N_TIMERS_TEST;i++) {
   837d0:	52800014 	mov	w20, #0x0                   	// #0
                timers[i]=-1;
   837d4:	12800017 	mov	w23, #0xffffffff            	// #-1
            if (timers[i]!=-1) {
   837d8:	b9400260 	ldr	w0, [x19]
   837dc:	11000694 	add	w20, w20, #0x1
   837e0:	3100041f 	cmn	w0, #0x1
   837e4:	54000140 	b.eq	8380c <test_ktimer2+0xd4>  // b.none
                ret = ktimer_cancel(timers[i]); 
   837e8:	97fffa8c 	bl	82218 <ktimer_cancel>
                BUG_ON(ret == -1); // no such timer
   837ec:	3100041f 	cmn	w0, #0x1
   837f0:	54000500 	b.eq	83890 <test_ktimer2+0x158>  // b.none
                timers[i]=-1;
   837f4:	b9000277 	str	w23, [x19]
                W("ktimer_cancel idx %d", i+1); 
   837f8:	2a1403e3 	mov	w3, w20
   837fc:	911f62c1 	add	x1, x22, #0x7d8
   83800:	aa1503e0 	mov	x0, x21
   83804:	52800ba2 	mov	w2, #0x5d                  	// #93
   83808:	97fff768 	bl	815a8 <tfp_printf>
        for (int i=0;i<N_TIMERS_TEST;i++) {
   8380c:	91001273 	add	x19, x19, #0x4
   83810:	7100269f 	cmp	w20, #0x9
   83814:	54fffe21 	b.ne	837d8 <test_ktimer2+0xa0>  // b.any
}
   83818:	a94153f3 	ldp	x19, x20, [sp, #16]
   8381c:	a9425bf5 	ldp	x21, x22, [sp, #32]
   83820:	a94363f7 	ldp	x23, x24, [sp, #48]
   83824:	a8c47bfd 	ldp	x29, x30, [sp], #64
   83828:	d65f03c0 	ret
            W("ktimer_start %d", idx+1); 
   8382c:	f0000075 	adrp	x21, 92000 <get_el+0xd61c>
   83830:	911f62b5 	add	x21, x21, #0x7d8
   83834:	2a1403e3 	mov	w3, w20
   83838:	aa1503e1 	mov	x1, x21
   8383c:	52800d02 	mov	w2, #0x68                  	// #104
   83840:	f0000060 	adrp	x0, 92000 <get_el+0xd61c>
   83844:	91290000 	add	x0, x0, #0xa40
   83848:	97fff758 	bl	815a8 <tfp_printf>
                test_ktimer2_handler, (void*)colors[idx] /*args*/, 0 /* context */); 
   8384c:	90000082 	adrp	x2, 93000 <get_el+0xe61c>
   83850:	913ac042 	add	x2, x2, #0xeb0
            ret = ktimer_start(200*(idx+1), /*firing interval, ms*/
   83854:	52801900 	mov	w0, #0xc8                  	// #200
   83858:	90000001 	adrp	x1, 83000 <draw_frame+0x2d0>
   8385c:	d2800003 	mov	x3, #0x0                   	// #0
   83860:	91138021 	add	x1, x1, #0x4e0
   83864:	1b007e80 	mul	w0, w20, w0
   83868:	f8737842 	ldr	x2, [x2, x19, lsl #3]
   8386c:	97fffa23 	bl	820f8 <ktimer_start>
   83870:	2a0003f4 	mov	w20, w0
            BUG_ON(ret<0); 
   83874:	37f801a0 	tbnz	w0, #31, 838a8 <test_ktimer2+0x170>
            timers[idx]=ret; 
   83878:	911602d6 	add	x22, x22, #0x580
   8387c:	b8337ad4 	str	w20, [x22, x19, lsl #2]
}
   83880:	a94153f3 	ldp	x19, x20, [sp, #16]
            timers[idx]=ret; 
   83884:	a9425bf5 	ldp	x21, x22, [sp, #32]
}
   83888:	a8c47bfd 	ldp	x29, x30, [sp], #64
   8388c:	d65f03c0 	ret
                BUG_ON(ret == -1); // no such timer
   83890:	aa1803e1 	mov	x1, x24
   83894:	f0000060 	adrp	x0, 92000 <get_el+0xd61c>
   83898:	52800b62 	mov	w2, #0x5b                  	// #91
   8389c:	91278000 	add	x0, x0, #0x9e0
   838a0:	97fff810 	bl	818e0 <assertion_failed>
   838a4:	17ffffd4 	b	837f4 <test_ktimer2+0xbc>
            BUG_ON(ret<0); 
   838a8:	aa1503e1 	mov	x1, x21
   838ac:	f0000060 	adrp	x0, 92000 <get_el+0xd61c>
   838b0:	52800d62 	mov	w2, #0x6b                  	// #107
   838b4:	911ec000 	add	x0, x0, #0x7b0
   838b8:	97fff80a 	bl	818e0 <assertion_failed>
   838bc:	17ffffef 	b	83878 <test_ktimer2+0x140>

00000000000838c0 <test_fb_voffset>:
    efficiency.

    This works correctly on RPi3 hardware. Known bug on QEMU: Some color
    quadrants won't display correctly, likely due to a QEMU bug.
*/ 
void test_fb_voffset() {
   838c0:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
   838c4:	910003fd 	mov	x29, sp
   838c8:	f9000bf3 	str	x19, [sp, #16]

    // acquire(&mboxlock);      //it's a test. so no lock

    fb_fini(); 

    the_fb.width = N;
   838cc:	90000093 	adrp	x19, 93000 <get_el+0xe61c>
    fb_fini(); 
   838d0:	97fffb70 	bl	82690 <fb_fini>
    the_fb.width = N;
   838d4:	f9474260 	ldr	x0, [x19, #3712]
   838d8:	b21803e2 	mov	x2, #0x10000000100         	// #1099511628032
    the_fb.height = N;

    the_fb.vwidth = N*2; 
   838dc:	b21703e1 	mov	x1, #0x20000000200         	// #2199023256064
   838e0:	a9008402 	stp	x2, x1, [x0, #8]
    the_fb.vheight = N*2; 

    if (fb_init() != 0) BUG();     
   838e4:	97fffc57 	bl	82a40 <fb_init>
   838e8:	350008e0 	cbnz	w0, 83a04 <test_fb_voffset+0x144>

    // prefill the fb with four color tiles, once 
    PIXEL b=0x00ff0000, g=0x0000ff00, r=0x000000ff; 
    int x, y;
    int pitch = the_fb.pitch; 
   838ec:	f9474273 	ldr	x19, [x19, #3712]
    for (y=0;y<N;y++)
        for (x=0;x<N;x++)
            setpixel(the_fb.fb,x,y,pitch,r); 
   838f0:	52802006 	mov	w6, #0x100                 	// #256
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   838f4:	52801fe4 	mov	w4, #0xff                  	// #255
   838f8:	f9400267 	ldr	x7, [x19]
    int pitch = the_fb.pitch; 
   838fc:	b9401a61 	ldr	w1, [x19, #24]
    for (y=0;y<N;y++)
   83900:	911000e2 	add	x2, x7, #0x400
            setpixel(the_fb.fb,x,y,pitch,r); 
   83904:	aa0203e3 	mov	x3, x2
   83908:	93407c25 	sxtw	x5, w1
        for (x=0;x<N;x++)
   8390c:	d1100060 	sub	x0, x3, #0x400
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   83910:	b8004404 	str	w4, [x0], #4
        for (x=0;x<N;x++)
   83914:	eb03001f 	cmp	x0, x3
   83918:	54ffffc1 	b.ne	83910 <test_fb_voffset+0x50>  // b.any
    for (y=0;y<N;y++)
   8391c:	8b050003 	add	x3, x0, x5
   83920:	710004c6 	subs	w6, w6, #0x1
   83924:	54ffff41 	b.ne	8390c <test_fb_voffset+0x4c>  // b.any
   83928:	912000e7 	add	x7, x7, #0x800
   8392c:	52802006 	mov	w6, #0x100                 	// #256
   83930:	aa0703e3 	mov	x3, x7
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   83934:	32009fe4 	mov	w4, #0xff00ff              	// #16711935

    for (y=0;y<N;y++)
        for (x=N;x<2*N;x++)
   83938:	d1100060 	sub	x0, x3, #0x400
   8393c:	d503201f 	nop
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   83940:	b8004404 	str	w4, [x0], #4
        for (x=N;x<2*N;x++)
   83944:	eb00007f 	cmp	x3, x0
   83948:	54ffffc1 	b.ne	83940 <test_fb_voffset+0x80>  // b.any
    for (y=0;y<N;y++)
   8394c:	8b050063 	add	x3, x3, x5
   83950:	710004c6 	subs	w6, w6, #0x1
   83954:	54ffff21 	b.ne	83938 <test_fb_voffset+0x78>  // b.any
   83958:	53185c21 	lsl	w1, w1, #8
   8395c:	52802004 	mov	w4, #0x100                 	// #256
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   83960:	529fe003 	mov	w3, #0xff00                	// #65280
   83964:	93407c21 	sxtw	x1, w1
   83968:	8b020022 	add	x2, x1, x2
            setpixel(the_fb.fb,x,y,pitch,(b|r));             

    for (y=N;y<2*N;y++)
        for (x=0;x<N;x++)
   8396c:	d1100040 	sub	x0, x2, #0x400
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   83970:	b8004403 	str	w3, [x0], #4
        for (x=0;x<N;x++)
   83974:	eb00005f 	cmp	x2, x0
   83978:	54ffffc1 	b.ne	83970 <test_fb_voffset+0xb0>  // b.any
    for (y=N;y<2*N;y++)
   8397c:	8b050042 	add	x2, x2, x5
   83980:	71000484 	subs	w4, w4, #0x1
   83984:	54ffff41 	b.ne	8396c <test_fb_voffset+0xac>  // b.any
   83988:	8b070021 	add	x1, x1, x7
   8398c:	52802003 	mov	w3, #0x100                 	// #256
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   83990:	52a01fe2 	mov	w2, #0xff0000              	// #16711680
            setpixel(the_fb.fb,x,y,pitch,g); 

    for (y=N;y<2*N;y++)
        for (x=N;x<2*N;x++)
   83994:	d1100020 	sub	x0, x1, #0x400
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
   83998:	b8004402 	str	w2, [x0], #4
        for (x=N;x<2*N;x++)
   8399c:	eb00003f 	cmp	x1, x0
   839a0:	54ffffc1 	b.ne	83998 <test_fb_voffset+0xd8>  // b.any
    for (y=N;y<2*N;y++)
   839a4:	8b050021 	add	x1, x1, x5
   839a8:	71000463 	subs	w3, w3, #0x1
   839ac:	54ffff41 	b.ne	83994 <test_fb_voffset+0xd4>  // b.any

    //what if we dont flush cache?
    // __asm_flush_dcache_range(the_fb.fb, the_fb.fb + the_fb.size); 

    while (1) {
        fb_set_voffsets(0,0);
   839b0:	52800001 	mov	w1, #0x0                   	// #0
   839b4:	52800000 	mov	w0, #0x0                   	// #0
   839b8:	97fffaf2 	bl	82580 <fb_set_voffsets>
        ms_delay(1500); 
   839bc:	5280bb80 	mov	w0, #0x5dc                 	// #1500
   839c0:	97fff97c 	bl	81fb0 <ms_delay>
        fb_set_voffsets(0,N);
   839c4:	52802001 	mov	w1, #0x100                 	// #256
   839c8:	52800000 	mov	w0, #0x0                   	// #0
   839cc:	97fffaed 	bl	82580 <fb_set_voffsets>
        ms_delay(1500); 
   839d0:	5280bb80 	mov	w0, #0x5dc                 	// #1500
   839d4:	97fff977 	bl	81fb0 <ms_delay>
        fb_set_voffsets(N,0);
   839d8:	52800001 	mov	w1, #0x0                   	// #0
   839dc:	52802000 	mov	w0, #0x100                 	// #256
   839e0:	97fffae8 	bl	82580 <fb_set_voffsets>
        ms_delay(1500); 
   839e4:	5280bb80 	mov	w0, #0x5dc                 	// #1500
   839e8:	97fff972 	bl	81fb0 <ms_delay>
        fb_set_voffsets(N,N);
   839ec:	52802001 	mov	w1, #0x100                 	// #256
   839f0:	2a0103e0 	mov	w0, w1
   839f4:	97fffae3 	bl	82580 <fb_set_voffsets>
        ms_delay(1500); 
   839f8:	5280bb80 	mov	w0, #0x5dc                 	// #1500
   839fc:	97fff96d 	bl	81fb0 <ms_delay>
    while (1) {
   83a00:	17ffffec 	b	839b0 <test_fb_voffset+0xf0>
    if (fb_init() != 0) BUG();     
   83a04:	f0000061 	adrp	x1, 92000 <get_el+0xd61c>
   83a08:	b0000000 	adrp	x0, 84000 <vectors>
   83a0c:	911f6021 	add	x1, x1, #0x7d8
   83a10:	912ac000 	add	x0, x0, #0xab0
   83a14:	52801342 	mov	w2, #0x9a                  	// #154
   83a18:	97fff7b2 	bl	818e0 <assertion_failed>
   83a1c:	17ffffb4 	b	838ec <test_fb_voffset+0x2c>

0000000000083a20 <uart_send>:
// busy wait
// quest: UART. complete below cf uart_recv()
void uart_send (char c) {
	while(1) {
			/* Q4  STUDENT_TODO: your code here */
            if (get32(AUX_MU_LSR_REG) & 0x20)
   83a20:	d28a0a82 	mov	x2, #0x5054                	// #20564
void uart_send (char c) {
   83a24:	12001c00 	and	w0, w0, #0xff
            if (get32(AUX_MU_LSR_REG) & 0x20)
   83a28:	f2a7e422 	movk	x2, #0x3f21, lsl #16
   83a2c:	d503201f 	nop
   83a30:	b9400041 	ldr	w1, [x2]
   83a34:	362fffe1 	tbz	w1, #5, 83a30 <uart_send+0x10>
                break;
	}
	/* Q4  STUDENT_TODO: your code here */
    put32(AUX_MU_IO_REG, c);
   83a38:	d28a0801 	mov	x1, #0x5040                	// #20544
   83a3c:	f2a7e421 	movk	x1, #0x3f21, lsl #16
   83a40:	b9000020 	str	w0, [x1]
}
   83a44:	d65f03c0 	ret

0000000000083a48 <uart_recv>:
 
// busy wait until get a char 
char uart_recv (void) {
	while(1) {
		if(get32(AUX_MU_LSR_REG) & 0x01) 
   83a48:	d28a0a81 	mov	x1, #0x5054                	// #20564
   83a4c:	f2a7e421 	movk	x1, #0x3f21, lsl #16
   83a50:	b9400020 	ldr	w0, [x1]
   83a54:	3607ffe0 	tbz	w0, #0, 83a50 <uart_recv+0x8>
			break;
	}
	return(get32(AUX_MU_IO_REG) & 0xFF);
   83a58:	d28a0800 	mov	x0, #0x5040                	// #20544
   83a5c:	f2a7e420 	movk	x0, #0x3f21, lsl #16
   83a60:	b9400000 	ldr	w0, [x0]
}
   83a64:	d65f03c0 	ret

0000000000083a68 <uart_try_recv>:

// try read a char, return -1 if no char (NB: return type is int) 
int uart_try_recv(void) {
    if (!(get32(AUX_MU_STAT_REG) & 0xF0000)) {
   83a68:	d28a0c80 	mov	x0, #0x5064                	// #20580
   83a6c:	f2a7e420 	movk	x0, #0x3f21, lsl #16
   83a70:	b9400000 	ldr	w0, [x0]
   83a74:	72100c1f 	tst	w0, #0xf0000
   83a78:	540000c0 	b.eq	83a90 <uart_try_recv+0x28>  // b.none
        return -1;
    } else {
        // rx fifo has bytes
        return get32(AUX_MU_IO_REG) & 0xFF;
   83a7c:	d28a0800 	mov	x0, #0x5040                	// #20544
   83a80:	f2a7e420 	movk	x0, #0x3f21, lsl #16
   83a84:	b9400000 	ldr	w0, [x0]
   83a88:	12001c00 	and	w0, w0, #0xff
    }
}
   83a8c:	d65f03c0 	ret
        return -1;
   83a90:	12800000 	mov	w0, #0xffffffff            	// #-1
}
   83a94:	d65f03c0 	ret

0000000000083a98 <uart_send_string>:

void uart_send_string(char* str) {
	for (int i = 0; str[i] != '\0'; i ++) {
   83a98:	39400002 	ldrb	w2, [x0]
   83a9c:	34000182 	cbz	w2, 83acc <uart_send_string+0x34>
            if (get32(AUX_MU_LSR_REG) & 0x20)
   83aa0:	d28a0a81 	mov	x1, #0x5054                	// #20564
    put32(AUX_MU_IO_REG, c);
   83aa4:	d28a0804 	mov	x4, #0x5040                	// #20544
   83aa8:	91000403 	add	x3, x0, #0x1
            if (get32(AUX_MU_LSR_REG) & 0x20)
   83aac:	f2a7e421 	movk	x1, #0x3f21, lsl #16
    put32(AUX_MU_IO_REG, c);
   83ab0:	f2a7e424 	movk	x4, #0x3f21, lsl #16
   83ab4:	d503201f 	nop
            if (get32(AUX_MU_LSR_REG) & 0x20)
   83ab8:	b9400020 	ldr	w0, [x1]
   83abc:	362fffe0 	tbz	w0, #5, 83ab8 <uart_send_string+0x20>
    put32(AUX_MU_IO_REG, c);
   83ac0:	b9000082 	str	w2, [x4]
	for (int i = 0; str[i] != '\0'; i ++) {
   83ac4:	38401462 	ldrb	w2, [x3], #1
   83ac8:	35ffff82 	cbnz	w2, 83ab8 <uart_send_string+0x20>
		uart_send((char)str[i]);
	}
}
   83acc:	d65f03c0 	ret

0000000000083ad0 <putc>:
            if (get32(AUX_MU_LSR_REG) & 0x20)
   83ad0:	d28a0a82 	mov	x2, #0x5054                	// #20564

// This function is required by printf function
void putc(void* p, char c) {
   83ad4:	12001c21 	and	w1, w1, #0xff
            if (get32(AUX_MU_LSR_REG) & 0x20)
   83ad8:	f2a7e422 	movk	x2, #0x3f21, lsl #16
   83adc:	d503201f 	nop
   83ae0:	b9400040 	ldr	w0, [x2]
   83ae4:	362fffe0 	tbz	w0, #5, 83ae0 <putc+0x10>
    put32(AUX_MU_IO_REG, c);
   83ae8:	d28a0800 	mov	x0, #0x5040                	// #20544
   83aec:	f2a7e420 	movk	x0, #0x3f21, lsl #16
   83af0:	b9000001 	str	w1, [x0]
	uart_send(c);
}
   83af4:	d65f03c0 	ret

0000000000083af8 <uart_irq>:
 */
void uart_irq(void) {
    //  check AUX_MU_IIR_REG bit0 for pending irq
    //    and bit 2:1 for irq causes
	int c; 
    uint iir = get32(AUX_MU_IIR_REG);
   83af8:	d28a0900 	mov	x0, #0x5048                	// #20552
   83afc:	f2a7e420 	movk	x0, #0x3f21, lsl #16
   83b00:	b9400000 	ldr	w0, [x0]
    if (iir & 1) // no pending
   83b04:	370001a0 	tbnz	w0, #0, 83b38 <uart_irq+0x40>
        return;
    V("pending irq: p %d w %d r %d", (iir & 1), (iir & 2), (iir & 4));

    // clear rx irq, must be done before we read 
    if (IS_RECEIVE_INTERRUPT(iir)) {
   83b08:	36100180 	tbz	w0, #2, 83b38 <uart_irq+0x40>
    if (!(get32(AUX_MU_STAT_REG) & 0xF0000)) {
   83b0c:	d28a0c81 	mov	x1, #0x5064                	// #20580
   83b10:	f2a7e421 	movk	x1, #0x3f21, lsl #16
   83b14:	b9400020 	ldr	w0, [x1]
   83b18:	72100c1f 	tst	w0, #0xf0000
   83b1c:	540000e0 	b.eq	83b38 <uart_irq+0x40>  // b.none
        return get32(AUX_MU_IO_REG) & 0xFF;
   83b20:	d28a0802 	mov	x2, #0x5040                	// #20544
   83b24:	f2a7e422 	movk	x2, #0x3f21, lsl #16
   83b28:	b9400040 	ldr	w0, [x2]
    if (!(get32(AUX_MU_STAT_REG) & 0xF0000)) {
   83b2c:	b9400020 	ldr	w0, [x1]
   83b30:	72100c1f 	tst	w0, #0xf0000
   83b34:	54ffffa1 	b.ne	83b28 <uart_irq+0x30>  // b.any
                break;
            }
            V("char %d", c); 
        }
    }
}
   83b38:	d65f03c0 	ret
   83b3c:	d503201f 	nop

0000000000083b40 <uart_init>:
void uart_init(void) {
    unsigned int selector;
    // code below also showcases how to configure GPIO pins
    // cf: https://github.com/bztsrc/raspi3-tutorial/blob/master/03_uart1/uart.c#L45
    // select gpio functions for pin14,15. note 3bits per pin.
    selector = get32(GPFSEL1);
   83b40:	d2800082 	mov	x2, #0x4                   	// #4
void uart_init(void) {
   83b44:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
    selector = get32(GPFSEL1);
   83b48:	f2a7e402 	movk	x2, #0x3f20, lsl #16
void uart_init(void) {
   83b4c:	910003fd 	mov	x29, sp
    selector = get32(GPFSEL1);
   83b50:	b9400041 	ldr	w1, [x2]

    // Below: set up GPIO pull modes. protocol recommended by the bcm2837 manual
    //    (pg 101, "GPIO Pull-up/down Clock Registers")
    // We need neither the pull-up nor the pull-down state, because both
    //  the 14 and 15 pins are going to be connected all the time.
    put32(GPPUD, 0); // disable pull up/down control (for pins below)
   83b54:	d2801283 	mov	x3, #0x94                  	// #148
   83b58:	f2a7e403 	movk	x3, #0x3f20, lsl #16
    selector |= 2 << 15;    // set alt5 for gpio15
   83b5c:	52840004 	mov	w4, #0x2000                	// #8192
   83b60:	120e6421 	and	w1, w1, #0xfffc0fff
void uart_init(void) {
   83b64:	f9000bf3 	str	x19, [sp, #16]
    selector |= 2 << 15;    // set alt5 for gpio15
   83b68:	72a00024 	movk	w4, #0x1, lsl #16
   83b6c:	2a040021 	orr	w1, w1, w4
    put32(GPFSEL1, selector);
   83b70:	b9000041 	str	w1, [x2]
    delay(150);
    // "control the actuation of internal pull-downs on the respective GPIO pins."
    put32(GPPUDCLK0, (1 << 14) | (1 << 15)); // "clock the control signal into the GPIO pads"
   83b74:	d2801313 	mov	x19, #0x98                  	// #152
    put32(GPPUD, 0); // disable pull up/down control (for pins below)
   83b78:	b900007f 	str	wzr, [x3]
    put32(GPPUDCLK0, (1 << 14) | (1 << 15)); // "clock the control signal into the GPIO pads"
   83b7c:	f2a7e413 	movk	x19, #0x3f20, lsl #16
    delay(150);
   83b80:	d28012c0 	mov	x0, #0x96                  	// #150
   83b84:	97fff945 	bl	82098 <delay>
    put32(GPPUDCLK0, (1 << 14) | (1 << 15)); // "clock the control signal into the GPIO pads"
   83b88:	52980000 	mov	w0, #0xc000                	// #49152
   83b8c:	b9000260 	str	w0, [x19]
    delay(150);
   83b90:	d28012c0 	mov	x0, #0x96                  	// #150
   83b94:	97fff941 	bl	82098 <delay>
    put32(GPPUDCLK0, 0);               // remote the clock, flush GPIO setup
   83b98:	b900027f 	str	wzr, [x19]
    put32(AUX_MU_IIR_REG, FLUSH_UART); // flush FIFO
   83b9c:	d28a0900 	mov	x0, #0x5048                	// #20552

    put32(AUX_ENABLES, 1);     // Enable mini uart (this also enables access to it registers)
   83ba0:	d28a0081 	mov	x1, #0x5004                	// #20484
    put32(AUX_MU_IIR_REG, FLUSH_UART); // flush FIFO
   83ba4:	f2a7e420 	movk	x0, #0x3f21, lsl #16
    put32(AUX_ENABLES, 1);     // Enable mini uart (this also enables access to it registers)
   83ba8:	f2a7e421 	movk	x1, #0x3f21, lsl #16
    put32(AUX_MU_CNTL_REG, 0); // Disable auto flow control and disable receiver and transmitter (for now)
   83bac:	d28a0c02 	mov	x2, #0x5060                	// #20576
    put32(AUX_MU_IIR_REG, FLUSH_UART); // flush FIFO
   83bb0:	528018c3 	mov	w3, #0xc6                  	// #198
    put32(AUX_MU_CNTL_REG, 0); // Disable auto flow control and disable receiver and transmitter (for now)
   83bb4:	f2a7e422 	movk	x2, #0x3f21, lsl #16
  		/* STUDENT_TODO: your code here */
        ier |= AUX_MU_IER_RXIRQ_ENABLE;
        put32(AUX_MU_IER_REG, ier);
	} // leave tx irq disabled

    put32(AUX_MU_LCR_REG, 3);    // Enable 8 bit mode
   83bb8:	d28a0987 	mov	x7, #0x504c                	// #20556
    put32(AUX_MU_MCR_REG, 0);    // Set RTS line to be always high
    put32(AUX_MU_BAUD_REG, 270); // Set baud rate to 115200

    put32(AUX_MU_CNTL_REG, 3); // Finally, enable transmitter and receiver
}
   83bbc:	f9400bf3 	ldr	x19, [sp, #16]
    put32(AUX_MU_IIR_REG, FLUSH_UART); // flush FIFO
   83bc0:	b9000003 	str	w3, [x0]
    put32(AUX_MU_IER_REG, (3 << 2) | (0xf << 4)); // bit 7:4 3:2 must be 1
   83bc4:	d28a0880 	mov	x0, #0x5044                	// #20548
    put32(AUX_ENABLES, 1);     // Enable mini uart (this also enables access to it registers)
   83bc8:	52800023 	mov	w3, #0x1                   	// #1
    put32(AUX_MU_IER_REG, (3 << 2) | (0xf << 4)); // bit 7:4 3:2 must be 1
   83bcc:	f2a7e420 	movk	x0, #0x3f21, lsl #16
    put32(AUX_ENABLES, 1);     // Enable mini uart (this also enables access to it registers)
   83bd0:	b9000023 	str	w3, [x1]
    put32(AUX_MU_CNTL_REG, 0); // Disable auto flow control and disable receiver and transmitter (for now)
   83bd4:	b900005f 	str	wzr, [x2]
    put32(AUX_MU_IER_REG, (3 << 2) | (0xf << 4)); // bit 7:4 3:2 must be 1
   83bd8:	52801f81 	mov	w1, #0xfc                  	// #252
   83bdc:	b9000001 	str	w1, [x0]
    put32(AUX_MU_LCR_REG, 3);    // Enable 8 bit mode
   83be0:	f2a7e427 	movk	x7, #0x3f21, lsl #16
    put32(AUX_MU_MCR_REG, 0);    // Set RTS line to be always high
   83be4:	d28a0a06 	mov	x6, #0x5050                	// #20560
    put32(AUX_MU_BAUD_REG, 270); // Set baud rate to 115200
   83be8:	d28a0d04 	mov	x4, #0x5068                	// #20584
		unsigned int ier = get32(AUX_MU_IER_REG); 
   83bec:	b9400001 	ldr	w1, [x0]
    put32(AUX_MU_MCR_REG, 0);    // Set RTS line to be always high
   83bf0:	f2a7e426 	movk	x6, #0x3f21, lsl #16
    put32(AUX_MU_LCR_REG, 3);    // Enable 8 bit mode
   83bf4:	52800063 	mov	w3, #0x3                   	// #3
    put32(AUX_MU_BAUD_REG, 270); // Set baud rate to 115200
   83bf8:	f2a7e424 	movk	x4, #0x3f21, lsl #16
        ier |= AUX_MU_IER_RXIRQ_ENABLE;
   83bfc:	32000021 	orr	w1, w1, #0x1
        put32(AUX_MU_IER_REG, ier);
   83c00:	b9000001 	str	w1, [x0]
    put32(AUX_MU_LCR_REG, 3);    // Enable 8 bit mode
   83c04:	b90000e3 	str	w3, [x7]
    put32(AUX_MU_BAUD_REG, 270); // Set baud rate to 115200
   83c08:	528021c5 	mov	w5, #0x10e                 	// #270
    put32(AUX_MU_MCR_REG, 0);    // Set RTS line to be always high
   83c0c:	b90000df 	str	wzr, [x6]
    put32(AUX_MU_BAUD_REG, 270); // Set baud rate to 115200
   83c10:	b9000085 	str	w5, [x4]
    put32(AUX_MU_CNTL_REG, 3); // Finally, enable transmitter and receiver
   83c14:	b9000043 	str	w3, [x2]
}
   83c18:	a8c27bfd 	ldp	x29, x30, [sp], #32
   83c1c:	d65f03c0 	ret
	...

0000000000084000 <vectors>:
.align	11
.globl vectors 
vectors:
	/* EL1t -- Exception happens when CPU is at EL1 while the stack pointer (SP)
	was set to be shared with EL0 */
	ventry	sync_invalid_el1t			// Synchronous EL1t
   84000:	140001e1 	b	84784 <sync_invalid_el1t>
   84004:	d503201f 	nop
   84008:	d503201f 	nop
   8400c:	d503201f 	nop
   84010:	d503201f 	nop
   84014:	d503201f 	nop
   84018:	d503201f 	nop
   8401c:	d503201f 	nop
   84020:	d503201f 	nop
   84024:	d503201f 	nop
   84028:	d503201f 	nop
   8402c:	d503201f 	nop
   84030:	d503201f 	nop
   84034:	d503201f 	nop
   84038:	d503201f 	nop
   8403c:	d503201f 	nop
   84040:	d503201f 	nop
   84044:	d503201f 	nop
   84048:	d503201f 	nop
   8404c:	d503201f 	nop
   84050:	d503201f 	nop
   84054:	d503201f 	nop
   84058:	d503201f 	nop
   8405c:	d503201f 	nop
   84060:	d503201f 	nop
   84064:	d503201f 	nop
   84068:	d503201f 	nop
   8406c:	d503201f 	nop
   84070:	d503201f 	nop
   84074:	d503201f 	nop
   84078:	d503201f 	nop
   8407c:	d503201f 	nop
	ventry	irq_invalid_el1t			// IRQ EL1t
   84080:	140001c8 	b	847a0 <irq_invalid_el1t>
   84084:	d503201f 	nop
   84088:	d503201f 	nop
   8408c:	d503201f 	nop
   84090:	d503201f 	nop
   84094:	d503201f 	nop
   84098:	d503201f 	nop
   8409c:	d503201f 	nop
   840a0:	d503201f 	nop
   840a4:	d503201f 	nop
   840a8:	d503201f 	nop
   840ac:	d503201f 	nop
   840b0:	d503201f 	nop
   840b4:	d503201f 	nop
   840b8:	d503201f 	nop
   840bc:	d503201f 	nop
   840c0:	d503201f 	nop
   840c4:	d503201f 	nop
   840c8:	d503201f 	nop
   840cc:	d503201f 	nop
   840d0:	d503201f 	nop
   840d4:	d503201f 	nop
   840d8:	d503201f 	nop
   840dc:	d503201f 	nop
   840e0:	d503201f 	nop
   840e4:	d503201f 	nop
   840e8:	d503201f 	nop
   840ec:	d503201f 	nop
   840f0:	d503201f 	nop
   840f4:	d503201f 	nop
   840f8:	d503201f 	nop
   840fc:	d503201f 	nop
	ventry	fiq_invalid_el1t			// FIQ EL1t
   84100:	140001af 	b	847bc <fiq_invalid_el1t>
   84104:	d503201f 	nop
   84108:	d503201f 	nop
   8410c:	d503201f 	nop
   84110:	d503201f 	nop
   84114:	d503201f 	nop
   84118:	d503201f 	nop
   8411c:	d503201f 	nop
   84120:	d503201f 	nop
   84124:	d503201f 	nop
   84128:	d503201f 	nop
   8412c:	d503201f 	nop
   84130:	d503201f 	nop
   84134:	d503201f 	nop
   84138:	d503201f 	nop
   8413c:	d503201f 	nop
   84140:	d503201f 	nop
   84144:	d503201f 	nop
   84148:	d503201f 	nop
   8414c:	d503201f 	nop
   84150:	d503201f 	nop
   84154:	d503201f 	nop
   84158:	d503201f 	nop
   8415c:	d503201f 	nop
   84160:	d503201f 	nop
   84164:	d503201f 	nop
   84168:	d503201f 	nop
   8416c:	d503201f 	nop
   84170:	d503201f 	nop
   84174:	d503201f 	nop
   84178:	d503201f 	nop
   8417c:	d503201f 	nop
	ventry	error_invalid_el1t			// Error EL1t
   84180:	14000196 	b	847d8 <error_invalid_el1t>
   84184:	d503201f 	nop
   84188:	d503201f 	nop
   8418c:	d503201f 	nop
   84190:	d503201f 	nop
   84194:	d503201f 	nop
   84198:	d503201f 	nop
   8419c:	d503201f 	nop
   841a0:	d503201f 	nop
   841a4:	d503201f 	nop
   841a8:	d503201f 	nop
   841ac:	d503201f 	nop
   841b0:	d503201f 	nop
   841b4:	d503201f 	nop
   841b8:	d503201f 	nop
   841bc:	d503201f 	nop
   841c0:	d503201f 	nop
   841c4:	d503201f 	nop
   841c8:	d503201f 	nop
   841cc:	d503201f 	nop
   841d0:	d503201f 	nop
   841d4:	d503201f 	nop
   841d8:	d503201f 	nop
   841dc:	d503201f 	nop
   841e0:	d503201f 	nop
   841e4:	d503201f 	nop
   841e8:	d503201f 	nop
   841ec:	d503201f 	nop
   841f0:	d503201f 	nop
   841f4:	d503201f 	nop
   841f8:	d503201f 	nop
   841fc:	d503201f 	nop

	/* EL1h -- Exception happens at EL1 at the time when a dedicated SP was
	 	allocated for EL1. This is the mode that our kernel is currently
	 	using */
	ventry	sync_invalid_el1h			// Synchronous EL1h
   84200:	1400017d 	b	847f4 <sync_invalid_el1h>
   84204:	d503201f 	nop
   84208:	d503201f 	nop
   8420c:	d503201f 	nop
   84210:	d503201f 	nop
   84214:	d503201f 	nop
   84218:	d503201f 	nop
   8421c:	d503201f 	nop
   84220:	d503201f 	nop
   84224:	d503201f 	nop
   84228:	d503201f 	nop
   8422c:	d503201f 	nop
   84230:	d503201f 	nop
   84234:	d503201f 	nop
   84238:	d503201f 	nop
   8423c:	d503201f 	nop
   84240:	d503201f 	nop
   84244:	d503201f 	nop
   84248:	d503201f 	nop
   8424c:	d503201f 	nop
   84250:	d503201f 	nop
   84254:	d503201f 	nop
   84258:	d503201f 	nop
   8425c:	d503201f 	nop
   84260:	d503201f 	nop
   84264:	d503201f 	nop
   84268:	d503201f 	nop
   8426c:	d503201f 	nop
   84270:	d503201f 	nop
   84274:	d503201f 	nop
   84278:	d503201f 	nop
   8427c:	d503201f 	nop
	// IRQ EL1h
ventry	irq_invalid_el1h /* STUDENT_TODO: replace this */
   84280:	14000180 	b	84880 <irq_invalid_el1h>
   84284:	d503201f 	nop
   84288:	d503201f 	nop
   8428c:	d503201f 	nop
   84290:	d503201f 	nop
   84294:	d503201f 	nop
   84298:	d503201f 	nop
   8429c:	d503201f 	nop
   842a0:	d503201f 	nop
   842a4:	d503201f 	nop
   842a8:	d503201f 	nop
   842ac:	d503201f 	nop
   842b0:	d503201f 	nop
   842b4:	d503201f 	nop
   842b8:	d503201f 	nop
   842bc:	d503201f 	nop
   842c0:	d503201f 	nop
   842c4:	d503201f 	nop
   842c8:	d503201f 	nop
   842cc:	d503201f 	nop
   842d0:	d503201f 	nop
   842d4:	d503201f 	nop
   842d8:	d503201f 	nop
   842dc:	d503201f 	nop
   842e0:	d503201f 	nop
   842e4:	d503201f 	nop
   842e8:	d503201f 	nop
   842ec:	d503201f 	nop
   842f0:	d503201f 	nop
   842f4:	d503201f 	nop
   842f8:	d503201f 	nop
   842fc:	d503201f 	nop
	ventry	fiq_invalid_el1h			// FIQ EL1h
   84300:	14000144 	b	84810 <fiq_invalid_el1h>
   84304:	d503201f 	nop
   84308:	d503201f 	nop
   8430c:	d503201f 	nop
   84310:	d503201f 	nop
   84314:	d503201f 	nop
   84318:	d503201f 	nop
   8431c:	d503201f 	nop
   84320:	d503201f 	nop
   84324:	d503201f 	nop
   84328:	d503201f 	nop
   8432c:	d503201f 	nop
   84330:	d503201f 	nop
   84334:	d503201f 	nop
   84338:	d503201f 	nop
   8433c:	d503201f 	nop
   84340:	d503201f 	nop
   84344:	d503201f 	nop
   84348:	d503201f 	nop
   8434c:	d503201f 	nop
   84350:	d503201f 	nop
   84354:	d503201f 	nop
   84358:	d503201f 	nop
   8435c:	d503201f 	nop
   84360:	d503201f 	nop
   84364:	d503201f 	nop
   84368:	d503201f 	nop
   8436c:	d503201f 	nop
   84370:	d503201f 	nop
   84374:	d503201f 	nop
   84378:	d503201f 	nop
   8437c:	d503201f 	nop
	ventry	error_invalid_el1h			// Error EL1h
   84380:	1400012b 	b	8482c <error_invalid_el1h>
   84384:	d503201f 	nop
   84388:	d503201f 	nop
   8438c:	d503201f 	nop
   84390:	d503201f 	nop
   84394:	d503201f 	nop
   84398:	d503201f 	nop
   8439c:	d503201f 	nop
   843a0:	d503201f 	nop
   843a4:	d503201f 	nop
   843a8:	d503201f 	nop
   843ac:	d503201f 	nop
   843b0:	d503201f 	nop
   843b4:	d503201f 	nop
   843b8:	d503201f 	nop
   843bc:	d503201f 	nop
   843c0:	d503201f 	nop
   843c4:	d503201f 	nop
   843c8:	d503201f 	nop
   843cc:	d503201f 	nop
   843d0:	d503201f 	nop
   843d4:	d503201f 	nop
   843d8:	d503201f 	nop
   843dc:	d503201f 	nop
   843e0:	d503201f 	nop
   843e4:	d503201f 	nop
   843e8:	d503201f 	nop
   843ec:	d503201f 	nop
   843f0:	d503201f 	nop
   843f4:	d503201f 	nop
   843f8:	d503201f 	nop
   843fc:	d503201f 	nop

	/*  EL0_64 -- Exception is taken from EL0 executing in 64-bit mode. 
		The exceptions caused in 64-bit user programs */
	ventry	sync_invalid_el0_64			// Synchronous 64-bit EL0
   84400:	14000112 	b	84848 <sync_invalid_el0_64>
   84404:	d503201f 	nop
   84408:	d503201f 	nop
   8440c:	d503201f 	nop
   84410:	d503201f 	nop
   84414:	d503201f 	nop
   84418:	d503201f 	nop
   8441c:	d503201f 	nop
   84420:	d503201f 	nop
   84424:	d503201f 	nop
   84428:	d503201f 	nop
   8442c:	d503201f 	nop
   84430:	d503201f 	nop
   84434:	d503201f 	nop
   84438:	d503201f 	nop
   8443c:	d503201f 	nop
   84440:	d503201f 	nop
   84444:	d503201f 	nop
   84448:	d503201f 	nop
   8444c:	d503201f 	nop
   84450:	d503201f 	nop
   84454:	d503201f 	nop
   84458:	d503201f 	nop
   8445c:	d503201f 	nop
   84460:	d503201f 	nop
   84464:	d503201f 	nop
   84468:	d503201f 	nop
   8446c:	d503201f 	nop
   84470:	d503201f 	nop
   84474:	d503201f 	nop
   84478:	d503201f 	nop
   8447c:	d503201f 	nop
	ventry	irq_invalid_el0_64			// IRQ 64-bit EL0
   84480:	140000f9 	b	84864 <irq_invalid_el0_64>
   84484:	d503201f 	nop
   84488:	d503201f 	nop
   8448c:	d503201f 	nop
   84490:	d503201f 	nop
   84494:	d503201f 	nop
   84498:	d503201f 	nop
   8449c:	d503201f 	nop
   844a0:	d503201f 	nop
   844a4:	d503201f 	nop
   844a8:	d503201f 	nop
   844ac:	d503201f 	nop
   844b0:	d503201f 	nop
   844b4:	d503201f 	nop
   844b8:	d503201f 	nop
   844bc:	d503201f 	nop
   844c0:	d503201f 	nop
   844c4:	d503201f 	nop
   844c8:	d503201f 	nop
   844cc:	d503201f 	nop
   844d0:	d503201f 	nop
   844d4:	d503201f 	nop
   844d8:	d503201f 	nop
   844dc:	d503201f 	nop
   844e0:	d503201f 	nop
   844e4:	d503201f 	nop
   844e8:	d503201f 	nop
   844ec:	d503201f 	nop
   844f0:	d503201f 	nop
   844f4:	d503201f 	nop
   844f8:	d503201f 	nop
   844fc:	d503201f 	nop
	ventry	fiq_invalid_el0_64			// FIQ 64-bit EL0
   84500:	140000e7 	b	8489c <fiq_invalid_el0_64>
   84504:	d503201f 	nop
   84508:	d503201f 	nop
   8450c:	d503201f 	nop
   84510:	d503201f 	nop
   84514:	d503201f 	nop
   84518:	d503201f 	nop
   8451c:	d503201f 	nop
   84520:	d503201f 	nop
   84524:	d503201f 	nop
   84528:	d503201f 	nop
   8452c:	d503201f 	nop
   84530:	d503201f 	nop
   84534:	d503201f 	nop
   84538:	d503201f 	nop
   8453c:	d503201f 	nop
   84540:	d503201f 	nop
   84544:	d503201f 	nop
   84548:	d503201f 	nop
   8454c:	d503201f 	nop
   84550:	d503201f 	nop
   84554:	d503201f 	nop
   84558:	d503201f 	nop
   8455c:	d503201f 	nop
   84560:	d503201f 	nop
   84564:	d503201f 	nop
   84568:	d503201f 	nop
   8456c:	d503201f 	nop
   84570:	d503201f 	nop
   84574:	d503201f 	nop
   84578:	d503201f 	nop
   8457c:	d503201f 	nop
	ventry	error_invalid_el0_64			// Error 64-bit EL0
   84580:	140000ce 	b	848b8 <error_invalid_el0_64>
   84584:	d503201f 	nop
   84588:	d503201f 	nop
   8458c:	d503201f 	nop
   84590:	d503201f 	nop
   84594:	d503201f 	nop
   84598:	d503201f 	nop
   8459c:	d503201f 	nop
   845a0:	d503201f 	nop
   845a4:	d503201f 	nop
   845a8:	d503201f 	nop
   845ac:	d503201f 	nop
   845b0:	d503201f 	nop
   845b4:	d503201f 	nop
   845b8:	d503201f 	nop
   845bc:	d503201f 	nop
   845c0:	d503201f 	nop
   845c4:	d503201f 	nop
   845c8:	d503201f 	nop
   845cc:	d503201f 	nop
   845d0:	d503201f 	nop
   845d4:	d503201f 	nop
   845d8:	d503201f 	nop
   845dc:	d503201f 	nop
   845e0:	d503201f 	nop
   845e4:	d503201f 	nop
   845e8:	d503201f 	nop
   845ec:	d503201f 	nop
   845f0:	d503201f 	nop
   845f4:	d503201f 	nop
   845f8:	d503201f 	nop
   845fc:	d503201f 	nop

	/*  EL0_32 -- Exception is taken from EL0 executing in 32-bit mode
			The exceptions caused in 32-bit user programs  */
	ventry	sync_invalid_el0_32			// Synchronous 32-bit EL0
   84600:	140000b5 	b	848d4 <sync_invalid_el0_32>
   84604:	d503201f 	nop
   84608:	d503201f 	nop
   8460c:	d503201f 	nop
   84610:	d503201f 	nop
   84614:	d503201f 	nop
   84618:	d503201f 	nop
   8461c:	d503201f 	nop
   84620:	d503201f 	nop
   84624:	d503201f 	nop
   84628:	d503201f 	nop
   8462c:	d503201f 	nop
   84630:	d503201f 	nop
   84634:	d503201f 	nop
   84638:	d503201f 	nop
   8463c:	d503201f 	nop
   84640:	d503201f 	nop
   84644:	d503201f 	nop
   84648:	d503201f 	nop
   8464c:	d503201f 	nop
   84650:	d503201f 	nop
   84654:	d503201f 	nop
   84658:	d503201f 	nop
   8465c:	d503201f 	nop
   84660:	d503201f 	nop
   84664:	d503201f 	nop
   84668:	d503201f 	nop
   8466c:	d503201f 	nop
   84670:	d503201f 	nop
   84674:	d503201f 	nop
   84678:	d503201f 	nop
   8467c:	d503201f 	nop
	ventry	irq_invalid_el0_32			// IRQ 32-bit EL0
   84680:	1400009c 	b	848f0 <irq_invalid_el0_32>
   84684:	d503201f 	nop
   84688:	d503201f 	nop
   8468c:	d503201f 	nop
   84690:	d503201f 	nop
   84694:	d503201f 	nop
   84698:	d503201f 	nop
   8469c:	d503201f 	nop
   846a0:	d503201f 	nop
   846a4:	d503201f 	nop
   846a8:	d503201f 	nop
   846ac:	d503201f 	nop
   846b0:	d503201f 	nop
   846b4:	d503201f 	nop
   846b8:	d503201f 	nop
   846bc:	d503201f 	nop
   846c0:	d503201f 	nop
   846c4:	d503201f 	nop
   846c8:	d503201f 	nop
   846cc:	d503201f 	nop
   846d0:	d503201f 	nop
   846d4:	d503201f 	nop
   846d8:	d503201f 	nop
   846dc:	d503201f 	nop
   846e0:	d503201f 	nop
   846e4:	d503201f 	nop
   846e8:	d503201f 	nop
   846ec:	d503201f 	nop
   846f0:	d503201f 	nop
   846f4:	d503201f 	nop
   846f8:	d503201f 	nop
   846fc:	d503201f 	nop
	ventry	fiq_invalid_el0_32			// FIQ 32-bit EL0
   84700:	14000083 	b	8490c <fiq_invalid_el0_32>
   84704:	d503201f 	nop
   84708:	d503201f 	nop
   8470c:	d503201f 	nop
   84710:	d503201f 	nop
   84714:	d503201f 	nop
   84718:	d503201f 	nop
   8471c:	d503201f 	nop
   84720:	d503201f 	nop
   84724:	d503201f 	nop
   84728:	d503201f 	nop
   8472c:	d503201f 	nop
   84730:	d503201f 	nop
   84734:	d503201f 	nop
   84738:	d503201f 	nop
   8473c:	d503201f 	nop
   84740:	d503201f 	nop
   84744:	d503201f 	nop
   84748:	d503201f 	nop
   8474c:	d503201f 	nop
   84750:	d503201f 	nop
   84754:	d503201f 	nop
   84758:	d503201f 	nop
   8475c:	d503201f 	nop
   84760:	d503201f 	nop
   84764:	d503201f 	nop
   84768:	d503201f 	nop
   8476c:	d503201f 	nop
   84770:	d503201f 	nop
   84774:	d503201f 	nop
   84778:	d503201f 	nop
   8477c:	d503201f 	nop
	ventry	error_invalid_el0_32			// Error 32-bit EL0
   84780:	1400006a 	b	84928 <error_invalid_el0_32>

0000000000084784 <sync_invalid_el1t>:

sync_invalid_el1t:
	handle_invalid_entry  SYNC_INVALID_EL1t
   84784:	d2800000 	mov	x0, #0x0                   	// #0
   84788:	d5385201 	mrs	x1, esr_el1
   8478c:	d5384022 	mrs	x2, elr_el1
   84790:	d5386003 	mrs	x3, far_el1
   84794:	97fff06d 	bl	80948 <show_invalid_entry_message>
   84798:	d50342df 	msr	daifset, #0x2
   8479c:	1400007d 	b	84990 <err_hang>

00000000000847a0 <irq_invalid_el1t>:

irq_invalid_el1t:
	handle_invalid_entry  IRQ_INVALID_EL1t
   847a0:	d2800020 	mov	x0, #0x1                   	// #1
   847a4:	d5385201 	mrs	x1, esr_el1
   847a8:	d5384022 	mrs	x2, elr_el1
   847ac:	d5386003 	mrs	x3, far_el1
   847b0:	97fff066 	bl	80948 <show_invalid_entry_message>
   847b4:	d50342df 	msr	daifset, #0x2
   847b8:	14000076 	b	84990 <err_hang>

00000000000847bc <fiq_invalid_el1t>:

fiq_invalid_el1t:
	handle_invalid_entry  FIQ_INVALID_EL1t
   847bc:	d2800040 	mov	x0, #0x2                   	// #2
   847c0:	d5385201 	mrs	x1, esr_el1
   847c4:	d5384022 	mrs	x2, elr_el1
   847c8:	d5386003 	mrs	x3, far_el1
   847cc:	97fff05f 	bl	80948 <show_invalid_entry_message>
   847d0:	d50342df 	msr	daifset, #0x2
   847d4:	1400006f 	b	84990 <err_hang>

00000000000847d8 <error_invalid_el1t>:

error_invalid_el1t:
	handle_invalid_entry  ERROR_INVALID_EL1t
   847d8:	d2800060 	mov	x0, #0x3                   	// #3
   847dc:	d5385201 	mrs	x1, esr_el1
   847e0:	d5384022 	mrs	x2, elr_el1
   847e4:	d5386003 	mrs	x3, far_el1
   847e8:	97fff058 	bl	80948 <show_invalid_entry_message>
   847ec:	d50342df 	msr	daifset, #0x2
   847f0:	14000068 	b	84990 <err_hang>

00000000000847f4 <sync_invalid_el1h>:

sync_invalid_el1h:
	handle_invalid_entry  SYNC_INVALID_EL1h
   847f4:	d2800080 	mov	x0, #0x4                   	// #4
   847f8:	d5385201 	mrs	x1, esr_el1
   847fc:	d5384022 	mrs	x2, elr_el1
   84800:	d5386003 	mrs	x3, far_el1
   84804:	97fff051 	bl	80948 <show_invalid_entry_message>
   84808:	d50342df 	msr	daifset, #0x2
   8480c:	14000061 	b	84990 <err_hang>

0000000000084810 <fiq_invalid_el1h>:

fiq_invalid_el1h:
	handle_invalid_entry  FIQ_INVALID_EL1h
   84810:	d28000c0 	mov	x0, #0x6                   	// #6
   84814:	d5385201 	mrs	x1, esr_el1
   84818:	d5384022 	mrs	x2, elr_el1
   8481c:	d5386003 	mrs	x3, far_el1
   84820:	97fff04a 	bl	80948 <show_invalid_entry_message>
   84824:	d50342df 	msr	daifset, #0x2
   84828:	1400005a 	b	84990 <err_hang>

000000000008482c <error_invalid_el1h>:

error_invalid_el1h:
	handle_invalid_entry  ERROR_INVALID_EL1h
   8482c:	d28000e0 	mov	x0, #0x7                   	// #7
   84830:	d5385201 	mrs	x1, esr_el1
   84834:	d5384022 	mrs	x2, elr_el1
   84838:	d5386003 	mrs	x3, far_el1
   8483c:	97fff043 	bl	80948 <show_invalid_entry_message>
   84840:	d50342df 	msr	daifset, #0x2
   84844:	14000053 	b	84990 <err_hang>

0000000000084848 <sync_invalid_el0_64>:

sync_invalid_el0_64:
	handle_invalid_entry  SYNC_INVALID_EL0_64
   84848:	d2800100 	mov	x0, #0x8                   	// #8
   8484c:	d5385201 	mrs	x1, esr_el1
   84850:	d5384022 	mrs	x2, elr_el1
   84854:	d5386003 	mrs	x3, far_el1
   84858:	97fff03c 	bl	80948 <show_invalid_entry_message>
   8485c:	d50342df 	msr	daifset, #0x2
   84860:	1400004c 	b	84990 <err_hang>

0000000000084864 <irq_invalid_el0_64>:

irq_invalid_el0_64:
	handle_invalid_entry  IRQ_INVALID_EL0_64
   84864:	d2800120 	mov	x0, #0x9                   	// #9
   84868:	d5385201 	mrs	x1, esr_el1
   8486c:	d5384022 	mrs	x2, elr_el1
   84870:	d5386003 	mrs	x3, far_el1
   84874:	97fff035 	bl	80948 <show_invalid_entry_message>
   84878:	d50342df 	msr	daifset, #0x2
   8487c:	14000045 	b	84990 <err_hang>

0000000000084880 <irq_invalid_el1h>:

irq_invalid_el1h:
	handle_invalid_entry  IRQ_INVALID_EL1h
   84880:	d28000a0 	mov	x0, #0x5                   	// #5
   84884:	d5385201 	mrs	x1, esr_el1
   84888:	d5384022 	mrs	x2, elr_el1
   8488c:	d5386003 	mrs	x3, far_el1
   84890:	97fff02e 	bl	80948 <show_invalid_entry_message>
   84894:	d50342df 	msr	daifset, #0x2
   84898:	1400003e 	b	84990 <err_hang>

000000000008489c <fiq_invalid_el0_64>:
	
fiq_invalid_el0_64:
	handle_invalid_entry  FIQ_INVALID_EL0_64
   8489c:	d2800140 	mov	x0, #0xa                   	// #10
   848a0:	d5385201 	mrs	x1, esr_el1
   848a4:	d5384022 	mrs	x2, elr_el1
   848a8:	d5386003 	mrs	x3, far_el1
   848ac:	97fff027 	bl	80948 <show_invalid_entry_message>
   848b0:	d50342df 	msr	daifset, #0x2
   848b4:	14000037 	b	84990 <err_hang>

00000000000848b8 <error_invalid_el0_64>:

error_invalid_el0_64:
	handle_invalid_entry  ERROR_INVALID_EL0_64
   848b8:	d2800160 	mov	x0, #0xb                   	// #11
   848bc:	d5385201 	mrs	x1, esr_el1
   848c0:	d5384022 	mrs	x2, elr_el1
   848c4:	d5386003 	mrs	x3, far_el1
   848c8:	97fff020 	bl	80948 <show_invalid_entry_message>
   848cc:	d50342df 	msr	daifset, #0x2
   848d0:	14000030 	b	84990 <err_hang>

00000000000848d4 <sync_invalid_el0_32>:

sync_invalid_el0_32:
	handle_invalid_entry  SYNC_INVALID_EL0_32
   848d4:	d2800180 	mov	x0, #0xc                   	// #12
   848d8:	d5385201 	mrs	x1, esr_el1
   848dc:	d5384022 	mrs	x2, elr_el1
   848e0:	d5386003 	mrs	x3, far_el1
   848e4:	97fff019 	bl	80948 <show_invalid_entry_message>
   848e8:	d50342df 	msr	daifset, #0x2
   848ec:	14000029 	b	84990 <err_hang>

00000000000848f0 <irq_invalid_el0_32>:

irq_invalid_el0_32:
	handle_invalid_entry  IRQ_INVALID_EL0_32
   848f0:	d28001a0 	mov	x0, #0xd                   	// #13
   848f4:	d5385201 	mrs	x1, esr_el1
   848f8:	d5384022 	mrs	x2, elr_el1
   848fc:	d5386003 	mrs	x3, far_el1
   84900:	97fff012 	bl	80948 <show_invalid_entry_message>
   84904:	d50342df 	msr	daifset, #0x2
   84908:	14000022 	b	84990 <err_hang>

000000000008490c <fiq_invalid_el0_32>:

fiq_invalid_el0_32:
	handle_invalid_entry  FIQ_INVALID_EL0_32
   8490c:	d28001c0 	mov	x0, #0xe                   	// #14
   84910:	d5385201 	mrs	x1, esr_el1
   84914:	d5384022 	mrs	x2, elr_el1
   84918:	d5386003 	mrs	x3, far_el1
   8491c:	97fff00b 	bl	80948 <show_invalid_entry_message>
   84920:	d50342df 	msr	daifset, #0x2
   84924:	1400001b 	b	84990 <err_hang>

0000000000084928 <error_invalid_el0_32>:

error_invalid_el0_32:
	handle_invalid_entry  ERROR_INVALID_EL0_32
   84928:	d28001e0 	mov	x0, #0xf                   	// #15
   8492c:	d5385201 	mrs	x1, esr_el1
   84930:	d5384022 	mrs	x2, elr_el1
   84934:	d5386003 	mrs	x3, far_el1
   84938:	97fff004 	bl	80948 <show_invalid_entry_message>
   8493c:	d50342df 	msr	daifset, #0x2
   84940:	14000014 	b	84990 <err_hang>

0000000000084944 <el1_irq>:
/* ---- end of EL1 vectors ----- */


el1_irq:
	kernel_entry 
	bl	handle_irq
   84944:	97ffefbb 	bl	80830 <handle_irq>
	kernel_exit 
   84948:	a94007e0 	ldp	x0, x1, [sp]
   8494c:	a9410fe2 	ldp	x2, x3, [sp, #16]
   84950:	a94217e4 	ldp	x4, x5, [sp, #32]
   84954:	a9431fe6 	ldp	x6, x7, [sp, #48]
   84958:	a94427e8 	ldp	x8, x9, [sp, #64]
   8495c:	a9452fea 	ldp	x10, x11, [sp, #80]
   84960:	a94637ec 	ldp	x12, x13, [sp, #96]
   84964:	a9473fee 	ldp	x14, x15, [sp, #112]
   84968:	a94847f0 	ldp	x16, x17, [sp, #128]
   8496c:	a9494ff2 	ldp	x18, x19, [sp, #144]
   84970:	a94a57f4 	ldp	x20, x21, [sp, #160]
   84974:	a94b5ff6 	ldp	x22, x23, [sp, #176]
   84978:	a94c67f8 	ldp	x24, x25, [sp, #192]
   8497c:	a94d6ffa 	ldp	x26, x27, [sp, #208]
   84980:	a94e77fc 	ldp	x28, x29, [sp, #224]
   84984:	f9407bfe 	ldr	x30, [sp, #240]
   84988:	910483ff 	add	sp, sp, #0x120
   8498c:	d69f03e0 	eret

0000000000084990 <err_hang>:

.globl err_hang
err_hang: b err_hang
   84990:	14000000 	b	84990 <err_hang>

0000000000084994 <enable_irq>:

// ----------------- irq related --------------------------- //
// daifclr/set 
.globl enable_irq
enable_irq:
	msr    daifclr, #0b0010 
   84994:	d50342ff 	msr	daifclr, #0x2
	ret
   84998:	d65f03c0 	ret

000000000008499c <disable_irq>:

.globl disable_irq
disable_irq:
	msr	    daifset, #0b0010 
   8499c:	d50342df 	msr	daifset, #0x2
	ret 
   849a0:	d65f03c0 	ret

00000000000849a4 <is_irq_masked>:

.global is_irq_masked
is_irq_masked:
	// whereas daifset/clr are lowest four bits, daif bits are bit9--6
	// https://developer.arm.com/documentation/ddi0601/2023-12/AArch64-Registers/DAIF--Interrupt-Mask-Bits
	mrs x0, daif 
   849a4:	d53b4220 	mrs	x0, daif
	lsr x0, x0, #7 
   849a8:	d347fc00 	lsr	x0, x0, #7
	and x0, x0, #1
   849ac:	92400000 	and	x0, x0, #0x1
	ret
   849b0:	d65f03c0 	ret

00000000000849b4 <cpuid>:

.global cpuid
cpuid: 
	mrs	x0, mpidr_el1
   849b4:	d53800a0 	mrs	x0, mpidr_el1
	and	x0, x0, #0xFF
   849b8:	92401c00 	and	x0, x0, #0xff
	ret
   849bc:	d65f03c0 	ret

00000000000849c0 <memcpy_aligned>:
/* Below: the XXX_aligned funcs are faster than normal (unaligned) variants, but
    MUST BE used with care to avoid nasty bugs. unaligned addr will corrupt/miss
    contents. unless the buf is large, the extra speed is not worth it */
.globl memcpy_aligned
memcpy_aligned:
 	ldr x3, [x1], #8
   849c0:	f8408423 	ldr	x3, [x1], #8
 	str x3, [x0], #8
   849c4:	f8008403 	str	x3, [x0], #8
	subs x2, x2, #8
   849c8:	f1002042 	subs	x2, x2, #0x8
 	b.gt memcpy_aligned
   849cc:	54ffffac 	b.gt	849c0 <memcpy_aligned>
 	ret
   849d0:	d65f03c0 	ret

00000000000849d4 <memzero_aligned>:

.globl memzero_aligned
memzero_aligned:
	str xzr, [x0], #8
   849d4:	f800841f 	str	xzr, [x0], #8
	subs x1, x1, #8
   849d8:	f1002021 	subs	x1, x1, #0x8
	b.gt memzero_aligned
   849dc:	54ffffcc 	b.gt	849d4 <memzero_aligned>
	ret
   849e0:	d65f03c0 	ret

00000000000849e4 <get_el>:

.globl get_el
get_el:
	mrs x0, CurrentEL
   849e4:	d5384240 	mrs	x0, currentel
	lsr x0, x0, #2
   849e8:	d342fc00 	lsr	x0, x0, #2
	ret
   849ec:	d65f03c0 	ret
