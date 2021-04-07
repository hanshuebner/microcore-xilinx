\ ----------------------------------------------------------------------
\ @file : constants.fs for the Lattice XP2-8 demoboard
\ ----------------------------------------------------------------------
\
\ Last change: KS 05.04.2021 16:46:52
\ @project: microForth/microCore
\ @language: gforth_0.6.2
\ @copyright (c): Free Software Foundation
\ @original author: ks - Klaus Schleisiek
\ @contributor:
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
\ @brief : MicroCore hardware/software interface: Register Constants
\          Quantities between H ..... T due to loading
\          architecture_pkg.VHD on the Host.
\
\ Version Author   Date       Changes
\   210     ks   14-Jun-2020  initial version
\ ----------------------------------------------------------------------
Target

\ ----------------------------------------------------------------------
\ Memory mapping
\ ----------------------------------------------------------------------

\ ----------------------------------------------------------------------
\ registers and bits
\ ----------------------------------------------------------------------

H STATUS_REG    T Register Status
H s_c       T Bit #c            \    1 carry mask
H s_ovfl    T Bit #ovfl         \    2 integer and float overflow mask
H s_ie      T Bit #ie           \    4 interrupt enable mask
H s_iis     T Bit #iis          \    8 interrupt in service mask
H s_lit     T Bit #lit          \  $10 previous instruction was lit_instruction mask
H s_neg     T Bit #neg          \  $20 sign mask
H s_zero    T Bit #zero         \  $40 zero mask
H s_div     T Bit #sign-div     \  $80 sign of DIVisor mask
H s_den     T Bit #sign-den     \ $100 sign of DividENd mask
H s_unfl    T Bit #unfl         \ $200 float underflow mask

H DSP_REG       T Register Dsp

H RSP_REG       T Register Rsp

H INT_REG       T Register Int-reg
H i_ext     T Bit #i-ext
H i_time    T Bit #i-time
H FLAG_REG      T Register Flag-reg
H f_dsu     T Bit #f-dsu      \ set while umbilical is active (no break on rxd)
H f_sema    T Bit #f-sema
H f_bitout  T Bit #f-bitout
H f_sw1     T Bit #sw1
H f_sw2     T Bit #sw2
H f_sw3     T Bit #sw3
H f_sw4     T Bit #sw4

H VERSION_REG   T Register Version-reg

H DEBUG_REG     T Register Debug-reg

H CTRL_REG      T Register Ctrl-reg
H c_bitout  T Bit #c-bitout

H TIME_REG      T Register Time-reg

H LED_REG       T Register Leds

H IO_REG        T Register io

