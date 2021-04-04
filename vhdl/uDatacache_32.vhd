-- ---------------------------------------------------------------------
-- @file : uDatacache_32.vhd
-- ---------------------------------------------------------------------
--
-- Last change: KS 01.04.2021 22:42:48
-- Last check in: $Rev: 674 $ $Date:: 2021-03-24 #$
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

COMPONENT internal_datamem_32 PORT (
   Clock    : IN  STD_LOGIC;
   ClockEn  : IN  STD_LOGIC;
   Reset    : IN  STD_LOGIC;
   WE       : IN  STD_LOGIC;
   Address  : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
   Data     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
   Q        : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
); END COMPONENT;

SIGNAL slv_rdata      : STD_LOGIC_VECTOR(rdata'range);
SIGNAL slv_dma_rdata  : STD_LOGIC_VECTOR(rdata'range);

BEGIN

enable <= uBus.clk_en AND uBus.mem_en WHEN  uBus.ext_en = '0'  ELSE '0';

make_sim_mem: IF  simulation OR data_width /= 32  GENERATE

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

END GENERATE make_sim_mem; make_32_mem: IF  NOT simulation AND data_width = 32  GENERATE

   instantiated_data_mem: internal_datamem_32
   PORT MAP (
      Clock     => clk,
      ClockEn   => enable,
      Reset     => '0',
      WE        => write,
      Address   => std_logic_vector(addr(cache_addr_width-1 DOWNTO 0)),
      Data      => std_logic_vector(wdata),
      Q         => slv_rdata
	);

   rdata     <= unsigned(slv_rdata);
   dma_rdata <= (OTHERS => '0');

END GENERATE make_32_mem;

END rtl;
