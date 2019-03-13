--Testbench for RX communication

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity echo_tb is
end echo_tb;

architecture RTL of echo_tb is

	component echo_top
		Port (
			clk 			: in 	STD_LOGIC;							--logic clock
			clr 			: in 	STD_LOGIC;							--clear signal
			dataIn		: in  STD_LOGIC;							--data from FTDI Chip
			dataOut		: out STD_LOGIC;							--data to FTDI Chip
			words			: out	STD_LOGIC_VECTOR(10 downto 0)	--Number of words stored in FIFO
		);
	end component;
	
	signal clk, clr, dataIn, dataOut : STD_LOGIC := '1';
	--signal q : STD_LOGIC_VECTOR(7 downto 0);
	signal words : STD_LOGIC_VECTOR(10 downto 0);
	signal endsimulation : boolean := false;
	
	begin
	
	UUT : echo_top port map (
		clk 		=> clk,
		clr 		=> clr,
		dataIn	=> dataIn,
		dataOut	=> dataOut,
		words		=> words
	);
	
	--clock
	clk_proc: process
	begin
		if not endsimulation then
			clk <= not clk;
			wait for 10ns;
		else
			wait;
		end if;
	end process;
	
	stim_proc: process 
	begin
		wait for 20ns;
		clr <= '0';
		wait for 10us;
		
		dataIn <= '0';			--start bit
		wait for 8.61us;
		dataIn <= '1';
		wait for 8.61us;
		dataIn <= '0';
		wait for 8.61us;
		dataIn <= '1';
		wait for 8.61us;
		dataIn <= '0';
		wait for 8.61us;
		dataIn <= '1';
		wait for 8.61us;
		dataIn <= '0';
		wait for 8.61us;
		dataIn <= '1';
		wait for 8.61us;
		dataIn <= '0';
		wait for 8.61us;
		dataIn <= '1';			--stop bit + idle
		wait for 50us;
		
		dataIn <= '0';			--start bit
		wait for 8.61us;
		dataIn <= '1';
		wait for 8.61us;
		dataIn <= '1';
		wait for 8.61us;
		dataIn <= '1';
		wait for 8.61us;
		dataIn <= '0';
		wait for 8.61us;
		dataIn <= '1';
		wait for 8.61us;
		dataIn <= '0';
		wait for 8.61us;
		dataIn <= '0';
		wait for 8.61us;
		dataIn <= '0';
		wait for 8.61us;
		dataIn <= '1';			--stop bit + idle
		wait for 100us;
		
		endsimulation <= true;
		wait;
	end process;
end architecture RTL;
