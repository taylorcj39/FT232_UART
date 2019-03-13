-- Last update: 2016-12-26
-- Platform   : 
-------------------------------------------------------------------------------
-- Description: Top file for testing the Rx-TX echoing USB-UART controller
--					 Uses 1 FIFO for both TX and RX
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2016/12/22  1.0      Chris		Created
-------------------------------------------------------------------------------



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity echo_top is
	Port (
		clk 			: in 	STD_LOGIC;							--logic clock
      clr 			: in 	STD_LOGIC;							--clear signal
		dataIn		: in  STD_LOGIC;							--data from FTDI Chip
		dataOut		: out STD_LOGIC;							--data to FTDI Chip
		words			: out	STD_LOGIC_VECTOR(10 downto 0)	--Number of words stroed in FIFO
	);
end echo_top;

architecture RTL of echo_top is
	component TX
	Port (
		clk 			: in 	STD_LOGIC;							--logic clock
      clr 			: in 	STD_LOGIC;							--clear signal
		char			: in	STD_LOGIC_VECTOR(7 downto 0);	--Char from FIFO
		empty			: in	STD_Logic;							--Flag from FIFO signifying empty 
		rdreq			: out STD_LOGIC;							--Enables reading from the FIFO
		data			: out	STD_LOGIC							--Synchonous output to FTDI chip
	);
	end component;

	component RX
	Port (
		data			: in	STD_LOGIC;							--Synchonous input from FTDI chip
		clk 			: in 	STD_LOGIC;							--logic clock
      clr 			: in 	STD_LOGIC;							--clear signal
		full 			: in	STD_LOGIC;							--Signifies RX_FIFO is full
		wreq			: out STD_LOGIC;							--Enables writing to RX_FIFO
		char			: out	STD_LOGIC_VECTOR(7 downto 0)	--Flag signifying register of next bit of char
	);
	end component;
	
	component RX_FIFO
	PORT(
		clock		: IN STD_LOGIC;
		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		rdreq		: IN STD_LOGIC;
		sclr		: IN STD_LOGIC;
		wrreq		: IN STD_LOGIC;
		empty		: OUT STD_LOGIC;
		full		: OUT STD_LOGIC;
		q			: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		usedw		: OUT STD_LOGIC_VECTOR (10 DOWNTO 0)
	);
	end component;
	
	--Intermediate signals
	signal charIn, charOut : STD_LOGIC_VECTOR(7 downto 0);
	signal rdreq, wrreq, empty, full : STD_LOGIC;
	begin

	T : TX port map (
		clk 	=> clk,
		clr 	=> clr,
		char	=> charOut,
		empty	=> empty,
		rdreq	=> rdreq,
		data	=> dataOut
	);

	R : RX port map (
		data	=> dataIn,
	   clk 	=> clk,
	   clr 	=> clr,
	   full 	=> full,
	   wreq	=> wrreq,
	   char	=> charIn
	);
	
	FIFO : RX_FIFO port map (
		clock			=> clk,	
	   data			=> charIn,
	   rdreq			=> rdreq,
	   sclr			=> clr,
	   wrreq			=> wrreq,
	   empty			=> empty,
		full			=> full,
      q				=> charOut,
      usedw			=> words
	);
	
end architecture RTL;