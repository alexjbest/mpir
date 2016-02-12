include(`../config.m4')
define(`USE_LINUX64',1)
dnl define(`USE_PREFETCH',1)

dnl Copyright (C) 2016, Jens Nurmann
dnl All rights reserved.

dnl ============================================================================
dnl lSubShl1rEqu( Op1, Op2: pLimb; const NumLimbs: tCounter; Op3: pLimb ):tBaseVal
dnl Linux         %rdi  %rsi               %rdx             %rcx         :%rax
dnl Win7          %rcx  %rdx               %r8              %r9          :%rax
dnl
dnl Description:
dnl The function shifts Op2 left one bit, subtracts it from Op1, stores the
dnl result in Op3 and hands back the total carry. There is a gain in execution
dnl speed compared to separate shift and subtract by interleaving the elementary
dnl operations and reducing memory access. The factor depends on the size of the
dnl operands (the cache level in which the operands can be handled) and the core
dnl used.
dnl
dnl  Op3 := Op1 - Op2<<1
dnl
dnl Caveats:
dnl - the total carry is in (0..2)!
dnl
dnl Comments:
dnl - Skaylake asm version implemented, tested & benched on $15.10.2015 by jn
dnl - on an i7 $6700K per limb saving is $1 cycle in L1$, L2$ and L3$
dnl - includes LAHF / SAHF
dnl - includes prefetching

dnl  | Architecture | Piledriver |  K10-2  |
dnl  | Cycles/Limb  |    4.9     |   4.2   |

ifdef(`USE_LINUX64',`

  define(`Op1',   %rsi)
  define(`Op2',   %rdx)
  define(`NumLimbs',  %rcx)
  define(`Op3',   %rdi)
  ifdef(`USE_PREFETCH',`
    define(`Offs',  %rbp)        C  SAVE!
  ')

  define(`Limb0', %rbx)        C  SAVE!
  define(`Limb1', %r8)
  define(`Limb2', %r9)
  define(`Limb3', %r10)
  define(`Limb4', %r11)
  define(`Limb5', %r12)        C  SAVE!
  define(`Limb6', %r13)        C  SAVE!
  define(`Limb7', %r14)        C  SAVE!
  define(`Limb8', %r15)        C  SAVE!

')

ifdef(`USE_WIN64',`

  define(`Op1',   %rcx)
  define(`Op2',   %rdx)
  define(`NumLimbs',  %r8)
  define(`Op3',   %r9)
  ifdef(`USE_PREFETCH',`
    define(`Offs',  %rbp)         C  SAVE!
  ')

  define(`Limb0', %rbx)        C  SAVE!
  define(`Limb1', %rdi)        C  SAVE!
  define(`Limb2', %rsi)        C  SAVE!
  define(`Limb3', %r10)
  define(`Limb4', %r11)
  define(`Limb5', %r12)        C  SAVE!
  define(`Limb6', %r13)        C  SAVE!
  define(`Limb7', %r14)        C  SAVE!
  define(`Limb8', %r15)        C  SAVE!

')

ASM_START()
	TEXT
	ALIGN(32)
PROLOGUE(mpn_sublsh1_n)

  ifdef(`USE_WIN64',`
    ifdef(`USE_PREFETCH',`
      sub   $64, %rsp
      mov   Offs, 56(%rsp)
    ',`
      sub   $56, %rsp
    ')
      mov   Limb8, 48(%rsp)
      mov   Limb7, 40(%rsp)
      mov   Limb6, 32(%rsp)
      mov   Limb5, 24(%rsp)
      mov   Limb2, 16(%rsp)
      mov   Limb1, 8(%rsp)
      mov   Limb0, (%rsp)
  ')

  ifdef(`USE_LINUX64',`
    ifdef(`USE_PREFETCH',`
      sub   $48, %rsp
      mov   Offs, 40(%rsp)
    ',`
      sub   $40, %rsp
    ')
      mov   Limb8, 32(%rsp)
      mov   Limb7, 24(%rsp)
      mov   Limb6, 16(%rsp)
      mov   Limb5, 8(%rsp)
      mov   Limb0, (%rsp)
  ')

  ifdef(`USE_PREFETCH',`
    prefetchnta (Op1)
    prefetchnta (Op2)
    mov     $512, %ebp            C  Attn: check if redefining Offs
  ')

    C  prepare shift & subtraction with loop-unrolling $8
    xor     Limb0, Limb0
    lahf                        C  memorize clear carry (from "xor")

    test    $1, NumLimbs             C  a good %r8 / R16 / R32 macro would help!
    je      .lSubShl1rEquTwo

    mov     (Op2), Limb1
    shrd    $63, Limb1, Limb0

    sahf
    mov     (Op1), %rax
    sbb     Limb0, %rax
    mov     %rax, (Op3)
    lahf

    add     $8, Op1
    add     $8, Op2
    add     $8, Op3
    mov     Limb1, Limb0

  .lSubShl1rEquTwo:

    test    $2, NumLimbs             C  a good %r8 / R16 / R32 macro would help!
    je      .lSubShl1rEquFour

    mov     (Op2), Limb1
    mov     8(Op2), Limb2
    shrd    $63, Limb1, Limb0
    shrd    $63, Limb2, Limb1

    sahf
    mov     (Op1), %rax
    sbb     Limb0, %rax
    mov     %rax, (Op3)
    mov     8(Op1), %rax
    sbb     Limb1, %rax
    mov     %rax, 8(Op3)
    lahf

    add     $16, Op1
    add     $16, Op2
    add     $16, Op3
    mov     Limb2, Limb0

  .lSubShl1rEquFour:

    test    $4, NumLimbs             C  a good %r8 / R16 / R32 macro would help!
    je      .lSubShl1rEquTest   C  enter main loop =>

    mov     (Op2), Limb1
    mov     8(Op2), Limb2
    mov     16(Op2), Limb3
    mov     24(Op2), Limb4
    shrd    $63, Limb1, Limb0
    shrd    $63, Limb2, Limb1
    shrd    $63, Limb3, Limb2
    shrd    $63, Limb4, Limb3

    sahf
    mov     (Op1), %rax
    sbb     Limb0, %rax
    mov     %rax, (Op3)
    mov     8(Op1), %rax
    sbb     Limb1, %rax
    mov     %rax, 8(Op3)
    mov     16(Op1), %rax
    sbb     Limb2, %rax
    mov     %rax, 16(Op3)
    mov     24(Op1), %rax
    sbb     Limb3, %rax
    mov     %rax, 24(Op3)
    lahf

    add     $32, Op1
    add     $32, Op2
    add     $32, Op3
    mov     Limb4, Limb0
    jmp     .lSubShl1rEquTest   C  enter main loop =>

    C  main loop: <1.5 cycles per limb across all caches
    .align   32
  .lSubShl1rEquLoop:

  ifdef(`USE_PREFETCH',`
    prefetchnta (Op1,Offs,)
    prefetchnta (Op2,Offs,)
  ')

    mov     (Op2), Limb1        C  prepare shifted oct-limb from Op2
    mov     8(Op2), Limb2
    mov     16(Op2), Limb3
    mov     24(Op2), Limb4
    shrd    $63, Limb1, Limb0
    shrd    $63, Limb2, Limb1
    shrd    $63, Limb3, Limb2
    shrd    $63, Limb4, Limb3
    mov     32(Op2), Limb5
    mov     40(Op2), Limb6
    mov     48(Op2), Limb7
    mov     56(Op2), Limb8
    shrd    $63, Limb5, Limb4
    shrd    $63, Limb6, Limb5
    shrd    $63, Limb7, Limb6
    shrd    $63, Limb8, Limb7

    sahf                        C  restore carry
    mov     (Op1), %rax          C  sub shifted Op2 from Op1 with result in Op3
    sbb     Limb0, %rax
    mov     %rax, (Op3)
    mov     8(Op1), %rax
    sbb     Limb1, %rax
    mov     %rax, 8(Op3)
    mov     16(Op1), %rax
    sbb     Limb2, %rax
    mov     %rax, 16(Op3)
    mov     24(Op1), %rax
    sbb     Limb3, %rax
    mov     %rax, 24(Op3)
    mov     32(Op1), %rax
    sbb     Limb4, %rax
    mov     %rax, 32(Op3)
    mov     40(Op1), %rax
    sbb     Limb5, %rax
    mov     %rax, 40(Op3)
    mov     48(Op1), %rax
    sbb     Limb6, %rax
    mov     %rax, 48(Op3)
    mov     56(Op1), %rax
    sbb     Limb7, %rax
    mov     %rax, 56(Op3)
    lahf                        C  remember carry for next round

    add     $64, Op1
    add     $64, Op2
    add     $64, Op3
    mov     Limb8, Limb0

  .lSubShl1rEquTest:

    sub     $8, NumLimbs
    jnc     .lSubShl1rEquLoop

    C  housekeeping - hand back total carry
    shr     $63, Limb0
    sahf
    adc     $0, Limb0            C  Limb0=0/1/2 depending on final carry and shift
    mov     Limb0, %rax

  0:C Exit:

  ifdef(`USE_LINUX64',`
      mov   (%rsp), Limb0
      mov   8(%rsp), Limb5
      mov   16(%rsp), Limb6
      mov   24(%rsp), Limb7
      mov   32(%rsp), Limb8
    ifdef(`USE_PREFETCH',`
      mov   40(%rsp), Offs
      add   $48, %rsp
    ',`
      add   $40, %rsp
    ')
  ')

  ifdef(`USE_WIN64',`
      mov   (%rsp), Limb0
      mov   8(%rsp), Limb1
      mov   16(%rsp), Limb2
      mov   24(%rsp), Limb5
      mov   32(%rsp), Limb6
      mov   40(%rsp), Limb7
      mov   48(%rsp), Limb8
    ifdef(`USE_PREFETCH',`
      mov   56(%rsp), Offs
      sub   $64, %rsp
    ',`
      sub   $56, %rsp
    ')
  ')

    ret

EPILOGUE()
