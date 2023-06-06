# 8051-sched
8051 cooperative scheduler with semaphores.

For use with SDCC.

Example:


```C
#include <sched.h>


#define SEM_TEST	0x01


static __xdata uint8_t tcb1[64];
void code1(void)
{
	uint8_t n=0;
	while (1)
	{
		uart_hex(n++);
		uart_txs("code1\n");
		taskWake(SEM_TEST);
		taskSleep8(100);
	}
}


static __xdata uint8_t tcb2[64];
void code2(void)
{
	uint8_t n=0;
	while (1)
	{
		if (taskWait8(255, SEM_TEST))
		{
			uart_hex(n);
			n+=2;
			uart_txs("code2\n");
		}
	}
}


const __xdata uint8_t* __code tcbList[]=
{
	tcb1,
	tcb2,
	0
};


void schedCpuSleep(uint32_t t)
{
	delay_ms(t);
	currentTime+=t;
}


void mainProgram(void)
{
	tcbInit(tcb1, code1);
	tcbInit(tcb2, code2);
	
	schedStart();
}

```
