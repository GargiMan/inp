; Autor reseni: Marek Gergel xgerge01

; Projekt 2 - INP 2022
; Vernamova sifra na architekture MIPS64

; DATA SEGMENT
                .data
login:          .asciiz "xgerge01"  ; sem doplnte vas login
vernam_inc:     .byte   103         ; ascii kod znaku 'g'
vernam_dec:     .byte   101         ; ascii kod znaku 'e'
char_a:         .byte   97          ; ascii kod znaku 'a'
char_z:         .byte   122         ; ascii kod znaku 'z'

cipher:         .space  17  ; misto pro zapis sifrovaneho loginu

params_sys5:    .space  8   ; misto pro ulozeni adresy pocatku
                            ; retezce pro vypis pomoci syscall 5
                            ; (viz nize "funkce" print_string)

; CODE SEGMENT
                .text
main:
                lb      r10, char_a(r0)
                addi    r10, r10, -1        ; r10 = char_a - 1

                add     r13, r0, r0         ; r13 = 0 (index)

vernam_inc_loop:
                lb      r15, login(r13)     ; r15 = login[r13]
                sub     r9, r10, r15        ; r9 = r10 - login[r13]
                bgez    r9, print           ; if login[r13] < char_a -> print

                lb      r9, vernam_inc(r0)
                sub     r9, r9, r10         ; r9 = vernam_inc - char_a   -> 7

                add     r15, r15, r9        ; r15 = login[r13] + vernam_inc

                lb      r9, char_z(r0)
                sub     r9, r9, r15         ; r9 = r9 - r15
                bgez    r9, vernam_inc_loop_end ; if r15 > char_z -> vernam_inc_loop_end
                sub     r15, r10, r9        ; r15 = char_a - r9
                b       vernam_inc_loop_end ; go to inc loop end

vernam_inc_loop_end:
                sb      r15, cipher(r13)    ; cipher[r13] = r15

                addi    r13, r13, 1         ; r13 = r13 + 1
                b       vernam_dec_loop     ; go to dec loop

vernam_dec_loop:
                lb      r15, login(r13)     ; r15 = login[r13]
                sub     r9, r10, r15        ; r9 = r10 - login[r13]
                bgez    r9, print           ; if login[r13] < char_a -> print

                lb      r9, vernam_dec(r0)
                sub     r9, r9, r10         ; r9 = vernam_dec - char_a  -> 5

                sub     r15, r15, r9        ; r15 = login[r13] - vernam_dec

                sub     r9, r15, r10         ; r9 = r15 - r10
                addi    r9, r9, -1           ; r9 = r9 - 1
                bgez    r9, vernam_dec_loop_end ; if r15 < char_a -> vernam_dec_loop_end
                lb      r15, char_z(r0)
                addi    r15, r15, 1          ; r15 = r15 + 1
                add     r15, r15, r9         ; r15 = char_z + r9

                b       vernam_dec_loop_end ; go to dec loop end

vernam_dec_loop_end:
                sb      r15, cipher(r13)    ; cipher[r13] = r15

                addi    r13, r13, 1         ; r13 = r13 + 1
                b       vernam_inc_loop     ; go to inc loop

print:
                sb      r0, cipher(r13) ; cipher[r13] = 0
                daddi   r4, r0, cipher  ; vzorovy vypis: adresa login: do r4
                jal     print_string    ; vypis pomoci print_string - viz nize

                syscall 0   ; halt

print_string:   ; adresa retezce se ocekava v r4
                sw      r4, params_sys5(r0)
                daddi   r14, r0, params_sys5    ; adr pro syscall 5 musi do r14
                syscall 5   ; systemova procedura - vypis retezce na terminal
                jr      r31 ; return - r31 je urcen na return address
