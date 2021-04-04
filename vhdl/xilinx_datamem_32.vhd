
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity internal_datamem_32 is
  port (
    Clock : in std_logic;
    ClockEn : in std_logic;
    WE : in std_logic;
    Reset : in std_logic;
    Address : in std_logic_vector(11 downto 0);
    Data : in std_logic_vector(31 downto 0);
    Q : out std_logic_vector(31 downto 0));
end internal_datamem_32;

architecture behavioral of internal_datamem_32 is
  type ram_type is array (3071 downto 0) of std_logic_vector (31 downto 0);
  signal RAM: ram_type := (others => (others => '0'));
begin
  process (Clock)
  begin
    if rising_edge(Clock) then
      if ClockEn = '1' then
        Q <= RAM(conv_integer(Address));
        if WE = '1' then
          RAM(conv_integer(Address)) <= Data;
        end if;
      end if;
    end if;
  end process;
end behavioral;
