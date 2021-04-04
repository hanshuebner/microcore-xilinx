-- ---------------------------------------------------------------------
-- @file : eeprom.vhd
-- ---------------------------------------------------------------------
--
-- Last change: KS 11.03.2021 11:34:30
-- Project : microCore
-- Language : VHDL-2008
-- Last check in : $Rev: 644 $ $Date:: 2021-02-17 #$
-- @copyright (c): Klaus Schleisiek, All Rights Reserved.
--
-- Do not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- https://github.com/microCore-VHDL/microCore/tree/master/documents
-- Software distributed under the License is distributed on an "AS IS"
-- basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
-- See the License for the specific language governing rights and
-- limitations under the License.
--
-- @brief: serial E2prom AT24C1024B interface
--
-- Version Author   Date       Changes
--   2300    ks   08-Mar-2021  initial version
--                             Converted to NUMERIC_STD
-- ---------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.functions_pkg.ALL;
USE work.architecture_pkg.ALL;

ENTITY eeprom IS
PORT (uBus       : IN    uBus_port;
      ee_pause   : OUT   STD_LOGIC;
      ee_scl     : OUT   STD_LOGIC;
      ee_sda     : INOUT STD_LOGIC;
      ee_data    : OUT   byte
     );
END eeprom;

ARCHITECTURE rtl OF eeprom IS

ALIAS reset         : STD_LOGIC IS uBus.reset;
ALIAS clk           : STD_LOGIC IS uBus.clk;
ALIAS ctrl          : data_bus  IS uBus.sources(CTRL_REG);
ALIAS flags         : data_bus  IS uBus.sources(FLAG_REG);

SIGNAL sda_in       : STD_LOGIC;
SIGNAL sda_out      : STD_LOGIC;
SIGNAL eaddr        : UNSIGNED(16 DOWNTO 0);
SIGNAL din          : UNSIGNED ( 7 DOWNTO 0);
SIGNAL dout         : UNSIGNED ( 7 DOWNTO 0);
SIGNAL din_full     : STD_LOGIC;
SIGNAL dout_empty   : STD_LOGIC;
SIGNAL reading      : STD_LOGIC;
SIGNAL lastbyte     : STD_LOGIC;
SIGNAL finish       : STD_LOGIC;
SIGNAL busy         : STD_LOGIC;
SIGNAL read_write   : STD_LOGIC;
SIGNAL shifter      : UNSIGNED ( 7 DOWNTO 0);
SIGNAL byte_cnt     : NATURAL RANGE 0 TO 3;
SIGNAL ee_ctr       : NATURAL RANGE 0 TO 9;
TYPE ee_states      IS (idle, start, ack, write, read, rack, last, stop);
SIGNAL ee_state     : ee_states;

CONSTANT cyc_cnt    : NATURAL := (clk_frequency/INTEGER(1.0/120.0e-9));
SIGNAL cyc_ctr      : NATURAL RANGE 0 TO cyc_cnt;
SIGNAL cycle        : STD_LOGIC;
SIGNAL phase        : NATURAL RANGE 0 TO 7;

BEGIN

ee_sda <= '0' WHEN  sda_out = '0'  ELSE 'Z';
sda_in <= to_X01(ee_sda);

ee_pause <= '1' WHEN  (uReg_write(uBus, EE_ADR_REG) AND busy = '1')
                   OR (uReg_read (uBus, EE_DAT_REG) AND din_full = '0')
                   OR (uReg_write(uBus, EE_DAT_REG) AND dout_empty = '0')
                   OR (uReg_read (uBus, EE_END_REG) AND din_full = '0')
                   OR (uReg_write(uBus, EE_END_REG) AND dout_empty = '0')
                ELSE '0';

ee_data <= std_logic_vector(din);

eeprom_io: PROCESS (reset, clk)
BEGIN
   IF  reset = '1' AND async_reset  THEN
      sda_out <= '1';
      ee_scl <= '1';
      ee_ctr <= 0;
      byte_cnt <= 0;
      ee_state <= idle;
      eaddr <= (OTHERS => '0');
      din <= (OTHERS => '0');
      din_full <= '0';
      dout <= (OTHERS => '1');
      dout_empty <= '1';
      shifter <= (OTHERS => '0');
      reading <= '0';
      read_write <= '0';
      lastbyte <= '0';
      finish <= '0';
      busy <= '0';
   ELSIF  rising_edge(clk)  THEN
      IF  cycle = '1'  THEN
         IF  phase = 0  THEN
            ee_scl <= '1';
         ELSIF  phase = 4 AND ee_state /= idle  THEN
            ee_scl <= '0';
         END IF;
         CASE ee_state IS
         WHEN idle  => sda_out <= '1';
                       read_write <= '0';
                       IF  byte_cnt = 2 AND phase = 6  THEN
                          ee_state <= start;
                          din_full <= '0';
                       END IF;
         WHEN start => IF  phase = 1  THEN
                          sda_out <= '0';
                          ee_state <= write;
                          shifter <= "101000" & eaddr(16) & read_write;
                          ee_ctr <= 9;
                       END IF;
         WHEN write => IF  phase = 4  THEN
                          ee_ctr <= ee_ctr-1;
                       ELSIF  phase = 5 AND  ee_ctr = 0  THEN
                             sda_out <= '1';
                             ee_state <= ack;
                       ELSIF  phase = 6  THEN
                          sda_out <= shifter(7);
                          shifter <= shifter(6 DOWNTO 0) & '1';
                       END IF;
         WHEN ack   => IF  phase = 4  THEN
                          IF  sda_in = '0'  THEN
                             IF  byte_cnt = 0  THEN
                                IF  reading = '1'  THEN
                                   read_write <= '1';
                                   IF  read_write = '0'  THEN
                                      ee_state <= start;
                                   ELSE
                                      ee_state <= read;
                                      ee_ctr <= 8;
                                   END IF;
                                ELSIF  finish = '1'  THEN
                                   ee_state <= stop;
                                ELSE
                                   ee_ctr <= 8;
                                   ee_state <= write;
                                   dout_empty <= '1';
                                   shifter <= dout;
                                   finish <= lastbyte;
                                END IF;
                             ELSE
                                byte_cnt <= byte_cnt-1;
                                IF  byte_cnt = 2  THEN
                                   shifter <= eaddr(15 DOWNTO 8);
                                   ee_ctr <= 8;
                                   ee_state <= write;
                                ELSE
                                   shifter <= eaddr( 7 DOWNTO 0);
                                   ee_ctr <= 8;
                                   ee_state <= write;
                                END IF;
                             END IF;
                          ELSE
                             shifter <= "101000" & eaddr(16) & '0';
                             ee_state <= start;
                          END IF;
                       END IF;
         WHEN read  => IF  phase = 3  THEN
                          shifter <= shifter(6 DOWNTO 0) & sda_in;
                       ELSIF  phase = 5  THEN
                          sda_out <= '1';
                          IF  ee_ctr = 0  THEN
                             din_full <= '1';
                             din <= shifter;
                             IF  lastbyte = '1'  THEN
                                ee_state <= last;
                             ELSE
                                ee_state <= rack;
                             END IF;
                          ELSE
                             ee_ctr <= ee_ctr-1;
                          END IF;
                       END IF;
         WHEN rack  => IF  phase = 6  THEN
                          sda_out <= '0';
                       ELSIF  phase = 5  THEN
                          sda_out <= '1';
                          ee_state <= read;
                          ee_ctr <= 7;
                          shifter <= (OTHERS => '0');
                       END IF;
         WHEN last  => IF  phase = 5  THEN
                         ee_state <= stop;
                       END IF;
         WHEN stop  => IF  phase = 6  THEN
                         sda_out <= '0';
                       ELSIF  phase = 3  THEN
                         sda_out <= '1';
                         ee_state <= idle;
                         busy <= '0';
                       END IF;
         WHEN OTHERS => NULL;
         END CASE;
      END IF;
      IF  uReg_write(uBus, EE_ADR_REG) AND busy = '0'  THEN
         lastbyte <= '0';
         finish <= '0';
         reading <= uBus.wdata(17);
         IF  ((uBus.wdata(16) = '0' OR ctrl(c_rom) = '0') AND ctrl(c_wp) = '0') OR uBus.wdata(17) = '1'  THEN
             eaddr <= unsigned(uBus.wdata(16 DOWNTO 0));
             byte_cnt <= 2;
             busy <= '1';
         END IF;
      END IF;
      IF  uReg_write(uBus, EE_DAT_REG) AND dout_empty = '1' AND reading = '0' AND busy = '1'  THEN
         dout <= unsigned(uBus.wdata(7 DOWNTO 0));
         dout_empty <= '0';
      END IF;
      IF  uReg_write(uBus, EE_END_REG) AND dout_empty = '1' AND reading = '0' AND busy = '1'  THEN
         dout <= unsigned(uBus.wdata(7 DOWNTO 0));
         dout_empty <= '0';
         lastbyte <= '1';
      END IF;
      IF  uReg_read(uBus, EE_DAT_REG)  THEN
         reading <= '1';
         IF  din_full = '1'  THEN
            din_full <= '0';
         END IF;
      END IF;
      IF  uReg_read(uBus, EE_END_REG)  THEN
         reading <= '1';
         lastbyte <= '1';
         IF  din_full = '1'  THEN
            din_full <= '0';
         END IF;
      END IF;
      IF  reset = '1' AND NOT async_reset  THEN
         sda_out <= '1';
         ee_scl <= '1';
         ee_ctr <= 0;
         byte_cnt <= 0;
         ee_state <= idle;
         eaddr <= (OTHERS => '0');
         din <= (OTHERS => '0');
         din_full <= '0';
         dout <= (OTHERS => '1');
         dout_empty <= '1';
         shifter <= (OTHERS => '0');
         reading <= '0';
         read_write <= '0';
         lastbyte <= '0';
         finish <= '0';
         busy <= '0';
      END IF;
   END IF;
END PROCESS eeprom_io;

cycle <= '1' WHEN  cyc_ctr=0  ELSE '0';

cyc_counter : PROCESS (reset, clk)
BEGIN
   IF  reset = '1' AND async_reset  THEN
      cyc_ctr <= 0;
      phase <= 0;
   ELSIF  rising_edge(clk)  THEN
      IF    (ee_state /= read OR phase /= 7 OR din_full = '0'   OR ee_ctr /= 0)
        AND (ee_state /= ack  OR phase /= 7 OR dout_empty = '0' OR reading = '1' OR byte_cnt /= 0 OR finish = '1')
      THEN
         IF  cyc_ctr = cyc_cnt  THEN
            cyc_ctr <= 0;
         ELSE
            cyc_ctr <= cyc_ctr+1;
         END IF;
         IF  cycle = '1'  THEN
            IF  phase = 7  THEN
               phase <= 0;
            ELSE
               phase <= phase+1;
            END IF;
         END IF;
      ELSE
         cyc_ctr <= cyc_cnt;
      END IF;
      IF  reset = '1' AND NOT async_reset  THEN
         cyc_ctr <= 0;
         phase <= 0;
      END IF;
   END IF;
END PROCESS cyc_counter;

END rtl;
