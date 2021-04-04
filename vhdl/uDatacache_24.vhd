-- ---------------------------------------------------------------------
-- @file : uDatacache_24.vhd
-- ---------------------------------------------------------------------
--
-- Last change: KS 01.04.2021 22:42:48
-- Last check in: $Rev: 683 $ $Date:: 2021-04-01 #$
-- @project: microCore
-- @language : VHDL-2008
-- @copyright (c): Klaus Schleisiek, All Rights Reserved.
-- @contributors :
--
-- @license: Do not use this file except in compliance with the License.
-- You may obtain a copy of the Public License at
-- https://github.com/microCore-VHDL/microCore/tree/master/documents
-- Software distributed under the License is distributed on an "AS IS"
-- basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
-- See the License for the specific language governing rights and
-- limitations under the License.
--
-- @brief: Definition of the internal data memory.
--         Here fpga specific dual port memory IP can be included.
--
-- Version Author   Date       Changes
--   210     ks    8-Jun-2020  initial version
--  2300     ks    8-Mar-2021  Conversion to NUMERIC_STD
-- ---------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.functions_pkg.ALL;
USE work.architecture_pkg.ALL;

ENTITY uDatacache IS PORT (
   uBus        : IN  uBus_port;
   rdata       : OUT data_bus;
   dma_mem     : IN  datamem_port;
   dma_rdata   : OUT data_bus
); END uDatacache;

ARCHITECTURE rtl OF uDatacache IS

ALIAS clk        : STD_LOGIC IS uBus.clk;
ALIAS write      : STD_LOGIC IS uBus.write;
ALIAS addr       : data_addr IS uBus.addr;
ALIAS wdata      : data_bus  IS uBus.wdata;
ALIAS dma_enable : STD_LOGIC IS dma_mem.enable;
ALIAS dma_write  : STD_LOGIC IS dma_mem.write;
ALIAS dma_addr   : data_addr IS dma_mem.addr;
ALIAS dma_wdata  : data_bus  IS dma_mem.wdata;

SIGNAL enable    : STD_LOGIC;

BEGIN

enable <= uBus.clk_en AND uBus.mem_en WHEN  uBus.ext_en = '0'  ELSE '0';

make_sim_mem: IF  simulation OR data_width /= 24  GENERATE

   internal_data_mem: internal_dpram
   GENERIC MAP (data_width, cache_addr_width, "rw_check", DMEM_file)
   PORT MAP (
      clk     => clk,
      ena     => enable,
      wea     => write,
      addra   => addr(cache_addr_width-1 DOWNTO 0),
      dia     => wdata,
      doa     => rdata,
      enb     => dma_enable,
      web     => dma_write,
      addrb   => dma_addr(cache_addr_width-1 DOWNTO 0),
      dib     => dma_wdata,
      dob     => dma_rdata
   );

END GENERATE make_sim_mem; make_24_mem: IF  NOT simulation AND data_width = 24  GENERATE

   internal_data_mem: internal_dpram
   GENERIC MAP (data_width, cache_addr_width, "rw_check")
   PORT MAP (
      clk     => clk,
      ena     => enable,
      wea     => write,
      addra   => addr(cache_addr_width-1 DOWNTO 0),
      dia     => wdata,
      doa     => rdata,
      enb     => dma_enable,
      web     => dma_write,
      addrb   => dma_addr(cache_addr_width-1 DOWNTO 0),
      dib     => dma_wdata,
      dob     => dma_rdata
   );

END GENERATE make_24_mem;

END rtl;
