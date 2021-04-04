library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity test is

  generic(

    action : string := "Adder"

  );

  port(

    A    : in  std_logic;
    B    : in std_logic;
    C    : in std_logic;
    X    : out std_logic;
    Y    : out std_logic
  );

end entity test;


architecture behavioral of test is

component full_adder is
Port ( Data_in_A,Data_in_B,Data_in_C : in  STD_LOGIC;
Data_out_Sum,Data_out_Carry : out  STD_LOGIC);
end component;

component full_sub is
Port ( Data_in_A,Data_in_B,Data_in_C : in  STD_LOGIC;
Data_out_Diff,Data_out_Borrow : out  STD_LOGIC);
end component;

begin

  fulladder_generate : if action = "Adder" generate

  begin

--  fa_test_inst : entity lib1.dum_fa
  fa_test_inst : full_adder port map(
			Data_in_A => A,
			Data_in_B => B,
			Data_in_C => C,
			Data_out_Sum => X,
			Data_out_Carry => Y
	);

    end generate;

    

    subtractor_generate : if action = "subtract" generate

    begin

    fs_test_inst : full_sub  port map(
			Data_in_A => A,
			Data_in_B => B,
			Data_in_C => C,
			Data_out_Diff => X,
			Data_out_Borrow => Y


        );

    end generate;

end behavioral;

