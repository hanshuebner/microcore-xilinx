-----------------------------------------------------------------
-- dac.vhd                                                     --
-----------------------------------------------------------------
--
-- Author: KLAUS SCHLEISIEK
-- Last change: KS 14.10.2016 10:15:43
--
-- Interface for the AD5623 DAC
--

LIBRARY IEEE;
USE     IEEE.STD_LOGIC_1164.ALL;
USE     IEEE.STD_LOGIC_signed.ALL;
USE     work.functions.ALL;
USE     work.constants.ALL;

ENTITY dac_ad5623 IS
PORT (uBus        : IN  uBus_port;
      exc         : OUT STD_LOGIC;
      dac_clk     : OUT STD_LOGIC;
      dac_cs      : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      dac_din     : OUT STD_LOGIC
     );
END dac_ad5623;

ARCHITECTURE rtl OF dac_ad5623 IS

ALIAS  reset        : STD_LOGIC IS uBus.reset;
ALIAS  clk          : STD_LOGIC IS uBus.clk;
ALIAS  clk_en       : STD_LOGIC IS uBus.clk_en;
ALIAS  data         : data_bus  IS uBus.dout;

SIGNAL busy         : STD_LOGIC;
SIGNAL dac_shift    : STD_LOGIC_VECTOR(23 DOWNTO 0);
SIGNAL clock        : STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL dac_ctr      : NATURAL RANGE 24 DOWNTO 0;

BEGIN

dac_clk <= clock(1);
dac_din <= dac_shift(23);
exc     <= '1' WHEN  busy = '1' AND
                     (uReg_write(uBus, DAC_REG)  OR uReg_write(uBus, DAC0_REG) OR
                      uReg_write(uBus, DAC1_REG) OR uReg_write(uBus, DAC2_REG) OR
                      uReg_write(uBus, DAC4_REG)
                     )  ELSE '0';

dac_proc : PROCESS (clk, reset)

PROCEDURE to_dac (cs : IN STD_LOGIC_VECTOR(2 DOWNTO 0)) IS
BEGIN
   dac_cs <= cs;
   dac_ctr <= 24;
   dac_shift <= data(23 DOWNTO 0);
   busy <= '1';
   clock <= "10";
END to_dac;

BEGIN
   IF  rising_edge(clk)  THEN
      IF  reset = '1'  THEN
         clock <= (OTHERS => '0');
         dac_ctr <= 0;
         dac_cs <= (OTHERS => '0');
         busy <= '0';
      ELSE
         IF  dac_ctr = 0  THEN
            busy <= '0';
            dac_cs <= (OTHERS => '0');
            IF  uReg_write(uBus, DAC_REG)  THEN  -- configuration of DAC0 and DAc1
               to_dac("001");
            END IF;
            IF  uReg_write(uBus, DAC0_REG)  THEN -- write data to DAC0
               to_dac("001");
               dac_shift <= "00011000" & data(11 DOWNTO 0) & "0000";
            END IF;
            IF  uReg_write(uBus, DAC1_REG)  THEN -- write data to DAC1
               to_dac("001");
               dac_shift <= "00011001" & data(11 DOWNTO 0) & "0000";
            END IF;
            IF  uReg_write(uBus, DAC2_REG)  THEN -- write config to DAC2 and DAC3
               to_dac("010");
            END IF;
            IF  uReg_write(uBus, DAC4_REG)  THEN -- write config to DAC4 and DAC5
               to_dac("100");
            END IF;
         ELSE
            clock <= clock + 1;
            IF  clock = "01"  THEN
               dac_shift <= dac_shift(22 DOWNTO 0) & '0';
            ELSIF  clock = "11"  THEN
               dac_ctr <= dac_ctr - 1;
            END IF;
         END IF;
      END IF;
   END IF;
END PROCESS dac_proc;

END rtl;
