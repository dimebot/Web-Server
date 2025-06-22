.intel_syntax noprefix
.global _start
_start:
        mov rbp, rsp
        mov rdi, 2
        mov rsi, 1
        mov rdx, 0
        mov rax, 41
        syscall         #socket syscall

        mov [rbp + 8], rax      #store socket's fd

        mov rdi, [rbp + 8]
        lea rsi, [rip + sock_addr]
        mov rdx, 16
        mov rax, 49
        syscall         #bind to the socket's fd

        mov rdi, [rbp + 8]
        mov rsi, 0
        mov rax, 50
        syscall         #listen on the named socket

        accept:
        mov rdi, [rbp + 8]
        mov rsi, 0
        mov rdx, 0
        mov rax, 43
        syscall         #accept client connection on the socket

        mov [rbp + 16], rax     #store the accepted connection's fd

        mov rax, 57
        syscall         #fork

        cmp rax, 0
        je child_process

        parent_process:
        mov rdi, [rbp + 16]
        mov rax, 3      #close the accepted connection fd and listen for more connections
        syscall

        jmp accept

        child_process:
        mov rdi, [rbp + 8]
        mov rax, 3
        syscall         #close the socket fd and work with a single client connection only

        mov rdi, [rbp + 16]
        sub rsp, 600
        mov rsi, rsp
        mov rdx, 600
        mov rax, 0
        syscall         #read the incoming request to the buffer

        mov r8, rsp
        cmp byte ptr [rsp], 0x47
        jne post

        get:  
        cmp byte ptr [r8], 0x20
        je filename_start
        add r8, 1
        jmp get

        filename_start:
        add r8, 1
        mov r9, r8

        parse_filename:
        cmp byte ptr [r9], 0x20
        je done_filename
        add r9, 1
        jmp parse_filename

        done_filename:
        mov byte ptr [r9], 0x00

        lea rdi, [r8]
        mov rsi, 0
        mov rdx, 0
        mov rax, 2
        syscall         #open the requested file

        mov [rbp + 8], rax      #store the opened file's fd

        mov rdi, [rbp + 8]
        sub rsp, 300
        mov rsi, rsp
        mov rdx, 300
        mov rax, 0
        syscall         #read from the file

        mov r12, rax

        mov rdi, [rbp + 8]
        mov rax, 3
        syscall         #close the opened file

        mov rdi, [rbp + 16]
        lea rsi, [rip + http_ok]
        mov rdx, 19
        mov rax, 1
        syscall         #http 200 response

        mov rdi, [rbp + 16]
        mov rsi, rsp
        mov rdx, r12
        mov rax, 1
        syscall         #write the requested file's content

        mov rdi, [rbp + 16]
        mov rax, 3
        syscall         #close the connection's fd

        jmp exit

        post:
        cmp byte ptr[r8], 0x20
        je done_post
        add r8, 1
        jmp post

        done_post:
        add r8, 1
        mov r9, r8

        parse_filename_post:
        cmp byte ptr[r9], 0x20
        je done_filename_post
        add r9, 1
        jmp parse_filename_post

        done_filename_post:
        mov byte ptr[r9], 0x00

        lea rdi, [r8]
        mov rsi, 65
        mov rdx, 0777
        mov rax, 2
        syscall         #open the file with write and create perms

        mov [rbp + 8], rax

        add r9, 161
        cmp byte ptr [r9], 0x0A
        je add_one
        jmp final

        add_one:
        add r9, 1

        final:
        mov rcx, 0
        mov r10, r9

        get_count:
        cmp byte ptr[r10], 0x00
        je done_count
        add r10, 1
        add rcx, 1
        jmp get_count

        done_count:
        mov rdi, [rbp + 8]
        lea rsi, [r9]
        mov rdx, rcx
        mov rax, 1
        syscall         #write the content to the file

        mov rdi, [rbp + 8]
        mov rax, 3
        syscall

        mov rdi, [rbp + 16]
        lea rsi, [rip + http_ok]
        mov rdx, 19
        mov rax, 1
        syscall         #write http 200 to connection's fd
         
        exit:
        mov rdi, 0
        mov rax, 60
        syscall         #exit

.section .data
sock_addr:
        .2byte 2
        .2byte 0x901f
        .4byte 0x100007f
        .8byte 0

http_ok:
        .string "HTTP/1.0 200 OK\r\n\r\n"
