.intel_syntax noprefix
.code16
.section .text
.global _start

/* RAMPROBE.COM v0.20
 * 386+ DOS diagnostic utility for BIOS and XMS memory reporting.
 */
_start:
    push cs
    pop ds

    mov dx, offset banner
    call puts

    /* INT 15h AH=88h */
    mov dx, offset lab88
    call puts
    mov ah, 0x88
    int 0x15
    jc unsup88
    movzx eax, ax
    add eax, 1024
    call print_u32
    mov dx, offset kbcrlf
    call puts
    jmp after88
unsup88:
    mov dx, offset unsupported
    call puts
after88:

    /* INT 15h AH=8Ah */
    mov dx, offset lab8a
    call puts
    mov ah, 0x8A
    int 0x15
    jc unsup8a
    movzx eax, ax
    movzx edx, dx
    shl edx, 16
    or eax, edx
    add eax, 1024
    call print_u32
    mov dx, offset kbcrlf
    call puts
    jmp after8a
unsup8a:
    mov dx, offset unsupported
    call puts
after8a:

    /* INT 15h AX=DA88h */
    mov dx, offset labda
    call puts
    mov ax, 0xDA88
    int 0x15
    jc unsupda
    movzx eax, bx
    movzx edx, cl
    shl edx, 16
    or eax, edx
    add eax, 1024
    call print_u32
    mov dx, offset kbcrlf
    call puts
    jmp afterda
unsupda:
    mov dx, offset unsupported
    call puts
afterda:

    /* INT 15h AX=E801h */
    mov dx, offset labe801
    call puts
    mov ax, 0xE801
    int 0x15
    jc unsupe801
    /* Some BIOSes use CX/DX when AX/BX are zero. */
    mov si, ax
    mov di, bx
    or si, di
    jnz haveab
    mov si, cx
    mov di, dx
haveab:
    movzx eax, si
    movzx edx, di
    shl edx, 6
    add eax, edx
    add eax, 1024
    call print_u32
    mov dx, offset kbcrlf
    call puts
    jmp aftere801
unsupe801:
    mov dx, offset unsupported
    call puts
aftere801:

    /* INT 15h E820h: report top of highest type-1 range. */
    mov dx, offset labe820
    call puts
    push ds
    pop es
    xor ebx, ebx
    mov dword ptr [e820_top], 0
    mov byte ptr [e820_seen], 0
.e820_loop:
    mov eax, 0xE820
    mov edx, 0x534D4150
    mov ecx, 24
    mov di, offset e820_buf
    int 0x15
    jc .e820_done
    cmp eax, 0x534D4150
    jne .e820_done
    mov byte ptr [e820_seen], 1
    cmp dword ptr [e820_buf+16], 1
    jne .e820_next
    cmp dword ptr [e820_buf+4], 0
    jne .e820_next
    cmp dword ptr [e820_buf+12], 0
    jne .e820_next
    mov eax, dword ptr [e820_buf]
    add eax, dword ptr [e820_buf+8]
    jc .e820_next
    cmp eax, dword ptr [e820_top]
    jbe .e820_next
    mov dword ptr [e820_top], eax
.e820_next:
    test ebx, ebx
    jnz .e820_loop
.e820_done:
    cmp byte ptr [e820_seen], 0
    je unsupe820
    mov eax, dword ptr [e820_top]
    shr eax, 10
    call print_u32
    mov dx, offset kbcrlf
    call puts
    jmp aftere820
unsupe820:
    mov dx, offset unsupported
    call puts
aftere820:

    mov dx, offset blankline
    call puts

    /* Find an installed XMS manager. */
    mov dx, offset xmshead
    call puts

    /* Report whether RAMSIZE.COM stage-2 XMS filter is resident. */
    mov ax, 0xD5A0
    mov bx, 0x5253
    mov cx, 0x5A45
    int 0x2F
    cmp ax, 0xD5A1
    jne 1f
    mov dx, offset filt_yes
    call puts
    jmp 2f
1:
    mov dx, offset filt_no
    call puts
2:

    mov ax, 0x4300
    int 0x2F
    cmp al, 0x80
    jne no_xms

    mov ax, 0x4310
    int 0x2F
    mov word ptr [xms_vec], bx
    mov word ptr [xms_vec+2], es

    /* XMS driver version. */
    xor ax, ax
    lcall [xms_vec]
    mov word ptr [xms_ver], ax
    mov dx, offset xmsverlab
    call puts
    mov ax, word ptr [xms_ver]
    mov al, ah
    xor ah, ah
    call print_u16_dec
    mov dl, '.'
    mov ah, 2
    int 0x21
    mov ax, word ptr [xms_ver]
    and ax, 0x00FF
    /* XMS minor is BCD; print two hex digits, which reads naturally (00, 10, etc). */
    call print_hex8
    mov dx, offset crlf
    call puts

    /* XMS 2.0 function 08h. AX largest, DX total, in KB. */
    mov dx, offset xms2lab
    call puts
    xor bx, bx
    mov ah, 0x08
    lcall [xms_vec]
    mov word ptr [xms2_largest], ax
    mov word ptr [xms2_total], dx
    mov byte ptr [xms2_status], bl
    cmp bl, 0
    jne xms2_error
    movzx eax, word ptr [xms2_total]
    call print_u32
    mov dx, offset totalmid
    call puts
    movzx eax, word ptr [xms2_largest]
    call print_u32
    mov dx, offset largestend
    call puts
    jmp after_xms2
xms2_error:
    mov dx, offset errtxt
    call puts
    mov al, byte ptr [xms2_status]
    call print_hex8
    mov dx, offset crlf
    call puts
after_xms2:

    /* XMS 3.0 function 88h. EAX largest, EDX total, ECX highest byte. */
    mov dx, offset xms3lab
    call puts
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    mov ah, 0x88
    lcall [xms_vec]
    mov dword ptr [xms3_largest], eax
    mov dword ptr [xms3_total], edx
    mov dword ptr [xms3_highest], ecx
    mov byte ptr [xms3_status], bl
    cmp bl, 0
    jne xms3_error
    mov eax, dword ptr [xms3_total]
    call print_u32
    mov dx, offset totalmid
    call puts
    mov eax, dword ptr [xms3_largest]
    call print_u32
    mov dx, offset largestend
    call puts

    mov dx, offset xmshighlab
    call puts
    mov eax, dword ptr [xms3_highest]
    call print_hex32
    mov dx, offset highmid
    call puts
    mov eax, dword ptr [xms3_highest]
    inc eax
    shr eax, 10
    call print_u32
    mov dx, offset kbcrlf
    call puts
    jmp done
xms3_error:
    mov dx, offset errtxt
    call puts
    mov al, byte ptr [xms3_status]
    call print_hex8
    mov dx, offset crlf
    call puts
    jmp done

no_xms:
    mov dx, offset noxmstxt
    call puts

done:
    mov ax, 0x4C00
    int 0x21

puts:
    mov ah, 9
    int 0x21
    ret

/* print EAX as unsigned decimal */
print_u32:
    push eax
    push ebx
    push ecx
    push edx
    mov ebx, 10
    xor ecx, ecx
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
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

/* print AX as unsigned decimal */
print_u16_dec:
    movzx eax, ax
    jmp print_u32

/* print AL as two hexadecimal digits */
print_hex8:
    push ax
    push bx
    push dx
    mov bl, al
    shr al, 4
    call hex_nibble
    mov al, bl
    and al, 0x0F
    call hex_nibble
    pop dx
    pop bx
    pop ax
    ret

/* print EAX as eight hexadecimal digits */
print_hex32:
    push eax
    push ebx
    push ecx
    push edx
    mov ebx, eax
    mov cx, 8
.hloop:
    rol ebx, 4
    mov al, bl
    and al, 0x0F
    call hex_nibble
    loop .hloop
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

hex_nibble:
    and al, 0x0F
    cmp al, 9
    jbe 1f
    add al, 'A' - 10
    jmp 2f
1:
    add al, '0'
2:
    mov dl, al
    mov ah, 2
    int 0x21
    ret

banner:      .ascii "RAMPROBE 0.21 - BIOS/XMS visible memory\r\n$"
lab88:       .ascii "INT 15/88   : $"
lab8a:       .ascii "INT 15/8A   : $"
labda:       .ascii "INT 15/DA88 : $"
labe801:     .ascii "INT 15/E801 : $"
labe820:     .ascii "INT 15/E820 : $"
unsupported: .ascii "unsupported\r\n$"
kbcrlf:      .ascii " KB total\r\n$"
blankline:   .ascii "\r\n$"
crlf:        .ascii "\r\n$"
xmshead:     .ascii "XMS manager diagnostics\r\n$"
filt_yes:    .ascii "RAMSIZE XMS : filter installed\r\n$"
filt_no:     .ascii "RAMSIZE XMS : filter not installed\r\n$"
xmsverlab:   .ascii "XMS version : $"
xms2lab:     .ascii "XMS fn 08   : total free $"
xms3lab:     .ascii "XMS fn 88   : total free $"
totalmid:    .ascii " KB, largest $"
largestend:  .ascii " KB\r\n$"
xmshighlab:  .ascii "XMS highest : 0x$"
highmid:     .ascii "  (top $"
errtxt:      .ascii "error 0x$"
noxmstxt:    .ascii "No XMS manager installed.\r\n$"

.align 4
xms_vec:        .long 0
xms_ver:        .word 0
xms2_largest:   .word 0
xms2_total:     .word 0
xms2_status:    .byte 0
.align 4
xms3_largest:   .long 0
xms3_total:     .long 0
xms3_highest:   .long 0
xms3_status:    .byte 0
.align 4
e820_seen: .byte 0
.align 4
e820_top:  .long 0
e820_buf:  .space 24, 0
