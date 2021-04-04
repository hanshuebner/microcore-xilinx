\ ----------------------------------------------------------------------
\ @file : bootload.fs
\ ----------------------------------------------------------------------
\
\ Last change: KS 13.03.2021 19:19:50
\ Project : microCore
\ Language : gforth_0.6.2
\ Last check in : $Rev: 667 $ $Date:: 2021-03-14 #$
\ @copyright (c): Free Software Foundation
\ @original author: ks - Klaus Schleisiek
\
\ @license: This file is part of microForth.
\ microForth is free software for microCore that loads on top of Gforth;
\ you can redistribute it and/or modify it under the terms of the
\ GNU General Public License as published by the Free Software Foundation,
\ either version 3 of the License, or (at your option) any later version.
\ This program is distributed in the hope that it will be useful,
\ but WITHOUT ANY WARRANTY; without even the implied warranty of
\ MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
\ GNU General Public License for more details.
\ You should have received a copy of the GNU General Public License
\ along with this program. If not, see http://www.gnu.org/licenses/.
\
\ @brief : MicroCore load screen for a program that is synthesized into
\          the core. It is executed immediately after the FPGA has been
\          configured and it blinks the 8 LEDS of the XP2 board
\
\ Version Author   Date       Changes
\   210     ks   14-Jun-2020  initial version
\ ----------------------------------------------------------------------
Only Forth also definitions 

[IFDEF] unpatch     unpatch    [ENDIF]
[IFDEF] close-port  close-port [ENDIF]
[IFDEF] microcore   microcore  [ENDIF]   Marker microcore

include extensions.fs           \ Some System word (re)definitions for a more sympathetic environment
include ../vhdl/architecture_pkg.vhd
include microcross.fs           \ the cross-compiler

Target new                      \ go into target compilation mode and initialize target compiler

2 code-origin
0 data-origin

include constants.fs            \ microCore Register addresses and bits

: delay ( -- ) &500 time + BEGIN  dup time? UNTIL drop ;

: blinking  ( -- )
   1 BEGIN  \ BEGIN  #f-tst flag? UNTIL
      6 FOR   2* dup leds !  delay  NEXT
      6 FOR  u2/ dup leds !  delay  NEXT
   REPEAT
; noexit

#reset TRAP: rst ( -- )    blinking ;

end

Boot-file ../vhdl/bootload.vhd cr .( bootload.fs written to ../vhdl/bootload.vhd )

