\ 
\ Last change: KS 06.03.2021 22:52:44
\ Last check in : $Rev: 656 $ $Date:: 2021-03-06 #$
\
\ MicroCore load screen for simulating the umbilical's break function.
\ Constant break has to be set to '1' in bench.vhd.
\ Use wave signal script break.do in the simulator directory.
\
Only Forth also definitions 

[IFDEF] unpatch     unpatch    [ENDIF]
[IFDEF] close-port  close-port [ENDIF]
[IFDEF] microcore   microcore  [ENDIF]   Marker microcore

include extensions.fs           \ Some System word (re)definitions for a more sympathetic environment
include ../vhdl/architecture_pkg_sim.vhd
include microcross.fs           \ the cross-compiler

Target new initialized          \ go into target compilation mode and initialize target compiler

8 trap-addr code-origin
          0 data-origin
      
include constants.fs            \ microCore Register addresses and bits
include debugger.fs
library forth_lib.fs
library task_lib.fs

Task Background

Variable Counter
Variable Rerun

: bg_task  ( -- )  0 Counter !   0 Rerun !
   BEGIN  pause  1 Counter +!   Dsu @   Rerun @
      2dup or 0= IF  Rerun on  THEN
      and IF  #c-bitout Ctrl !  THEN
   REPEAT
;
: boot  ( -- )   CALL INITIALIZATION
   Terminal Background ['] bg_task spawn
   BEGIN pause REPEAT
;
#reset TRAP: rst    ( -- )            boot       ;  \ compile branch to boot at reset vector location
#psr   TRAP: psr    ( -- )            pause      ;  \ reexecute the previous instruction
#break TRAP: break  ( -- )            debugger   ;
#data! TRAP: data!  ( dp n -- dp+1 )  swap st 1+ ;  \ Data memory initialization

end

MEM-file program.mem cr .( sim_break.fs written to program.mem )
