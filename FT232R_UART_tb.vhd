------------------------------------------------------------------------------
-- Title      : FT232R_UART_tb
-- Project    : 
-------------------------------------------------------------------------------
-- File       : FT232R_UART_tb.vhd
-- Author     : Chris Taylor
-- Company    : RHK Technology / Oakland University
-- Last update: 2017-01-04
-- Platform   : 
-------------------------------------------------------------------------------
-- Description: Test Bench for USB-UART controller for FT232R
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2017/01/04  1.0      Chris		Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FT232R_UART_tb is
end FT232R_UART_tb;

architecture RTL of FT232R_UART_tb is

	component FT232R_UART
			Port (
				--FTDI-FT232R Interface
				clk 			: in 	STD_LOGIC;							--logic clock
				clr 			: in 	STD_LOGIC;							--clear signal
				FSDI			: in  STD_LOGIC;							--data from FTDI Chip
				FSDO			: out STD_LOGIC;							--data to FTDI Chip
				
				--Processor-TX_FIFO Interface
				TX_WR     : in  std_logic;          				-- intiate transmission of TX_DIN
				TX_DIN    : in  std_logic_vector(7 downto 0); 	-- data to transmit
				--TX_empty  : out std_logic;          				-- tx fifo empty
				TX_full   : out std_logic;          				-- tx fifo full
				TX_WORDS  : out std_logic_vector(10 downto 0); 	-- number of elements in the tx fifo

				--Processor-RX_FIFO Interface
				RX_RD     : in  std_logic;          				-- read data ( RX_DOUT has the data read in it on the same clock that read data is asserted )
				RX_DOUT   : out std_logic_vector(7 downto 0); 	-- data received
				RX_empty  : out std_logic;          				-- rx fifo empty
				--RX_full   : out std_logic;          				-- rx fifo full
				RX_WORDS  : out std_logic_vector(10 downto 0) 	-- number of elements in the rx fifo

			);
	end component;
	
	signal clk, clr : STD_LOGIC := '1';
	signal FSDI, FSDO, TX_WR, TX_full, RX_RD, RX_empty : STD_LOGIC;
	signal TX_WORDS, RX_WORDS : STD_LOGIC_VECTOR(10 downto 0);
	signal RX_DOUT, TX_DIN : STD_LOGIC_VECTOR(7 downto 0);
	signal endSimulation : boolean := false;
	
	begin
	
	
	UUT : FT232R_UART port map (
		clk 		=> clk, 		
		clr 		=> clr, 		
		FSDI		=> FSDI,		
		FSDO		=> FSDO,		
		TX_WR   	=> TX_WR,   
		TX_DIN  	=> TX_DIN,  
		TX_full 	=> TX_full, 
		TX_WORDS	=> TX_WORDS,
		RX_RD   	=> RX_RD,  
		RX_DOUT 	=> RX_DOUT, 
		RX_empty	=> RX_empty,
		RX_WORDS	=> RX_WORDS
	);
	
	--clock
	clk_proc: process
	begin
		if not endSimulation then
			clk <= not clk;
			wait for 10ns;
		else
			wait;
		end if;
	end process;
	
	stim_proc: process 
	begin
		RX_RD <= '0';	--Never pop off the RX_FIFO
		FSDI <= '1';
		TX_WR <= '0';
		TX_DIN <= (others => '1');
		
		wait for 20ns;
		clr <= '0';
		wait for 10us;
		
		--Send in 2 chars to RX, 0x55 then 0x15
		FSDI <= '0';			--start bit
		wait for 8.61us;
		FSDI <= '1';
		wait for 8.61us;
		FSDI <= '0';
		wait for 8.61us;
		FSDI <= '1';
		wait for 8.61us;
		FSDI <= '0';
		wait for 8.61us;
		FSDI <= '1';
		wait for 8.61us;
		FSDI <= '0';
		wait for 8.61us;
		FSDI <= '1';
		wait for 8.61us;
		FSDI <= '0';
		wait for 8.61us;
		FSDI <= '1';			--stop bit + idle
		wait for 50us;
		
		FSDI <= '0';			--start bit
		wait for 8.61us;
		FSDI <= '1';
		wait for 8.61us;
		FSDI <= '0';
		wait for 8.61us;
		FSDI <= '1';
		wait for 8.61us;
		FSDI <= '0';
		wait for 8.61us;
		FSDI <= '1';
		wait for 8.61us;
		FSDI <= '0';
		wait for 8.61us;
		FSDI <= '0';
		wait for 8.61us;
		FSDI <= '0';
		wait for 8.61us;
		FSDI <= '1';			--stop bit + idle
		wait for 50us;
		
		--Send in 2 chars to RX, 0x55 then 0x95
		TX_DIN <= X"55";
		TX_WR <= '1';
		wait for 20ns;
		TX_DIN <= X"95";
		TX_WR <= '0';
		wait for 200ns;
		TX_WR <= '1';
		wait for 20ns;
		TX_WR <= '0';
		wait for 200us;
		
		endSimulation <= true;
		wait;
	end process;
end architecture RTL;
