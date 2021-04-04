\
\ Last change: KS 13.03.2021 19:11:12
\ Last check in : $Rev: 643 $ $Date:: 2021-02-11 #$
\
\ Basic microCore load screen for execution on the target.
\
Only Forth also definitions hex

[IFDEF] unpatch     unpatch    [ENDIF]
[IFDEF] close-port  close-port [ENDIF]
[IFDEF] microcore   microcore  [ENDIF]   Marker microcore

include extensions.fs           \ Some System word (re)definitions
include ../vhdl/architecture_pkg.vhd
include microcross.fs           \ the cross-compiler

\ Verbose on

Host  Variable int16p   0 int16p !

Target new initialized          \ go into target compilation mode and initialize target compiler

8 trap-addr code-origin
          0 data-origin

include constants.fs            \ MicroCore Register addresses and bits
include debugger.fs
library forth_lib.fs

Host: uint16 ;

Class int16   int16 definitions
1 int16 allot   int16 seal

     h' Object Alias Variable

     : @  ( addr -- n )  @ $FFFF and dup $8000 and IF  $FFFF not or  THEN ;
Macro: !  ( n addr -- )  T ! H ;
Target

$200 int16 Constant int
int16  Variable signed
uint16 Variable unsigned

Class Cell   Cell definitions
1 Cell allot   Cell seal
Macro: @    ( obj -- n )   T @ H ;
Macro: !    ( n obj -- )   T ! H ;
     : +!   ( n obj -- )   +! ;
     : on   ( obj -- )     on ;
     : off  ( obj -- )     off ;
     : ?    ( obj -- )     @ . ;
Target

Class Point  Point definitions
   Cell Attribute X
   Cell Attribute Y
Point seal
: set   ( X Y obj -- )     swap over Self Y !   Self X ! ;
: ?     ( obj -- )         dup Point X ?   Point Y ? ;
Target

Point Object Punkt   init: init-Punkt ( -- )   1 2 Punkt set ;

\ ----------------------------------------------------------------------
\ Interrupt
\ ----------------------------------------------------------------------

Variable Ticker  0 Ticker !

: interrupt ( -- )  intflags
   #i-time and IF  1 Ticker +!  #i-time not Flag-reg !  THEN
;
init: init-int  ( -- )  #i-time int-enable ei ;

\ ----------------------------------------------------------------------
\ Booting and TRAPs
\ ----------------------------------------------------------------------

init: init-leds ( -- )  0 Leds ! ;

: boot  ( -- )   0 #cache erase   CALL initialization   debug-service ;

#reset TRAP: rst    ( -- )            boot              ;  \ compile branch to boot at reset vector location
#isr   TRAP: isr    ( -- )            interrupt IRET    ;
#psr   TRAP: psr    ( -- )            pause             ;  \ call the scheduler, eventually re-execute instruction
#break TRAP: break  ( -- )            debugger          ;  \ Debugger
#does> TRAP: dodoes ( addr -- addr' ) ld 1+ swap BRANCH ;  \ the DOES> runtime primitive
#data! TRAP: data!  ( dp n -- dp+1 )  swap st 1+        ;  \ Data memory initialization

end
