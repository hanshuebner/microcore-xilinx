-- ---------------------------------------------------------------------
-- @file : fpga.vhd for the Spartan-3A Evaluation Kit
-- ---------------------------------------------------------------------
--
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
-- @brief: Top level microCore entity with umbilical debug interface.
--         This file should be edited for technology specific additions
--         like e.g. pad assignments and it is the source of the uBus.
--
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
-- umbilical uart for debugging
   serial_rxd   : IN  STD_LOGIC;        -- incoming asynchronous data stream
   serial_txd   : OUT STD_LOGIC;        -- outgoing data stream
   rxd_out      : out STD_LOGIC;
   txd_out      : out STD_LOGIC
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

ATTRIBUTE LOC      OF serial_rxd     : SIGNAL IS "A3";
   ATTRIBUTE PULLMODE OF serial_rxd  : SIGNAL IS "NONE";
   ATTRIBUTE IO_TYPE  OF serial_rxd  : SIGNAL IS "LVCMOS33";

ATTRIBUTE LOC      OF serial_txd     : SIGNAL IS "B3";
   ATTRIBUTE PULLMODE OF serial_txd  : SIGNAL IS "NONE";
   ATTRIBUTE IO_TYPE  OF serial_txd  : SIGNAL IS "LVCMOS33";
   ATTRIBUTE DRIVE    OF serial_txd  : SIGNAL IS "8";
   ATTRIBUTE SLEWRATE OF serial_txd  : SIGNAL IS "SLOW";

ATTRIBUTE LOC      OF rxd_out     : SIGNAL IS "A8";
   ATTRIBUTE PULLMODE of rxd_out  : SIGNAL IS "NONE";
   ATTRIBUTE IO_TYPE  OF rxd_out  : SIGNAL IS "LVCMOS33";

ATTRIBUTE LOC      OF txd_out     : SIGNAL IS "C7";
   ATTRIBUTE PULLMODE of txd_out  : SIGNAL IS "NONE";
   ATTRIBUTE IO_TYPE  OF txd_out  : SIGNAL IS "LVCMOS33";

END fpga;

ARCHITECTURE technology OF fpga IS

SIGNAL uBus       : uBus_port;
ALIAS  reset      : STD_LOGIC IS uBus.reset;
ALIAS  clk        : STD_LOGIC IS uBus.clk;
ALIAS  clk_en     : STD_LOGIC IS uBus.clk_en;

SIGNAL reset_a    : STD_LOGIC; -- asynchronous reset positive logic
SIGNAL reset_s    : STD_LOGIC; -- synchronized reset_button
SIGNAL serial_rxd_s  : STD_LOGIC;
SIGNAL serial_break  : STD_LOGIC;

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

SIGNAL dcache_en    : STD_LOGIC;
SIGNAL dcache_rdata : data_bus;
SIGNAL mem_rdata    : data_bus;
SIGNAL dma_mem      : datamem_port;
SIGNAL dma_rdata    : data_bus;
SIGNAL cache_addr   : data_addr;    -- for simulation only

SIGNAL ext_rdata    : data_bus;
SIGNAL SRAM_delay   : STD_LOGIC;

-- board specific IO
SIGNAL leds         : byte;
SIGNAL time_int     : STD_LOGIC;
SIGNAL ioreg        : UNSIGNED(14 DOWNTO 0);

SIGNAL serial_txd_buf : STD_LOGIC;

BEGIN

flags(7 DOWNTO 5) <= (OTHERS => '0');

-- ---------------------------------------------------------------------
-- input signal synchronization
-- ---------------------------------------------------------------------

reset_a <= reset_button;
synch_reset: synchronize PORT MAP(clk, reset_a, reset_s);
reset <= reset_a OR reset_s;

synch_serial_rxd:   synchronize   PORT MAP(clk, serial_rxd, serial_rxd_s);

-- ---------------------------------------------------------------------
-- debugging
-- ---------------------------------------------------------------------

rxd_out <= serial_rxd;
txd_out <= serial_txd_buf;
serial_txd <= serial_txd_buf;

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

flags(f_dsu) <= NOT serial_break; -- '1' if debug terminal present

uCore: microcore PORT MAP (
   uBus       => uBus,
   core       => core,
   memory     => memory,
-- umbilical uart interface
   rxd        => serial_rxd_s,
   break      => serial_break,
   txd        => serial_txd_buf
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
leds_out(0) <= NOT Ctrl(c_bitout) WHEN  SIMULATION  ELSE  NOT leds(0);

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
