include(`../config.m4')
define(`USE_LINUX64',1)
dnl define(`USE_PREFETCH',1)

dnl Copyright (C) 2016, Jens Nurmann
dnl All rights reserved.

dnl ============================================================================
dnl lAddShl1Equ( Op1, Op2: pLimb; const NumLimbs: tCounter; Op3: pLimb ):tBaseVal
dnl Linux        %rdi  %rsi               %rdx             %rcx         :%rax
dnl Win7         %rcx  %rdx               %r8              %r9          :%rax
dnl
dnl Description:
dnl The function shifts Op1 left one bit, adds this to Op2, stores the result
dnl in Op3 and hands back the total carry. There is a gain in execution speed
dnl compared to separate shift and addition by interleaving the elementary
dnl operations and reducing memory access. The factor depends on the size of the
dnl operands (the cache level which in the operands can be handled) and the core
dnl used.
dnl
dnl  Op3 := Op1<<1 + Op2
dnl
dnl Caveats:
dnl - the total carry can range from 0-2!
dnl
dnl Comments:
dnl - Skylake asm version implemented, tested & benched on $11.10.2015 by jn
dnl - on an i7 $6700K per limb saving is $1 cycle in L1$, L2$ and L3$
dnl - includes LAHF / SAHF
dnl - includes prefetching

dnl  | Architecture | Piledriver |
dnl  | Cycles/Limb  |    4.6     |


ifdef(`USE_LINUX64',`

  define(`Op1',   %rdx)
  define(`Op2',   %rsi)
  define(`NumLimbs',  %rcx)
  define(`Op3',   %rdi)
  ifdef(`USE_PREFETCH',`
    define(`Offs',  %rbp)        C SAVE!
  ')

  define(`Limb0', %rbx)         C SAVE!
  define(`Limb1', %r8)
  define(`Limb2', %r9)
  define(`Limb3', %r10)
  define(`Limb4', %r11)
  define(`Limb5', %r12)        C SAVE!
  define(`Limb6', %r13)        C SAVE!
  define(`Limb7', %r14)        C SAVE!
  define(`Limb8', %r15)        C SAVE!

')

ifdef(`USE_WIN64',`

  define(`Op1',   %rcx)
  define(`Op2',   %rdx)
  define(`NumLimbs',  %r8)
  define(`Op3',   %r9)
  ifdef(`USE_PREFETCH',`
    define(`Offs',  %rbp)        C SAVE!
  ')

  define(`Limb0', %rbx)        C SAVE!
  define(`Limb1', %rdi)        C SAVE!
  define(`Limb2', %rsi)        C SAVE!
  define(`Limb3', %r10)
  define(`Limb4', %r11)
  define(`Limb5', %r12)        C SAVE!
  define(`Limb6', %r13)        C SAVE!
  define(`Limb7', %r14)        C SAVE!
  define(`Limb8', %r15)        C SAVE!

')

ASM_START()
	TEXT
	ALIGN(32)
PROLOGUE(mpn_addlsh1_n)

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
    mov     $512, %ebp            C Attn: check if redefining Offs
  ')

    C prepare shift & addition with loop-unrolling $8
    xor     Limb0, Limb0        C a good %r8 / R16 / R32 macro would help!
    lahf                        C memorize clear carry (from "xor")

    test    $1, NumLimbs             C a good %r8 / R16 / R32 macro would help!
    jz      .lAddShl1EquTwo

    mov     (Op1), Limb1
    shrd    $63, Limb1, Limb0

    sahf
    adc     (Op2), Limb0
    mov     Limb0, (Op3)
    lahf

    add     $8, Op1
    add     $8, Op2
    add     $8, Op3
    mov     Limb1, Limb0

  .lAddShl1EquTwo:

    test    $2, NumLimbs             C a good %r8 / R16 / R32 macro would help!
    jz      .lAddShl1EquFour

    mov     (Op1), Limb1
    mov     8(Op1), Limb2
    shrd    $63, Limb1, Limb0
    shrd    $63, Limb2, Limb1

    sahf
    adc     (Op2), Limb0
    adc     8(Op2), Limb1
    mov     Limb0, (Op3)
    mov     Limb1, 8(Op3)
    lahf

    add     $16, Op1
    add     $16, Op2
    add     $16, Op3
    mov     Limb2, Limb0

  .lAddShl1EquFour:

    test    $4, NumLimbs             C a good %r8 / R16 / R32 macro would help!
    jz      .lAddShl1EquTest    C enter main loop =>

    mov     (Op1), Limb1
    mov     8(Op1), Limb2
    mov     16(Op1), Limb3
    mov     24(Op1), Limb4
    shrd    $63, Limb1, Limb0
    shrd    $63, Limb2, Limb1
    shrd    $63, Limb3, Limb2
    shrd    $63, Limb4, Limb3

    sahf
    adc     (Op2), Limb0
    adc     8(Op2), Limb1
    adc     16(Op2), Limb2
    adc     24(Op2), Limb3
    mov     Limb0, (Op3)
    mov     Limb1, 8(Op3)
    mov     Limb2, 16(Op3)
    mov     Limb3, 24(Op3)
    lahf

    add     $32, Op1
    add     $32, Op2
    add     $32, Op3
    mov     Limb4, Limb0
    jmp     .lAddShl1EquTest    C enter main loop =>

    C main loop: <1.3 cycles per limb in L1$
    C combining elements in multiples of four prooved fastest on Skylake
    .align   32
  .lAddShl1EquLoop:

  ifdef(`USE_PREFETCH',`
    prefetchnta (Op1,Offs,)
    prefetchnta (Op2,Offs,)
  ')

    mov     (Op1), Limb1        C prepare shifted oct-limb from Op1
    mov     8(Op1), Limb2
    mov     16(Op1), Limb3
    mov     24(Op1), Limb4
    shrd    $63, Limb1, Limb0
    shrd    $63, Limb2, Limb1
    shrd    $63, Limb3, Limb2
    shrd    $63, Limb4, Limb3
    mov     32(Op1), Limb5
    mov     40(Op1), Limb6
    mov     48(Op1), Limb7
    mov     56(Op1), Limb8
    shrd    $63, Limb5, Limb4
    shrd    $63, Limb6, Limb5
    shrd    $63, Limb7, Limb6
    shrd    $63, Limb8, Limb7

    sahf                        C restore carry
    adc     (Op2), Limb0        C add Op2 to oct-limb and store in Op3
    adc     8(Op2), Limb1
    adc     16(Op2), Limb2
    adc     24(Op2), Limb3
    mov     Limb0, (Op3)
    mov     Limb1, 8(Op3)
    mov     Limb2, 16(Op3)
    mov     Limb3, 24(Op3)
    adc     32(Op2), Limb4
    adc     40(Op2), Limb5
    adc     48(Op2), Limb6
    adc     56(Op2), Limb7
    mov     Limb4, 32(Op3)
    mov     Limb5, 40(Op3)
    mov     Limb6, 48(Op3)
    mov     Limb7, 56(Op3)
    lahf                        C remember carry for next round

    add     $64, Op1
    add     $64, Op2
    add     $64, Op3
    mov     Limb8, Limb0

  .lAddShl1EquTest:

    sub     $8, NumLimbs
    jnc     .lAddShl1EquLoop

    C housekeeping - hand back total carry
    shr     $63, Limb0
    sahf
    adc     $0, Limb0            C =0/1/2 depending on final carry and shift
    mov     Limb0, %rax

  0:CExit:

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