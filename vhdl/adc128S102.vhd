-----------------------------------------------------------------
-- adc.vhd                                                     --
-----------------------------------------------------------------
--
-- Author: KLAUS SCHLEISIEK
-- Last change: KS 21.03.2017 12:14:46
--
-- Interface for the ADC128S102 12-bit, 8 channel AD converter
--
--------------------------------------------------------------------------
-- Functional description of the interface:
--
-- There is one register IO_REG (a generic) and one interrupt flag f_adc.
-- When IO_REG is written with the channel address, conversion starts.
-- When IO_REG is read, the result (after the 2nd conversion) is read.
-- When the ADC128 is not yet finished converting, an exception is raised.
-- When the conversion is finished, f_adc is set and reset by
-- reading IO_REG.
-- Writing IO_REG starts just one (double) conversion cycle.
--------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_signed.ALL;
USE work.functions.ALL;
USE work.constants.ALL;

ENTITY ADC128S102 IS
GENERIC (io_reg   : INTEGER;
         semaphor : NATURAL);
PORT (uBus        : IN  uBus_port;
      adc_exc     : OUT STD_LOGIC;
      adc_int     : OUT STD_LOGIC;
      adc_data    : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
-- ADC128S102 interface
      adc_cs_n    : OUT STD_LOGIC;
      adc_sclk    : OUT STD_LOGIC;
      adc_din     : OUT STD_LOGIC;
      adc_dout    : IN  STD_LOGIC
     );
END ADC128S102;

ARCHITECTURE rtl OF ADC128S102 IS

ALIAS reset         : STD_LOGIC IS uBus.reset;
ALIAS clk           : STD_LOGIC IS uBus.clk;
ALIAS clk_en        : STD_LOGIC IS uBus.clk_en;
SIGNAL channel      : STD_LOGIC_VECTOR(4 DOWNTO 0);
SIGNAL clk_ctr      : STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL cycle        : NATURAL RANGE 0 TO 16;
SIGNAL phase        : INTEGER RANGE 0 TO 1;
SIGNAL busy         : STD_LOGIC;
SIGNAL shifter      : STD_LOGIC_VECTOR(11 DOWNTO 0);

BEGIN

adc_cs_n <= NOT busy;
adc_sclk <= NOT clk_ctr(1);

adc_exc <= '1' WHEN  (uReg_write(uBus, IO_REG) AND busy = '1')
                  OR (uReg_read (uBus, IO_REG) AND busy = '1')
               ELSE '0';

adc_ctrl_proc : PROCESS (reset, clk)
BEGIN
   IF  rising_edge(clk)  THEN
      IF  reset = '1'  THEN
         cycle <= 0;
         phase <= 0;
         adc_int <= '0';
         busy <= '0';
         adc_din <= '0';
         clk_ctr <= (OTHERS => '0');
      ELSE
         IF  busy = '0'  THEN
            IF  uReg_write(uBus, IO_REG)  THEN
               channel <= "00" & uBus.dout(2 DOWNTO 0);
               busy <= '1';
               phase <= 0;
               cycle <= 15;
               clk_ctr <= (OTHERS => '0');
            END IF;
            IF  uReg_write(uBus, FLAG_REG) AND uBus.dout(semaphor) = '1'  THEN
               adc_int <= '1';
            END IF;
            IF  uReg_read (uBus, IO_REG)  THEN
               adc_int <= '0';
            END IF;
         ELSE --  busy = '1'
            IF  cycle = 0 AND phase = 1  THEN
               busy <= '0';
               adc_int <= '1';
               adc_data <= shifter;
            ELSE
               clk_ctr <= clk_ctr + 1;
               IF  clk_ctr = "01"  THEN
                  channel <= channel(3 DOWNTO 0) & '0';
                  adc_din <= channel(4);
               END IF;
               IF  clk_ctr = "11"  THEN
                  shifter <= shifter(10 DOWNTO 0) & adc_dout;
                  IF  cycle = 0  THEN
                     cycle <= 16;
                     phase <= 1;
                  ELSE
                     cycle <= cycle - 1;
                  END IF;
               END IF;
            END IF;
         END IF;
      END IF;
   END IF;
END PROCESS adc_ctrl_proc;

END rtl;
