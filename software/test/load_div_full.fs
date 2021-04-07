\ 
\ Last change: KS 13.03.2021 19:16:24
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
include task_lib.fs

\ --------------------------------------------------------------------------------
\ Test routines for signed division, truncated to a reduced data width
\ --------------------------------------------------------------------------------

Task Tester

                   $100 Constant #divisor  \  8 bit
#divisor #divisor * u2/ Constant #signbit  \ 16 bit

Variable Ptr
Variable Dividend
Variable Divisor
Variable Errors
Variable Ambiguous
Create Field     \ must be last Create with empty space until #cache

: blink       ( -- )      Leds @ $80 xor Leds ! ;

: sign-extend ( u -- n )  dup #signbit and IF  #signbit not or  THEN ;

: checkdiv ( -- )
   Dividend @ sign-extend extend Divisor @ m/mod
   ovfl? >r   Divisor @ 0=
   IF  or 0= r> xor ?EXIT Errors inc              \ 0 is always wrong with the exception of 0 / 0
   ELSE  Divisor @ * +
         Dividend @ sign-extend =
         IF   r> 0= ?EXIT  Ambiguous inc          \ correct and ovfl set
         ELSE r>    ?EXIT  Errors inc             \ false and ovfl not set
   THEN THEN
   Divisor @ Dividend @ Ptr @ st 1+ st 1+
   dup #cache u> IF  $FF Leds !  halt  THEN  Ptr !
;
: divtest  ( -- )
   0 Leds !   #signbit 2* 0
   DO  I Dividend !   I $3F and 0= IF blink THEN
      #divisor 0 DO  pause I Divisor !  checkdiv  LOOP
   LOOP
   $55 Leds !  halt
;
: start ( -- )   Terminal Tester ['] divtest spawn ;

: cold  ( -- )   Field Ptr !  Dividend [ #cache Dividend - ] Literal erase start ;

: ??    ( -- )   divisor @   dividend @ . . Errors @ u. Ambiguous @ u. ;

\ --------------------------------------------------------------------------------
\ booting and traps
\ --------------------------------------------------------------------------------

: boot  ( -- )   0 #cache erase   CALL initialization   debug-service ;

#reset TRAP: rst    ( -- )            boot              ;  \ compile branch to boot at reset vector location
#isr   TRAP: isr    ( -- )            di IRET           ;
#psr   TRAP: psr    ( -- )            pause             ;  \ call the scheduler, eventually re-execute instruction
#break TRAP: break  ( -- )            debugger          ;  \ Debugger
#does> TRAP: dodoes ( addr -- addr' ) ld 1+ swap BRANCH ;  \ the DOES> runtime primitive
#data! TRAP: data!  ( dp n -- dp+1 )  swap st 1+        ;  \ Data memory initialization

end
