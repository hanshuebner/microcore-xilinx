-- ---------------------------------------------------------------------
-- ---------------------------------------------------------------------
-- @file : spartan3a-evl.vhd - Toplevel for the Spartan-3A Evaluation Kit
-- ---------------------------------------------------------------------
--
-- Last change: KS 02.04.2021 18:34:55
-- @project: microCore
-- @language: VHDL-93
-- @copyright (c): Klaus Schleisiek, All Rights Reserved.
-- @contributors:
--
-- @license: Do not use this file except in compliance with the License.
-- You may obtain a copy of the Public License at
-- https://github.com/microCore-VHDL/microCore/tree/master/documents
-- Software distributed under the License is distributed on an "AS IS"
-- basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
-- See the License for the specific language governing rights and
-- limitations under the License.
--
-- @brief: Top level microCore entity with umbilical debug interface.
--         This file should be edited for technology specific additions
--         like e.g. pad assignments and it is the source of the uBus.
--
-- Version Author   Date       Changes
--   210     ks    8-Jun-2020  initial version
--  2300     ks    8-Mar-2021  converted to NUMERIC_STD
-- ---------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.functions_pkg.ALL;
USE work.architecture_pkg.ALL;

ENTITY fpga IS PORT (
   reset_button : IN  STD_LOGIC;
   clock        : IN  STD_LOGIC;        -- external clock input
   leds_out     : OUT UNSIGNED(3 downto 0);
   buttons      : in  STD_LOGIC_VECTOR(2 downto 0);
-- external memory interface (unused on S3A-EVL)
   ce_n        : OUT   STD_LOGIC;
   oe_n        : OUT   STD_LOGIC;
   we_n        : OUT   STD_LOGIC;
   addr        : OUT   UNSIGNED(ram_addr_width-1 DOWNTO 0);
   data        : INOUT UNSIGNED(ram_data_width-1 DOWNTO 0);
-- umbilical uart for debugging
   dsu_rxd     : IN    STD_LOGIC;  -- incoming asynchronous data stream
   dsu_txd     : OUT   STD_LOGIC   -- outgoing data stream
);

ATTRIBUTE LOC       : STRING;
ATTRIBUTE PULLMODE  : STRING;
ATTRIBUTE IO_TYPE   : STRING;
ATTRIBUTE DRIVE     : STRING;
ATTRIBUTE SLEWRATE  : STRING;

ATTRIBUTE LOC      OF reset_button     : SIGNAL IS "H4";
   ATTRIBUTE PULLMODE OF reset_button  : SIGNAL IS "UP";
   ATTRIBUTE IO_TYPE  OF reset_button  : SIGNAL IS "LVCMOS33";

ATTRIBUTE LOC      OF clock       : SIGNAL IS "C10";
   ATTRIBUTE PULLMODE OF clock    : SIGNAL IS "NONE";
   ATTRIBUTE IO_TYPE  OF clock    : SIGNAL IS "LVCMOS33";

ATTRIBUTE LOC      OF leds_out    : SIGNAL IS "D14, C16, C15, B15";
   ATTRIBUTE PULLMODE OF leds_out : SIGNAL IS "NONE";
   ATTRIBUTE IO_TYPE  OF leds_out : SIGNAL IS "LVCMOS33";
   ATTRIBUTE DRIVE    OF leds_out : SIGNAL IS "12";
   ATTRIBUTE SLEWRATE OF leds_out : SIGNAL IS "SLOW";

ATTRIBUTE LOC      OF buttons    : SIGNAL IS "K3, H5, L3";
   ATTRIBUTE PULLMODE OF buttons : SIGNAL IS "UP";
   ATTRIBUTE IO_TYPE  OF buttons : SIGNAL IS "LVCMOS33";

ATTRIBUTE LOC      OF dsu_rxd     : SIGNAL IS "A3";
   ATTRIBUTE PULLMODE OF dsu_rxd  : SIGNAL IS "NONE";
   ATTRIBUTE IO_TYPE  OF dsu_rxd  : SIGNAL IS "LVCMOS33";

ATTRIBUTE LOC      OF dsu_txd     : SIGNAL IS "B3";
   ATTRIBUTE PULLMODE OF dsu_txd  : SIGNAL IS "NONE";
   ATTRIBUTE IO_TYPE  OF dsu_txd  : SIGNAL IS "LVCMOS33";
   ATTRIBUTE DRIVE    OF dsu_txd  : SIGNAL IS "8";
   ATTRIBUTE SLEWRATE OF dsu_txd  : SIGNAL IS "SLOW";

END fpga;

ARCHITECTURE technology OF fpga IS

SIGNAL uBus       : uBus_port;
ALIAS  reset      : STD_LOGIC IS uBus.reset;
ALIAS  clk        : STD_LOGIC IS uBus.clk;
ALIAS  clk_en     : STD_LOGIC IS uBus.clk_en;

SIGNAL reset_a    : STD_LOGIC; -- asynchronous reset positive logic
SIGNAL reset_s    : STD_LOGIC; -- synchronized reset_n
SIGNAL dsu_rxd_s  : STD_LOGIC;
SIGNAL dsu_break  : STD_LOGIC;

COMPONENT microcore PORT (
   uBus        : IN    uBus_port;
   core        : OUT   core_signals;
   memory      : OUT   datamem_port;
-- umbilical uart interface
   rxd         : IN    STD_LOGIC;
   break       : OUT   STD_LOGIC;
   txd         : OUT   STD_LOGIC
); END COMPONENT microcore;

SIGNAL core         : core_signals;
SIGNAL flags        : flag_bus;
SIGNAL flags_pause  : STD_LOGIC;
SIGNAL ctrl         : UNSIGNED(ctrl_width-1 DOWNTO 0);
SIGNAL memory       : datamem_port; -- multiplexed memory signals

-- data memory
COMPONENT uDatacache PORT (
   uBus        : IN  uBus_port;
   rdata       : OUT data_bus;
   dma_mem     : IN  datamem_port;
   dma_rdata   : OUT data_bus
); END COMPONENT uDatacache;

SIGNAL dcache_rdata : data_bus;
SIGNAL mem_rdata    : data_bus;
SIGNAL dma_mem      : datamem_port;
SIGNAL dma_rdata    : data_bus;
SIGNAL cache_addr   : data_addr;    -- for simulation only

-- external memory
COMPONENT external_SRAM GENERIC (
   ram_addr_width : NATURAL;
   ram_data_width : NATURAL;
   delay_cnt      : NATURAL    -- delay_cnt+1 extra clock cycles for each memory access
); PORT (
   uBus        : IN    uBus_port;
   ext_rdata   : OUT   data_bus;
   delay       : OUT   STD_LOGIC;
-- external SRAM
   ce_n        : OUT   STD_LOGIC;
   oe_n        : OUT   STD_LOGIC;
   we_n        : OUT   STD_LOGIC;
   addr        : OUT   UNSIGNED(ram_addr_width-1 DOWNTO 0);
   data        : INOUT UNSIGNED(ram_data_width-1 DOWNTO 0)
); END COMPONENT external_SRAM;

SIGNAL ext_rdata    : data_bus;
SIGNAL SRAM_delay   : STD_LOGIC;

-- board specific IO
SIGNAL leds         : byte;
SIGNAL time_int     : STD_LOGIC;
SIGNAL ioreg        : UNSIGNED(14 DOWNTO 0);

BEGIN

flags(7 DOWNTO 5) <= (OTHERS => '0');

-- ---------------------------------------------------------------------
-- input signal synchronization
-- ---------------------------------------------------------------------

reset_a <= reset_button;
synch_reset: synchronize PORT MAP(clk, reset_a, reset_s);
reset <= reset_a OR reset_s;

synch_dsu_rxd:   synchronize   PORT MAP(clk, dsu_rxd, dsu_rxd_s);

-- ---------------------------------------------------------------------
-- clk generation (perhaps a PLL will be used)
-- ---------------------------------------------------------------------

clk <= clock;

-- ---------------------------------------------------------------------
-- ctrl-register (bitwise)
-- ---------------------------------------------------------------------

ctrl_proc: PROCESS (reset, clk)
BEGIN
   IF  reset = '1' AND ASYNC_RESET  THEN
      ctrl <= (OTHERS => '0');
   ELSIF  rising_edge(clk)  THEN
      IF  uReg_write(uBus, CTRL_REG)  THEN
         IF  uBus.wdata(signbit) = '0'  THEN
               ctrl <= ctrl OR  uBus.wdata(ctrl'range);
         ELSE  ctrl <= ctrl AND uBus.wdata(ctrl'range);
         END IF;
      END IF;
      IF  reset = '1' AND NOT ASYNC_RESET  THEN
         ctrl <= (OTHERS => '0');
      END IF;
   END IF;
END PROCESS ctrl_proc;

flags(f_bitout) <= ctrl(c_bitout);

uBus.sources(CTRL_REG) <= resize(ctrl, data_width);

-- ---------------------------------------------------------------------
-- software semaphor f_sema using flag register
-- ---------------------------------------------------------------------

sema_proc : PROCESS (clk, reset)
BEGIN
   IF  reset = '1' AND ASYNC_RESET  THEN
      flags(f_sema) <= '0';
   ELSIF  rising_edge(clk)  THEN
      IF  uReg_write(uBus, FLAG_REG)  THEN
         IF  (uBus.wdata(signbit) XOR uBus.wdata(f_sema)) = '1'  THEN
            flags(f_sema) <= uBus.wdata(f_sema);
         END IF;
      END IF;
      IF  reset = '1' AND NOT ASYNC_RESET  THEN
         flags(f_sema) <= '0';
      END IF;
   END IF;
END PROCESS sema_proc;

flags_pause <= '1' WHEN  uReg_write(uBus, FLAG_REG) AND uBus.wdata(signbit) = '0' AND
                         unsigned(uBus.wdata(flag_width-1 DOWNTO 0) AND flags) /= 0
               ELSE  '0';

-- ---------------------------------------------------------------------
-- microcore interface
-- ---------------------------------------------------------------------

flags(f_dsu) <= NOT dsu_break; -- '1' if debug terminal present

uCore: microcore PORT MAP (
   uBus       => uBus,
   core       => core,
   memory     => memory,
-- umbilical uart interface
   rxd        => dsu_rxd_s,
   break      => dsu_break,
   txd        => dsu_txd
);

-- control signals
--ALIAS  reset        : STD_LOGIC IS uBus.reset;
--ALIAS  clk          : STD_LOGIC IS uBus.clk;
uBus.clk_en               <= core.clk_en;
uBus.chain                <= core.chain;
uBus.pause                <= flags_pause;
uBus.delay                <= SRAM_delay;
uBus.tick                 <= core.tick;
-- registers
uBus.sources(STATUS_REG)  <= resize(core.status, data_width);
uBus.sources(DSP_REG)     <= resize(core.dsp, data_width);
uBus.sources(RSP_REG)     <= addr_rstack_v(data_width-1 DOWNTO rsp_width) & core.rsp;
uBus.sources(INT_REG)     <= resize(core.int, data_width);
uBus.sources(FLAG_REG)    <= resize(flags, data_width);
uBus.sources(VERSION_REG) <= to_unsigned(version, data_width);
uBus.sources(DEBUG_REG)   <= core.debug;
uBus.sources(TIME_REG)    <= core.time;
-- data memory and return stack
uBus.reg_en               <= core.reg_en;
uBus.mem_en               <= core.mem_en;
uBus.ext_en               <= core.ext_en;
uBus.write                <= memory.write;
uBus.addr                 <= memory.addr;
uBus.wdata                <= memory.wdata;
uBus.rdata                <= mem_rdata;

-- ---------------------------------------------------------------------
-- data memory consisting of dcache, ext_mem, and debugmem
-- ---------------------------------------------------------------------

dma_mem.enable <= '0';
dma_mem.write  <= '0';
dma_mem.addr   <= (OTHERS => '0');
dma_mem.wdata  <= (OTHERS => '0');

internal_data_mem: uDatacache PORT MAP (
   uBus         => uBus,
   rdata        => dcache_rdata,
   dma_mem      => dma_mem,
   dma_rdata    => dma_rdata
);

mem_rdata_proc : PROCESS (uBus, dcache_rdata, ext_rdata)
BEGIN
   mem_rdata <= dcache_rdata;
   IF  uBus.ext_en = '1' AND WITH_EXTMEM  THEN
      mem_rdata <= ext_rdata;
   END IF;
END PROCESS mem_rdata_proc;

-- pragma translate_off
memaddr_proc : PROCESS (clk)
BEGIN
   IF  rising_edge(clk)  THEN
      IF  (clk_en AND core.mem_en) = '1'  THEN
         cache_addr <= memory.addr; -- state of the internal blockRAM address register for simulation
      END IF;
END IF;
END PROCESS memaddr_proc;
-- pragma translate_on
-- ---------------------------------------------------------------------
-- external SRAM data memory
-- ---------------------------------------------------------------------

with_external_mem: IF  WITH_EXTMEM  GENERATE

   SRAM: external_SRAM
   GENERIC MAP (ram_addr_width, ram_data_width, 1)
   PORT MAP (
      uBus        => uBus,
      ext_rdata   => ext_rdata,
      delay       => SRAM_delay,
   -- external SRAM
      ce_n        => ce_n,
      oe_n        => oe_n,
      we_n        => we_n,
      addr        => addr,
      data        => data
);

END GENERATE with_external_mem; no_external_mem: IF  NOT WITH_EXTMEM  GENERATE

   ext_rdata  <= (OTHERS => '0');
   SRAM_delay <= '0';

   ce_n <= '1';
   we_n <= '1';
   oe_n <= '1';
   addr <= (OTHERS => '0');
   data <= (OTHERS => 'Z');

END GENERATE no_external_mem;

-- ---------------------------------------------------------------------
-- Spartan-3A Eval Kit specific IO
-- ---------------------------------------------------------------------

led_proc: PROCESS (reset, clk)
BEGIN
   IF  reset = '1' AND ASYNC_RESET  THEN
      leds <= (OTHERS => '0');
   ELSIF  rising_edge(clk)  THEN
      IF  uReg_write(uBus, LED_REG)  THEN
         leds <= uBus.wdata(7 DOWNTO 0);
      END IF;
      IF  reset = '1' AND NOT ASYNC_RESET  THEN
         leds <= (OTHERS => '0');
      END IF;
   END IF;
END PROCESS led_proc;

uBus.sources(LED_REG) <= resize(leds, data_width);

leds_out(leds_out'high DOWNTO 1) <= leds(leds_out'high DOWNTO 1);
leds_out(0) <= NOT Ctrl(c_bitout) WHEN  SIMULATION  ELSE leds(0);

flags(f_sw1) <= buttons(0);
flags(f_sw2) <= buttons(1);
flags(f_sw3) <= buttons(2);

time_int_proc : PROCESS (clk)
BEGIN
   IF  rising_edge(clk)  THEN
      IF  uBus.tick = '1'  THEN
         time_int <= '1';
      END IF;
      IF  uReg_write(uBus, FLAG_REG) AND uBus.wdata(signbit) = '1' AND uBus.wdata(i_time) = '0'  THEN
         time_int <= '0';
      END IF;
   END IF;
END PROCESS time_int_proc;

flags(i_time) <= time_int;

END technology;

