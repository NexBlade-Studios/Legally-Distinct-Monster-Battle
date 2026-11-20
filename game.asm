;
; LEGALLY DISTINCT MONSTER CATCHING
;

; Register convention
;  rbx = attacker pointer, r12 = defender pointer
;  syscall clobbers (overwrited by syscall) rax, rdi, rsi, rdx, rcx, r11
;  anything needed across a print lives in rbx, r12, or the stack

F_HP      equ 0
F_MAXHP   equ 1
F_ATK     equ 2
F_DEF     equ 3
F_GUARD   equ 4
F_NAMELEN equ 5
F_NAME    equ 6
F_SIZE    equ 14

section .bss
	player resb F_SIZE
	enemy resb F_SIZE
	num_buffer resb 20 ; cannot automatically print integers so a buffer is used
	inbuf resb 16
	seed resq 1
	sleep_time resq	2

section .data
	title:
	%include "art.inc"
	title_len equ $ - title

	; Print messages
	msg db "You have been challenged to BATTLE!"
	msg_len equ $ - msg
	menu db "1) Strike 2) Heavy Slam 3) Guard 4) Recover", 10
	menu_len equ $ - menu
	win db "You have won!", 10
	win_len equ $ - win
	lose db "You have lost!", 10
	lose_len equ $ - lose

	; Moves
	strike db "STRIKE"
	strike_len equ $ - strike
	heavy_slam db "HEAVY SLAM"
	heavy_slam_len equ $ - heavy_slam
	guard db "GUARD"
	guard_len equ $ - guard
	recover db "RECOVER"
	recover_len equ $ - recover

	; Message fragments
	used db " used "
	used_len equ $ - used
	dealt db " dealt "
	dealt_len equ $ - dealt
	damage db " damage!", 10
	damage_len equ $ - damage
	missed db " missed!", 10
	missed_len equ $ - missed
	healed db " healed "
	healed_len equ $ - healed
	guarding db " is guarding!", 10
	guarding_len equ $ - guarding
	hp_txt db " HP: "
	hp_txt_len equ $ - hp_txt
	took db " took "
	took_len equ $ - took
	input db ">"
	input_len equ $ - input
	slash db "/"
	slash_len equ $ - slash

	; Player names
	crimson db "Crimson"
	crimson_len equ $ - crimson
	cobalt db "Cobalt"
	cobalt_len equ $ - cobalt

	nl db 10
	nl_len equ $ - nl

%macro PRINT 2		; %1 = string_name. %2 = length
	mov rax, 1
	mov rdi, 1
	mov rsi, %1
	mov rdx, %2
	syscall
%endmacro

section .text
	global _start

	delay:
		push rax
		push rdi
		push rsi
		push rdx
		push r14

		mov rax, r14
		mov [rel sleep_time], rax
		mov qword [rel sleep_time + 8], 0

		mov eax, 35
		lea rdi, [rel sleep_time]
		xor esi, esi
		syscall

		pop r14
		pop rdx
		pop rsi
		pop rdi
		pop rax

		ret

	init_fighters:
		; Crimson (player)
		mov byte [rel player + F_HP], 40
		mov byte [rel player + F_MAXHP], 40
		mov byte [rel player + F_ATK], 12
		mov byte [rel player + F_DEF], 8
		mov byte [rel player + F_GUARD], 0

		; Cobalt (enemy)
		mov byte [rel enemy + F_HP], 35
		mov byte [rel enemy + F_MAXHP], 35
		mov byte [rel enemy + F_ATK], 10
		mov byte [rel enemy + F_DEF], 6
		mov byte [rel enemy + F_GUARD], 0

		mov byte [rel player + F_NAMELEN], crimson_len
		lea rax, [rel crimson]
		mov [rel player + F_NAME], rax

		mov byte [rel enemy + F_NAMELEN], cobalt_len
		lea rax, [rel cobalt]
		mov [rel enemy + F_NAME], rax

		ret

	init_random:
		rdtsc

		shl rdx, 32
		or rax, rdx

		mov [rel seed], rax

		ret

	rand_range:
		mov r8, [rel seed]
		mov r9, 1103515245
		imul r8, r9
		add r8, 12345

		mov [rel seed], r8

		shr r8, 16
		mov r9, rax
		mov rax, r8
		xor edx, edx
		div r9
		mov rax, rdx

		ret

	print_num:
		lea rdi, [rel num_buffer + 20] ; loads actual address rather than just its contents
		mov rcx, 10

	.convert:
		xor rdx, rdx
		div rcx

		add dl , '0'
		dec rdi
		mov [rdi], dl

		test rax, rax
		jnz .convert

		; Print the converted number
		lea rdx, [rel num_buffer + 20]
		sub rdx, rdi

		mov rax, 1
		mov rsi, rdi
		mov rdi, 1
		syscall

		ret

	print_status:
		; Print fighter name
		mov rsi, [rbx + F_NAME]
		movzx rdx, byte [rbx + F_NAMELEN]
		mov rax, 1
		mov rdi, 1
		syscall

		; Print "HP: "
		PRINT hp_txt, hp_txt_len

		; Print current HP
		movzx eax, byte [rbx + F_HP]
		call print_num

		; Print /
		mov rax, 1
		mov rdi, 1
		mov rsi, slash
		mov rdx, slash_len
		syscall

		; Print maximum HP
		movzx eax, byte [rbx + F_MAXHP]
		call print_num

		PRINT nl, nl_len

		ret

	get_player_move:
		.prompt:
		PRINT menu, menu_len
		PRINT input, input_len

		mov rax, 0
		mov rdi, 0
		lea rsi, [rel inbuf]
		mov rdx, 16
		syscall

		test rax, rax
		jz exit

		movzx eax, byte [rel inbuf]
		sub eax, '1'

		cmp eax, 3
		ja .prompt

		ret

	get_enemy_move:
		mov eax, 4
		call rand_range

		ret

	enemy_turn:
		lea rbx, [rel enemy]
		lea r12, [rel player]

		call get_enemy_move

		cmp rax, 0
		je .strike
		cmp rax, 1
		je .heavy
		cmp  rax, 2
		je .guard
		jmp .recover

	.strike:
		call print_strike
		call apply_damage
		mov r14, 3
		call delay
		call print_damage

		ret
	.heavy:
		call print_heavy
		call apply_heavy
		cmp rax, 0
		je .missed
		mov r14, 3
		call delay
		call print_damage

		ret
	.missed:
		mov r14, 3
		call delay
		call print_miss

		ret
	.guard:
		call do_guard
		mov r14, 3
		call delay
		call print_guard

		ret
	.recover:
		call do_recover
		mov r14, 3
		call delay
		call print_recover

		ret

	calculate_strike:
		; Random damage from 5 to 10
		mov eax, 6
		call rand_range
		add rax, 5

		; Add attackers ATK value
		movzx r8d, byte [rbx + F_ATK]
		add rax, r8

		; Subtract defender's DEF
		movzx r8d, byte [r12 + F_DEF]
		sub rax, r8

		; Minimum damage = 1
		cmp rax, 1
		jge .done
		mov eax, 1

	.done:
		ret

	calculate_heavy:
		; Random damage from 10 to 16
		mov eax, 7
		call rand_range
		add rax, 10

		; Add attackers ATK
		movzx r8d, byte [rbx + F_ATK]
		add rax, r8

		; Subtract defender's DEF
		movzx r8d, byte [r12 + F_DEF]
		sub rax, r8

		; Minimum damage = 1
		cmp rax, 1
		jge .done
		mov eax, 1
	.done:
		ret

	apply_damage:
		call calculate_strike

		; Check if defender is guarding
		cmp byte [r12 + F_GUARD], 1
		jne .no_guard

		; Halve the damage
		shr rax, 1


		; Minimum damage = 1
		cmp rax, 1
		jge .clear_guard
		mov eax, 1

	.clear_guard:
		mov byte [r12  +F_GUARD], 0

	.no_guard:
		push rax

		movzx r8d, byte [r12 + F_HP]
		sub r8, rax

		jnc .store_hp
		xor r8d, r8d

	.store_hp:
		mov byte [r12 + F_HP], r8b

		pop rax

		ret

	apply_heavy:
		call check_heavy_miss

		; If rax = 1, heavy missed
		cmp rax, 1
		je .miss

		call calculate_heavy

		cmp byte [r12 + F_GUARD], 1
		jne .no_guard

		shr rax, 1

		cmp rax, 1
		jge .clear_guard
		mov eax, 1

	.clear_guard:
		mov byte [r12 + F_GUARD], 0

	.no_guard:
		push rax

		movzx r8d, byte [r12 + F_HP]
		sub r8, rax

		jnc .store_hp
		xor r8d, r8d

	.store_hp:
		mov byte [r12 + F_HP], r8b

		pop rax

		ret
	.miss:
		xor eax, eax

		ret

	check_heavy_miss:
		mov eax, 10
		call rand_range

		cmp rax, 2
		jbe .miss

		mov eax, 0

		ret

	.miss:
		mov eax, 1

		ret

	do_guard:
		mov byte [rbx + F_GUARD], 1

		ret

	do_recover:
		movzx rax, byte [rbx + F_HP]
		mov r9, rax

		add rax, 10

		movzx r8, byte [rbx + F_MAXHP]
		cmp rax, r8
		jbe .store

		mov rax, r8

	.store:
		mov byte [rbx + F_HP], al

		sub rax, r9

		ret

	print_strike:
		mov rsi, [rbx + F_NAME]
		movzx rdx, byte [rbx + F_NAMELEN]
		mov eax, 1
		mov edi, 1
		syscall

		PRINT used, used_len
		PRINT strike, strike_len
		PRINT nl, nl_len

		ret

	print_heavy:
		mov rsi, [rbx + F_NAME]
		movzx rdx, byte [rbx + F_NAMELEN]
		mov eax, 1
		mov edi, 1
		syscall

		PRINT used, used_len
		PRINT heavy_slam, heavy_slam_len
		PRINT nl, nl_len

		ret

	print_guard:
		mov rsi, [rbx + F_NAME]
		movzx rdx, byte [rbx + F_NAMELEN]
		mov eax, 1
		mov edi, 1
		syscall

		PRINT guarding, guarding_len

		ret

	print_recover:
		push rax

		mov rsi, [rbx + F_NAME]
		movzx rdx, byte [rbx + F_NAMELEN]
		mov eax, 1
		mov edi, 1
		syscall

		PRINT healed, healed_len

		pop rax
		call print_num

		PRINT nl, nl_len

		ret

	print_damage:
		push rax

		mov rsi, [r12 + F_NAME]
		movzx rdx, byte [r12 + F_NAMELEN]
		mov eax, 1
		mov edi, 1
		syscall

		PRINT took, took_len

		pop rax
		call print_num

		PRINT damage, damage_len

		ret

	print_miss:
		mov rsi, [rbx + F_NAME]
		movzx rdx, byte [rbx + F_NAMELEN]
		mov eax, 1
		mov edi, 1
		syscall

		PRINT missed, missed_len

		ret

	exit:
		mov rax, 60
		xor rdi, rdi
		syscall

	_start:
		call init_fighters
		call init_random

		; Display title artwork
		PRINT title, title_len
		PRINT nl, nl_len

		; Display battle introduction
		mov r14, 4
		call delay
		PRINT msg, msg_len
		PRINT nl, nl_len

	; Display menu and get player choice
	.battle_loop:
		lea rbx, [rel player]
		call print_status

		lea rbx, [rel enemy]
		call print_status

		mov r14, 3
		call delay
		call get_player_move
		mov r13, rax

		cmp r13, 0
		je .strike

		cmp r13, 1
		je .heavy

		cmp r13, 2
		je .guard

		jmp .recover

	.strike:
		lea rbx, [rel player]
		lea r12, [rel enemy]
		call print_strike
		call apply_damage
		mov r14, 3
		call delay
		call print_damage
		jmp .done

	.heavy:
		lea rbx, [rel player]
		lea r12, [rel enemy]
		call print_heavy
		call apply_heavy
		cmp rax, 0
		je .missed
		mov r14, 3
		call delay
		call print_damage
		jmp .done
	.missed:
		mov r14, 3
		call delay
		call print_miss
		jmp .done
	.guard:
		lea rbx, [rel player]
		call do_guard
		mov r14, 3
		call delay
		call print_guard
		jmp .done
	.recover:
		lea rbx, [rel player]
		call do_recover
		mov r14, 3
		call delay
		call print_recover
		jmp .done

	.done:
		cmp byte [rel enemy + F_HP], 0
		je .win

		call enemy_turn

		cmp byte [rel player +F_HP], 0
		je .lose

		jmp .battle_loop
	.win:
		PRINT win, win_len
		call exit
	.lose:
		PRINT lose, lose_len
		call exit
