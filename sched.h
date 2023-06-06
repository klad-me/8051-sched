#ifndef SCHED_H
#define SCHED_H


#include <stdint.h>


typedef uint8_t sem_t;
typedef void (*task_code_t)(void);


extern const __xdata uint8_t* __code tcbList[];

extern volatile __data uint32_t currentTime;
extern volatile __data sem_t wakeFlags;


// Инициализация TCB (каждый TCB содержит 6 байт состояния + стэк вызовов)
void tcbInit(uint8_t __xdata *tcb, task_code_t code);

// Запустить планировщик (вызов не вернется)
void schedStart(void);

// Планировщик запускает эту функцию, когда надо спать (надо определить извне)
extern void schedCpuSleep(uint32_t t);

// Спать
void taskSleep1 (void);
void taskSleep8 (uint8_t  t);
void taskSleep16(uint16_t t);
void taskSleep32(uint32_t t);

// Ожидать семафор
sem_t taskWait8 (uint8_t  t, sem_t wait);
sem_t taskWait16(uint16_t t, sem_t wait);
sem_t taskWait32(uint32_t t, sem_t wait);

// Активировать семафор
#define taskWake(sem)			do{ __critical{ wakeFlags|=(sem); } }while(0)
#define taskWakeFromIsr(sem)	do{ wakeFlags|=(sem); }while(0)


#endif
