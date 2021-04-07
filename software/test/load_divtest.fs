\ 
\ Last change: KS 13.12.2020 16:15:33
\
\ MicroCore load screen for the core test program that is transferred
\ into the program memory via the debug umbilical
\
Only Forth also definitions 

[IFDEF] unpatch     unpatch    [ENDIF]
[IFDEF] close-port  close-port [ENDIF]
[IFDEF] microcore   microcore  [ENDIF]   Marker microcore

include extensions.fs           \ Some System word (re)definitions for a more sympathetic environment
include ../vhdl/architecture_pkg.vhd
include microcross.fs           \ the cross-compiler

Target new initialized          \ go into target compilation mode and initialize target compiler

8 trap-addr code-origin
          0 data-origin

include constants.fs            \ MicroCore Register addresses and bits
include debugger.fs
library forth_lib.fs
library task_lib.fs

Task Tester

\ &65539 Constant Prime    \ used up
&65543 Constant Prime
\ &65551 Constant Prime
\ &65557 Constant Prime
\ &65563 Constant Prime
\ &65581 Constant Prime

Variable Seed
Variable rounds 0 ,
Variable overflown
Variable uoverflown

1 0. 0 0   uoverflown !  overflown !  rounds 2!  Seed !  \ &65543

Variable Dividend  0 ,
Variable Divisor

: random    ( -- u )  Seed @ Prime * dup Seed ! ;

: indicate  ( -- )
   rounds 2@ 1. d+ rounds 2!
   rounds 1+ @ unpack -6 shift Leds ! drop
;
: muldiv_test ( -- f )
   random random 2dup Dividend 2!   random dup Divisor ! m/mod
   ovfl? IF  drop drop   true  1 overflown +!  EXIT THEN
   Divisor @ m* rot extend d+  Dividend 2@ d=
;
: umuldiv_test ( -- f )
   Dividend 2@   Divisor @ um/mod
   ovfl? IF  drop drop   true  1 uoverflown +!  EXIT THEN
   Divisor @ um* rot 0 d+  Dividend 2@ d=
;
: ??    ( -- )  uoverflown @   overflown @   rounds 2@   Seed @ u. d. u. u. ;

: test  ( -- )  BEGIN pause indicate muldiv_test umuldiv_test and 0= UNTIL halt ;

: boot  ( -- )
   0 #cache erase  CALL initialization
   Terminal Tester ['] test spawn
   debug-service
;

#reset TRAP: rst    ( -- )            boot              ;  \ compile branch to boot at reset vector location
#isr   TRAP: isr    ( -- )            di IRET           ;
#psr   TRAP: psr    ( -- )            pause             ;  \ call the scheduler, eventually re-execute instruction
#break TRAP: break  ( -- )            debugger          ;  \ Debugger
#does> TRAP: dodoes ( addr -- addr' ) ld 1+ swap BRANCH ;  \ the DOES> runtime primitive
#data! TRAP: data!  ( dp n -- dp+1 )  swap st 1+        ;  \ Data memory initialization

end
