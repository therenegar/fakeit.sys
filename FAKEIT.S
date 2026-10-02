.intel_syntax noprefix
.code16
.section .text
.global _start

/* FAKEIT.SYS v0.23
 * DOS CONFIG.SYS character device driver.
 * Caps BIOS-reported physical memory before an XMS/386 manager loads.
 * /MAX= is total visible RAM in KB.
 * 386+ required (E820/E881 handling and 32-bit arithmetic).
 */

_start:
    .word 0xFFFF, 0xFFFF             /* next device */
    .word 0xC000                     /* character device + IOCTL */
    .word strategy
    .word dev_interrupt
    .ascii "FAKEIT  "                /* 8-byte device name */

/* Request pointer saved by strategy entry. */
req_off:        .word 0
req_seg:        .word 0

/* Original INT 15h vector. */
old15_off:      .word 0
old15_seg:      .word 0

/* Runtime cap values, retained resident. */
max_kb:         .long 16384          /* total RAM in KB */
ext_kb:         .long 15360          /* KB above 1 MB */
limit_88:       .word 15360          /* AH=88h 16-bit KB cap */
cap_bytes:      .long 0x01000000      /* physical address ceiling */
limit_1to16:    .long 15360          /* KB in 1M..16M */
limit_above16:  .long 0              /* 64K blocks above 16M */

/* DOS strategy entry: ES:BX -> request packet. */
strategy:
    mov cs:[req_off], bx
    mov cs:[req_seg], es
    retf

/* DOS device interrupt entry. */
dev_interrupt:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es

    mov ax, cs:[req_seg]
    mov es, ax
    mov bx, cs:[req_off]
    mov al, es:[bx+2]                 /* command */
    cmp al, 0
    je .do_init
    cmp al, 3                          /* IOCTL input */
    je .do_ioctl
    jmp .unsupported

.do_init:
    call init_driver
    jmp .done

.do_ioctl:
    call ioctl_input
    jmp .done

.unsupported:
    mov word ptr es:[bx+3], 0x8103    /* DONE | ERROR | unknown command */

.done:
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    retf

/* ---------------- Resident INT 15h hook ---------------- */
int15_handler:
    /* Preserve the flags exactly as the original BIOS handler would see them. */
    pushf
    cmp ax, 0xE820
    je .go_e820
    cmp ax, 0xE881
    je .go_e881
    cmp ax, 0xE801
    je .go_e801
    cmp ax, 0xDA88
    je .go_da88
    cmp ah, 0x8A
    je .go_8a
    cmp ah, 0x88
    je .go_88
    popf
    ljmp [cs:old15_off]
.go_e820:
    popf
    jmp int15_e820
.go_e881:
    popf
    jmp int15_e881
.go_e801:
    popf
    jmp int15_e801
.go_da88:
    popf
    jmp int15_da88
.go_8a:
    popf
    jmp int15_8a
.go_88:
    popf
    jmp int15_88

/* Chain to old BIOS handler.  Each intercepted routine uses PUSHF/CALL FAR,
 * then patches the caller's saved CF at SS:[SP+4] before IRET.
 */
int15_88:
    pushf
    lcall [cs:old15_off]
    jc .err88
    push bp
    mov bp, sp
    and word ptr ss:[bp+6], 0xFFFE
    pop bp
    cmp ax, word ptr cs:[limit_88]
    jbe .ret88
    mov ax, word ptr cs:[limit_88]
.ret88:
    iret
.err88:
    push bp
    mov bp, sp
    or word ptr ss:[bp+6], 1
    pop bp
    iret

int15_8a:
    pushf
    lcall [cs:old15_off]
    jc .err8a
    push bp
    mov bp, sp
    and word ptr ss:[bp+6], 0xFFFE
    pop bp
    /* DX:AX = KB above 1 MB. Cap to ext_kb. */
    cmp dx, word ptr cs:[ext_kb+2]
    ja .cap8a
    jb .ret8a
    cmp ax, word ptr cs:[ext_kb]
    jbe .ret8a
.cap8a:
    mov ax, word ptr cs:[ext_kb]
    mov dx, word ptr cs:[ext_kb+2]
.ret8a:
    iret
.err8a:
    push bp
    mov bp, sp
    or word ptr ss:[bp+6], 1
    pop bp
    iret

int15_da88:
    pushf
    lcall [cs:old15_off]
    jc .errda
    push bp
    mov bp, sp
    and word ptr ss:[bp+6], 0xFFFE
    pop bp
    /* AMI: CL:BX = extended KB, AX=0. ext_kb is at most 0x3FFFFF here. */
    cmp cl, byte ptr cs:[ext_kb+2]
    ja .capda
    jb .retda
    cmp bx, word ptr cs:[ext_kb]
    jbe .retda
.capda:
    mov cl, byte ptr cs:[ext_kb+2]
    mov bx, word ptr cs:[ext_kb]
.retda:
    iret
.errda:
    push bp
    mov bp, sp
    or word ptr ss:[bp+6], 1
    pop bp
    iret

int15_e801:
    pushf
    lcall [cs:old15_off]
    jc .erre801
    push bp
    mov bp, sp
    and word ptr ss:[bp+6], 0xFFFE
    pop bp

    cmp ax, word ptr cs:[limit_1to16]
    jbe 1f
    mov ax, word ptr cs:[limit_1to16]
1:
    cmp cx, word ptr cs:[limit_1to16]
    jbe 2f
    mov cx, word ptr cs:[limit_1to16]
2:
    cmp bx, word ptr cs:[limit_above16]
    jbe 3f
    mov bx, word ptr cs:[limit_above16]
3:
    cmp dx, word ptr cs:[limit_above16]
    jbe .rete801
    mov dx, word ptr cs:[limit_above16]
.rete801:
    iret
.erre801:
    push bp
    mov bp, sp
    or word ptr ss:[bp+6], 1
    pop bp
    iret

int15_e881:
    pushf
    lcall [cs:old15_off]
    jc .erre881
    push bp
    mov bp, sp
    and word ptr ss:[bp+6], 0xFFFE
    pop bp

    cmp eax, dword ptr cs:[limit_1to16]
    jbe 1f
    mov eax, dword ptr cs:[limit_1to16]
1:
    cmp ecx, dword ptr cs:[limit_1to16]
    jbe 2f
    mov ecx, dword ptr cs:[limit_1to16]
2:
    cmp ebx, dword ptr cs:[limit_above16]
    jbe 3f
    mov ebx, dword ptr cs:[limit_above16]
3:
    cmp edx, dword ptr cs:[limit_above16]
    jbe .rete881
    mov edx, dword ptr cs:[limit_above16]
.rete881:
    iret
.erre881:
    push bp
    mov bp, sp
    or word ptr ss:[bp+6], 1
    pop bp
    iret

int15_e820:
    pushf
    lcall [cs:old15_off]
    jc .erre820
    push bp
    mov bp, sp
    and word ptr ss:[bp+6], 0xFFFE
    pop bp

    push ebp
    /* Only alter usable (type 1) entries with the standard 20-byte body. */
    cmp ecx, 20
    jb .rete820
    cmp dword ptr es:[di+16], 1
    jne .rete820

    /* Any usable range beginning at/above the cap becomes reserved. */
    cmp dword ptr es:[di+4], 0
    jne .reserve820
    mov ebp, dword ptr es:[di]
    cmp ebp, dword ptr cs:[cap_bytes]
    jae .reserve820

    /* Remaining bytes below cap = cap - base. */
    neg ebp
    add ebp, dword ptr cs:[cap_bytes]

    /* If returned length is larger than remaining space, trim it. */
    cmp dword ptr es:[di+12], 0
    jne .trim820
    cmp dword ptr es:[di+8], ebp
    jbe .rete820
.trim820:
    mov dword ptr es:[di+8], ebp
    mov dword ptr es:[di+12], 0
    jmp .rete820

.reserve820:
    mov dword ptr es:[di+16], 2       /* reserved */

.rete820:
    pop ebp
    iret
.erre820:
    push bp
    mov bp, sp
    or word ptr ss:[bp+6], 1
    pop bp
    iret

/* Runtime IOCTL input.  This lets FAKESIZE.COM obtain the active cap
 * without requiring the value to be repeated in AUTOEXEC.BAT.
 * Request buffer (16 bytes):
 *   00h  "FK22"
 *   04h  DWORD total cap in KB
 *   08h  DWORD extended-memory cap in KB
 *   0Ch  DWORD physical ceiling in bytes
 */
ioctl_input:
    cmp word ptr es:[bx+18], 16
    jb .ioctl_small

    push es
    les di, es:[bx+14]

    mov byte ptr es:[di+0], 'F'
    mov byte ptr es:[di+1], 'K'
    mov byte ptr es:[di+2], '2'
    mov byte ptr es:[di+3], '2'

    mov eax, dword ptr cs:[max_kb]
    mov dword ptr es:[di+4], eax
    mov eax, dword ptr cs:[ext_kb]
    mov dword ptr es:[di+8], eax
    mov eax, dword ptr cs:[cap_bytes]
    mov dword ptr es:[di+12], eax

    pop es
    mov word ptr es:[bx+18], 16
    mov word ptr es:[bx+3], 0x0100    /* DONE */
    ret

.ioctl_small:
    mov word ptr es:[bx+18], 0
    mov word ptr es:[bx+3], 0x810C    /* DONE | ERROR | general failure */
    ret

resident_end:

/* ---------------- Discardable initialization code ---------------- */
init_driver:
    push cs
    pop ds

    /* Parse CONFIG.SYS tail. On entry request +18 contains a read-only
     * far pointer to the text after '=' on the DEVICE= line.
     */
    push es
    push bx
    les di, es:[bx+18]
    call parse_command_line
    pop bx
    pop es
    jc init_badparam

    call compute_limits

    /* Save current INT 15h vector and install ours. DOS permits AH=35h/25h
     * during device INIT on DOS 3.x/4.x and later.
     */
    mov ax, 0x3515
    int 0x21
    mov cs:[old15_off], bx
    mov cs:[old15_seg], es

    push ds
    push cs
    pop ds
    mov dx, offset int15_handler
    mov ax, 0x2515
    int 0x21
    pop ds

    /* Return resident break address. */
    mov ax, cs
    mov es, cs:[req_seg]
    mov bx, cs:[req_off]
    mov word ptr es:[bx+14], offset resident_end
    mov word ptr es:[bx+16], ax
    mov word ptr es:[bx+3], 0x0100    /* DONE */

    mov dx, offset msg_loaded
    mov ah, 9
    int 0x21
    mov eax, dword ptr cs:[max_kb]
    call print_u32
    mov dx, offset msg_kb
    mov ah, 9
    int 0x21
    ret

init_badparam:
    mov es, cs:[req_seg]
    mov bx, cs:[req_off]
    mov ax, cs
    mov word ptr es:[bx+14], 0        /* load nothing resident */
    mov word ptr es:[bx+16], ax
    mov word ptr es:[bx+3], 0x8103
    mov dx, offset msg_usage
    mov ah, 9
    int 0x21
    ret

/* Parse /MAX=<decimal KB>. ES:DI points to entire CONFIG.SYS text after '='.
 * DOS commonly gives the full filename followed by options, terminated CR/LF.
 * Defaults to 16384 if no /MAX is present.
 */
parse_command_line:
    mov dword ptr cs:[max_kb], 16384
.scan:
    mov al, es:[di]
    cmp al, 0x0D
    je .ok
    cmp al, 0x0A
    je .ok
    cmp al, 0
    je .ok
    cmp al, '/'
    je .trymax
    cmp al, '-'
    je .trymax
.next:
    inc di
    jmp .scan

.trymax:
    push di
    inc di
    mov al, es:[di]
    and al, 0xDF
    cmp al, 'M'
    jne .nomatch
    inc di
    mov al, es:[di]
    and al, 0xDF
    cmp al, 'A'
    jne .nomatch
    inc di
    mov al, es:[di]
    and al, 0xDF
    cmp al, 'X'
    jne .nomatch
    inc di
    cmp byte ptr es:[di], '='
    jne .nomatch
    inc di

    xor eax, eax
    xor ecx, ecx
.digits:
    mov cl, es:[di]
    cmp cl, '0'
    jb .enddigits
    cmp cl, '9'
    ja .enddigits
    sub cl, '0'
    imul eax, eax, 10
    jo .bad
    movzx edx, cl
    add eax, edx
    jc .bad
    inc di
    jmp .digits
.enddigits:
    cmp eax, 1024
    jb .bad
    cmp eax, 4194303               /* cap_bytes must fit below 4GB */
    ja .bad
    mov dword ptr cs:[max_kb], eax
    pop ax                          /* discard saved DI without altering flags meaningfully */
    clc
    ret
.nomatch:
    pop di
    jmp .next
.bad:
    pop ax
    stc
    ret
.ok:
    clc
    ret

compute_limits:
    /* ext_kb = max(max_kb - 1024, 0) */
    mov eax, dword ptr cs:[max_kb]
    sub eax, 1024
    mov dword ptr cs:[ext_kb], eax

    /* AH=88h can report only a 16-bit KB count. */
    cmp eax, 65535
    jbe 9f
    mov eax, 65535
9:
    mov word ptr cs:[limit_88], ax

    /* cap_bytes = max_kb * 1024 */
    mov eax, dword ptr cs:[max_kb]
    shl eax, 10
    mov dword ptr cs:[cap_bytes], eax

    /* E801/E881: 1M..16M in KB, max 15360 */
    mov eax, dword ptr cs:[ext_kb]
    cmp eax, 15360
    jbe 1f
    mov eax, 15360
1:
    mov dword ptr cs:[limit_1to16], eax

    /* Above 16M in 64K blocks. */
    mov eax, dword ptr cs:[max_kb]
    cmp eax, 16384
    jbe 2f
    sub eax, 16384
    shr eax, 6
    jmp 3f
2:
    xor eax, eax
3:
    mov dword ptr cs:[limit_above16], eax
    ret

/* Print unsigned EAX decimal via DOS AH=02h. Init-time only. */
print_u32:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov ebx, 10
    xor cx, cx
1:
    xor edx, edx
    div ebx
    push dx
    inc cx
    test eax, eax
    jnz 1b
2:
    pop dx
    add dl, '0'
    mov ah, 2
    int 0x21
    loop 2b
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

msg_loaded:
    .ascii "FAKEIT.SYS 0.23 - limiting visible RAM to $"
msg_kb:
    .ascii " KB\r\n$"
msg_usage:
    .ascii "FAKEIT.SYS: invalid parameter. Use DEVICE=FAKEIT.SYS /MAX=<KB> (1024..4194303)\r\n$"

