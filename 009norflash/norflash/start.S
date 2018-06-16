
.text
.global _start

_start:
	b reset          /* vector 0 : reset */
	ldr pc, und_addr /* vector 4 : und */
	ldr pc, swi_addr /* vector 8 : swi */
	b halt			 /* vector 0x0c : prefetch aboot */
	b halt			 /* vector 0x10 : data abort */
	b halt			 /* vector 0x14 : reserved */
	ldr pc, irq_addr /* vector 0x18 : irq */
	b halt			 /* vector 0x1c : fiq */

und_addr:
	.word do_und

swi_addr:
	.word do_swi

irq_addr:
	.word do_irq	

do_und:
	/* ִ�е�����֮ǰ:
	 * 1. lr_und�����б��ж�ģʽ�е���һ������ִ�е�ָ��ĵ�ַ
	 * 2. SPSR_und�����б��ж�ģʽ��CPSR
	 * 3. CPSR�е�M4-M0������Ϊ11011, ���뵽undģʽ
	 * 4. ����0x4�ĵط�ִ�г��� 
	 */

	/* sp_undδ����, �������� */
	ldr sp, =0x34000000

	/* �����ֳ� */
	/* ��und�쳣�����������п��ܻ��޸�r0-r12, �����ȱ��� */
	/* lr���쳣�������ķ��ص�ַ, ҲҪ���� */
	stmdb sp!, {r0-r12, lr}  
	
	/* ����und�쳣 */
	mrs r0, cpsr
	ldr r1, =und_string
	bl printException
	
	/* �ָ��ֳ� */
	ldmia sp!, {r0-r12, pc}^  /* ^���spsr��ֵ�ָ���cpsr�� */

und_string:
	.string "UDEF"	
.align 4

do_swi:
	/* ִ�е�����֮ǰ:
	 * 1. lr_svc�����б��ж�ģʽ�е���һ������ִ�е�ָ��ĵ�ַ
	 * 2. SPSR_svc�����б��ж�ģʽ��CPSR
	 * 3. CPSR�е�M4-M0������Ϊ10011, ���뵽svcģʽ
	 * 4. ����0x08�ĵط�ִ�г��� 
	 */

	/* sp_svcδ����, �������� */
	ldr sp, =0x33e00000

	/* �����ֳ� */
	/* ��swi�쳣�����������п��ܻ��޸�r0-r12, �����ȱ��� */
	/* lr���쳣�������ķ��ص�ַ, ҲҪ���� */
	stmdb sp!, {r0-r12, lr}  

	mov r4, lr
	
	/* ����swi�쳣 */
	mrs r0, cpsr
	ldr r1, =swi_string
	bl printException
	
	/* �ָ��ֳ� */
	ldmia sp!, {r0-r12, pc}^  /* ^���spsr��ֵ�ָ���cpsr�� */
	
swi_string:
	.string "SWI"

.align 4

do_irq:
	/* ִ�е�����֮ǰ:
	 * 1. lr_irq�����б��ж�ģʽ�е���һ������ִ�е�ָ��ĵ�ַ
	 * 2. SPSR_irq�����б��ж�ģʽ��CPSR
	 * 3. CPSR�е�M4-M0������Ϊ10010, ���뵽irqģʽ
	 * 4. ����0x18�ĵط�ִ�г��� 
	 */

	/* sp_irqδ����, �������� */
	ldr sp, =0x33d00000

	/* �����ֳ� */
	/* ��irq�쳣�����������п��ܻ��޸�r0-r12, �����ȱ��� */
	/* lr-4���쳣�������ķ��ص�ַ, ҲҪ���� */
	sub lr, lr, #4
	stmdb sp!, {r0-r12, lr}  
	
	/* ����irq�쳣 */
	bl handle_irq_c
	
	/* �ָ��ֳ� */
	ldmia sp!, {r0-r12, pc}^  /* ^���spsr_irq��ֵ�ָ���cpsr�� */


reset:
	/**close watch dog ,defalt is open*/
	ldr r0 , =0x53000000
	ldr r1 , = 0
	str r1 , [r0]
	/*set MPLL,FCLK:HCLK:PCLK =400M:100M:50M */
	/*LOCKTIME (0x4C000000 )reste value 0xFFFFFFFF*/
	ldr r0, = 0x4C000000
	ldr r1, = 0xFFFFFFFF
	str r1,[r0]

	/*CLKDIVN (0x4C000014 ) = 0x5,tFCLK:tHCLK:tPCLK = 1:4:8*/
	ldr r0, = 0x4C000014
	ldr r1, = 0x5
	str r1,[r0]

	/*set cpu asynchronous bus mode*/
	mrc p15,0,r0,c1,c0,0
	orr r0,r0,#0xc0000000  //1_nF:OR:R1_iA
	mcr p15,0,r0,c1,c0,0

	/*MPLLCON  (0x4C000004  ) = (92<<12)|(1<<4)|(1<<0) */
	ldr r0, = 0x4C000004
	ldr r1, = (92<<12)|(1<<4)|(1<<0)
	str r1,[r0]


	/*set sp  Stacks*/
	mov r1, #0
	ldr r0, [r1] /* read back byte */
	str r1, [r1] /* 0->[0] */ 
	ldr r2, [r1] /* r2=[0] */
	cmp r1, r2   /* r1==r2? �����ȱ�ʾ��NAND���� */
	ldr sp, =0x40000000+4096 /* �ȼ�����nor���� */
	moveq sp, #4096  /* nand���� */
	streq r0, [r1]   /* �ָ�ԭ����ֵ */

	/*init sdram*/
	bl sdram_init 
 
	/*�������д���Σ����ݶε�sdram*/
	bl copy2sdram 

	/*���bss��*/
	bl clean_bss 

	/* ��λ֮��, cpu����svcģʽ
	 * ����, �л���usrģʽ
	 */
	mrs r0, cpsr         /* ����cpsr */
	bic r0, r0, #0xf     /* �޸�M4-M0Ϊ0b10000, ����usrģʽ */
	bic r0, r0, #(1<<7)  /* ���Iλ, ʹ���ж� */
	msr cpsr, r0

	/* ���� sp_usr */
	ldr sp, =0x33f00000

	ldr pc, =uart
uart:
	bl uart_init	/*115200 8n1*/

und_code:
	.word 0xdeadc0de  /* ģ��δ����ָ�����δ����ָ���ж� */

	swi 0x123  /* ִ�д�����, ����SWI(Software Interrupt)�쳣, ����0x8ִ�� */

	//bl main  /* ʹ��BL���������ת, ������Ȼ��NOR/sramִ�� */
	ldr pc, =main  /* ������ת, ����SDRAM */

halt:
	b halt


	/*����дλ���޹��룿
	������취��������������
	1.ʹ�������ת����B/BL
	2.�ض�λ֮ǰ����ʹ�þ��Ե�ַ�����粻�ɷ���ȫ�ֱ���/��̬�������г�ʼֵ������
	3.�ض�λ֮��ʹ�þ�����ת������ת��runtime address�����磺ldr pc, = main
	*/


