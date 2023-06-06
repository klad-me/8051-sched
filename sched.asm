		.module sched
		
		
maxSleepTime = 1500						; максимально допустимое время сна
		
		
		.area   OSEG(OVR,DATA)
		
_tcbInit_PARM_2::
		.ds		2
		
		
		.area	XSEG(XDATA)
		
		
		.area	DSEG(DATA)
		
_taskWait8_PARM_2::						; в DSEG, т.к. будем менять в taskSleep()
_taskWait16_PARM_2::
_taskWait32_PARM_2::
		.ds		2
		
_currentTime::							; текущее время
		.ds		4
		
_wakeFlags::							; флаги просыпания
		.ds		1
		
sleepTime::								; следующее время сна
		.ds		4
		
currentWake::							; текущие флаги просыпания
		.ds		1
		
currentTCB:								; TCB текущей выполняемой задачи
		.ds		2
		
schedulerSP:							; SP шедулера
		.ds		1
		
		
		
		.area	CSEG(CODE)
		
		.globl	_schedCpuSleep
		.globl	_tcbList
		
		
		
		
; Инициализация TCB
;  DPTR   - TCB
;  PARM_2 - код задачи
_tcbInit::
		mov		R0, #5					; очищаем флаги пробуждения и время сна
		clr		A
		
1$:		movx	@DPTR, A
		inc		DPTR
		djnz	R0, 1$
		
		mov		A, #2					; размер стека
		movx	@DPTR, A
		inc		DPTR
		
		mov		A, _tcbInit_PARM_2+0	; адрес задачи
		movx	@DPTR, A
		inc		DPTR
		mov		A, _tcbInit_PARM_2+1
		movx	@DPTR, A
		
		ret
		
		
		
; Запустить шедулер, прерывания должны быть отключены
_schedStart::
		mov		DPL, #<(_tcbList+0)		; получаем в DPTR начало списка TCB
		mov		DPH, #>(_tcbList+1)
		
		mov		currentWake, _wakeFlags	; получаем флаги просыпания
		mov		_wakeFlags, #0
		
		mov		sleepTime+0, #maxSleepTime	; устанавливаем максимальное время сна
		mov		sleepTime+1, #maxSleepTime >> 8
		mov		sleepTime+2, #maxSleepTime >> 16
		mov		sleepTime+3, #maxSleepTime >> 24
		
1$:		clr		A
		movc	A, @A+DPTR				; получаем адрес текущаего TCB
		inc		DPTR
		mov		currentTCB+0, A
		clr		A
		movc	A, @A+DPTR
		inc		DPTR
		mov		currentTCB+1, A
		
		orl		A, currentTCB+0			; проверяем на конец списка
		jz		2$
		
		push	DPL						; сохраняем указатель на список TCB
		push	DPH
		lcall	taskRun					; запускаем задачу
		pop		DPH						; восстанавливаем указатель на TCB
		pop		DPL
		
		sjmp	1$						; переходим на следующую задачу
		
		
2$:		mov		A, _wakeFlags			; если есть флаги просыпания, то запускаем опять все задачи
		jnz		_schedStart
		
		mov		A, sleepTime+0			; проверяем, надо ли спать
		orl		A, sleepTime+1
		orl		A, sleepTime+2
		orl		A, sleepTime+3
		jz		_schedStart
		
		mov		DPL, sleepTime+0		; засыпаем
		mov		DPH, sleepTime+1
		mov		B, sleepTime+2
		mov		A, sleepTime+3
		lcall	_schedCpuSleep
		
		sjmp	_schedStart
		
		
		
		
		
; Запустить задачу
taskRun:
		mov		DPL, currentTCB+0		; DPTR - указатель на TCB
		mov		DPH, currentTCB+1
		
		movx	A, @DPTR				; получаем флаги пробуждения
		inc		DPTR
		anl		A, currentWake			; флаги просыпания в R4
		mov		R4, A
		
		clr		C						; проверяем время пробуждения, заодно вычисляем оставшееся время сна в R3::R0
		
		movx	A, @DPTR
		inc		DPTR
		subb	A, _currentTime+0
		mov		R0, A
		
		movx	A, @DPTR
		inc		DPTR
		subb	A, _currentTime+1
		mov		R1, A
		
		movx	A, @DPTR
		inc		DPTR
		subb	A, _currentTime+2
		mov		R2, A
		
		movx	A, @DPTR
		inc		DPTR
		subb	A, _currentTime+3
		mov		R3, A
		
		orl		A, R0					; проверяем на нулевое врем
		orl		A, R1
		orl		A, R2
		jz		1$
		
		jc		1$						; проверяем на таймаут
		
		cjne	R4, #0, 1$				; проверяем флаги просыпания
		
		lcall	updateSleepTime			; задачу запускать не надо, просто обновляем время сна планировщика
		ret								; перходим на следующую задачу
		
		
1$:		mov		schedulerSP, SP			; сохраняем SP
		
		movx	A, @DPTR				; получаем размер стека в R2
		inc		DPTR
		mov		R2, A
		
		mov		R0, SP					; R0 - указатель стека
		mov		R1, A					; R1 - счётчик
		
2$:		inc		R0						; копируем стек
		movx	A, @DPTR
		inc		DPTR
		mov		@R0, A
		djnz	R1, 2$
		
		mov		A, R2					; смещаем SP на верх стека
		add		A, SP
		mov		SP, A
		
		setb	EA						; разрешаем прерывания
		
		mov		DPL, R4					; возвращаем флаги просыпания
		ret								; запускаем задачу
		
		
		
		
; Заснуть на 1мс
_taskSleep1::
		mov		DPL, #1
		
		
; Заснуть (время 8 бит)
;  DPL - время сна
_taskSleep8::
		mov		DPH, #0
		
		
; Заснуть (время 16 бит)
;  DPTR - время сна
_taskSleep16::
		clr		A
		mov		B, A
		
		
; Заснуть (время 32 бита)
;  A:B:DPTR - время сна
_taskSleep32::
		mov		_taskWait32_PARM_2, #0	; обнуляем флаги просыпания
		sjmp	_taskWait32
		
		
		
		
; Ожидать семафор (время 8 бит)
;  DPL    - время ожидания
;  PARM_2 - семафор
_taskWait8::
		mov		DPH, #0
		
		
; Ожидать семафор (время 16 бит)
;  DPTR   - время ожидания
;  PARM_2 - семафор
_taskWait16::
		clr		A
		mov		B, A
		
		
; Ожидать семафор (время 32 бита)
;  A:B:DPTR - время ожидания
;  PARM_2   - семафор
_taskWait32::
		clr		EA						; отключаем прерывания
		
		mov		R0, DPL					; сохраняем время ожидания в R3..R0
		mov		R1, DPH
		mov		R2, B
		mov		R3, A
		
		lcall	updateSleepTime			; обновляем время сна планировщика
		
		mov		DPL, currentTCB+0		; получаем адрес TCB в DPTR
		mov		DPH, currentTCB+1
		
		mov		A, _taskWait32_PARM_2	; сохраняем семафоры
		movx	@DPTR,A
		inc		DPTR
		
		mov		A, R0					; сохраняем время просыпания
		add		A, _currentTime+0
		movx	@DPTR, A
		inc		DPTR
		
		mov		A, R1
		addc	A, _currentTime+1
		movx	@DPTR, A
		inc		DPTR
		
		mov		A, R2
		addc	A, _currentTime+2
		movx	@DPTR, A
		inc		DPTR
		
		mov		A, R3
		addc	A, _currentTime+3
		movx	@DPTR, A
		inc		DPTR
		
		mov		A, SP					; вычисляем использование стека
		clr		C
		subb	A, schedulerSP
		
		movx	@DPTR, A				; сохраняем размер стека
		inc		DPTR
		
		mov		R0, schedulerSP			; R0 - указатель стека
		mov		R1, A					; R1 - счётчик
		
1$:		inc		R0						; копируем стек
		mov		A, @R0
		movx	@DPTR, A
		inc		DPTR
		djnz	R1, 1$
		
		mov		SP, schedulerSP			; восстанавливаем SP планировщика
		
		ret								; возвращаемся в планировщик
		
		
		
		
; Обновляем sleepTime по времени сна в R3:R0
updateSleepTime:
		clr		C						; получаем следующее время сна планировщика
		mov		A, R0
		subb	A, sleepTime+0
		mov		A, R1
		subb	A, sleepTime+1
		mov		A, R2
		subb	A, sleepTime+2
		mov		A, R3
		subb	A, sleepTime+2
		jnc		1$
		
		mov		sleepTime+0, R0			; новое время сна планировщика (меньшее)
		mov		sleepTime+1, R1
		mov		sleepTime+2, R2
		mov		sleepTime+3, R3
		
1$:		ret
