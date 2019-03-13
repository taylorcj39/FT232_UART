------------------------------------------------------------------------------
-- Title      : FT232R_UART
-- Project    : 
-------------------------------------------------------------------------------
-- File       : FT232R_UART.vhd
-- Author     : Chris Taylor
-- Company    : RHK Technology / Oakland University
-- Last update: 2017-01-03
-- Platform   : 
-------------------------------------------------------------------------------
-- Description: USB-UART controller for FT232R
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2016/12/29  1.0      Chris		Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FT232R_UART is
	Port (
		--FTDI-FT232R Interface
		clk			: in 	STD_LOGIC;							--logic clock
      clr			: in 	STD_LOGIC;							--clear signal
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
		--RX_FULL   : out std_logic;          				-- rx fifo full
		RX_WORDS  : out std_logic_vector(10 downto 0) 	-- number of elements in the rx fifo

	);
end FT232R_UART;

architecture RTL of FT232R_UART is

	--Altera synchronous FIFO IP component
	COMPONENT scfifo
		GENERIC (
			add_ram_output_register		: STRING;
			intended_device_family		: STRING;
			lpm_numwords					: NATURAL;
			lpm_showahead					: STRING;
			lpm_type							: STRING;
			lpm_width						: NATURAL;
			lpm_widthu						: NATURAL;
			overflow_checking				: STRING;
			underflow_checking			: STRING;
			use_eab							: STRING
		);
		
		PORT (
			clock	: IN STD_LOGIC;
			data	: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
			rdreq	: IN STD_LOGIC;
			sclr	: IN STD_LOGIC;
			wrreq	: IN STD_LOGIC;
			empty	: OUT STD_LOGIC;
			full	: OUT STD_LOGIC;
			q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
			usedw	: OUT STD_LOGIC_VECTOR (10 DOWNTO 0)
		);
	END COMPONENT;

	--Constants & Shared Signals
	constant bit_time : UNSIGNED(11 downto 0)		:= X"1B1";	--434 50MHz clk cycles = 8.68ms
	
	--RX Signals
	signal	RX_q					: STD_LOGIC_VECTOR(7 downto 0);	--Intermediate signal for char output
	signal	RX_DIN				: STD_LOGIC_VECTOR(7 downto 0);
	signal	comm_start			: STD_LOGIC;							--Flag for start of communication
	signal	RX_nxt				: STD_LOGIC;							--Flag for next bit to be shifted in
	signal	RX_bit_count		: UNSIGNED(3 downto 0);				--Counter for bits in char
	signal 	RX_baud_count 		: UNSIGNED(11 downto 0);			--counter for length of 1 bit					
	signal	RX_full				: STD_LOGIC;
	signal	RX_wrreq				: STD_LOGIC;
	
	--RX States
	type 		RX_state_type is (Wait_Start, Collect_StartBit, Collect, RX_Delay, Store, Check_Full);
	signal 	RX_state	: RX_state_type;
	
	--TX Signals
	signal	TX_q					: STD_LOGIC_VECTOR(7 downto 0);	--Intermediate signal for char from FIFO
	signal	TX_nxt				: STD_LOGIC;							--Flag for start of communication and when next bit is to be shifted in
	signal	TX_bit_count		: UNSIGNED(3 downto 0);				--Counter for bits in char
	signal 	TX_baud_count 		: UNSIGNED(11 downto 0);			--counter for length of 1 bit					
	signal	TX_empty				: STD_LOGIC;
	signal	TX_DOUT				: STD_LOGIC_VECTOR(7 downto 0);
	signal	TX_rdreq				: STD_LOGIC;
	
	--TX States
	type TX_state_type is (Check_Empty, Retrieve, Start_Bit, Shift, TX_Delay, Stop_Bit, Pop);
	signal	TX_state : TX_state_type;
	
	begin
	
	--RX Process-------------------------------------------------------------------------------
	--State Machine Process
	T1 : process(clk, clr, comm_start, RX_full)
	begin
	
	if clr = '1' then
		RX_state <= Wait_Start;
		RX_bit_count <= (others => '0');
		RX_baud_count <= (others => '0');
	elsif clk'event and clk = '1' then
		case RX_state is
			when Wait_Start =>						--Waits for low pulse of start bit to be recieved
				RX_baud_count <= (others => '0');
				if comm_start = '1' then
					RX_state <= Collect_StartBit;
				else
					RX_state <= Wait_Start;
				end if;
			when Collect_StartBit =>				--Absorbs time of start bit + .5 to align with center of each bit
				RX_baud_count <= RX_baud_count + 1;
				if RX_baud_count < ((bit_time*3)/2) - 1 then
					RX_state <= Collect_StartBit;
				else
					RX_baud_count <= (others => '0');
					RX_state <= Collect;
				end if;
			when RX_Delay =>								--Wait bit time to sample bit
				if RX_baud_count < bit_time then
					RX_state <= RX_Delay;
					RX_baud_count <= RX_baud_count + 1;
				elsif RX_bit_count < "1000"	then	--If < 8 bits are collected, move to Collect state
					RX_state <= Collect;
				else
					Rx_state <= Check_Full;				--If 8 bits are collected, move to Check_Full state
				end if;
			when Collect =>							--Shifts in additional bit to complete 1 char
				RX_baud_count <= (others => '0');
				RX_bit_count <= RX_bit_count +1;
				if RX_bit_count = "1000" then			--If 8 bits have been shifted in move to Store in FIFO state
					RX_state <= Store;
				else
					RX_state <= RX_Delay;					--If < 8 Bits have been shifted in, move to Delay to wait for more
				end if;
			when Check_Full =>						--Ensures that FIFO is not full before loading in another char
				RX_bit_count <= (others => '0');
				if RX_full = '1' then
					RX_state <= Check_Full;
				else
					RX_state <= Wait_Start;
				end if;
			when others =>
				null;
		end case;
	end if;
	end process;
	
	--Shift Registering Process
	S1 : process(clk, clr, RX_nxt, FSDI)
   begin
	--Shift left to right (7543210)
	if clr = '1' then
		RX_q <= (others => '0');
	elsif clk'event and clk = '1' and RX_nxt = '1' then
		RX_q(7) <= FSDI;
		RX_q(6 downto 0) <= RX_q(7 downto 1);
	end if;
   end process;
   
	--Combinational assignments performed here 	
	RX_DIN <= RX_q;
	comm_start <= '1' when RX_bit_count = "0000" and FSDI = '0' else '0';
	RX_nxt <= '1' when RX_state = Collect and RX_bit_count < "1000" else '0';
	RX_wrreq <= '1' when RX_state = Check_Full and RX_full = '0' else '0';
	-------------------------------------------------------------------------------
	
	--TX Process-------------------------------------------------------------------------------
	--State Machine Process
	T2 : process(clk, clr, TX_empty)
	begin
	
	if clr = '1' then
		TX_state <= Check_Empty;
		TX_bit_count <= (others => '0'); 
		TX_baud_count <= (others => '0');
	elsif clk'event and clk = '1' then
		case TX_state is
			when Check_Empty =>						--Checks/Waits for FIFO to not be empty
				TX_baud_count <= (others => '0');
				if TX_empty = '1' then
					TX_state <= Check_Empty;
				else
					TX_state <= Retrieve;
				end if;
			when Retrieve =>							--Store char from FIFO in register
				TX_state <= Pop;
			when Pop =>
				TX_state <= Start_Bit;
			when Start_Bit =>							--Time of Start-Bit
				TX_baud_count <= TX_baud_count + 1;
				if TX_baud_count < bit_time then
					TX_state <= Start_Bit;
				else
					TX_baud_count <= (others => '0');
					TX_state <= TX_Delay;
				end if;
			when TX_Delay =>
				TX_baud_count <= TX_baud_count + 1;
				if TX_baud_count <= bit_time then
					TX_state <= TX_Delay;
				else
					if TX_bit_count = "1000" then			--If 8 bits have been shifted in move to Stop_Bit
						TX_state <= Stop_Bit;
					else
						TX_state <= Shift;				--If < 8 Bits have been shifted in, move back to shifting in another bit
					end if;
				end if;
			when Shift =>								--Shifts in additional bit from Q register to complete 1 char
				TX_baud_count <= (others => '0');
				TX_bit_count <= TX_bit_count + 1;
				TX_state <= TX_Delay;	
			when Stop_Bit =>							--Time of Start-Bit
				TX_baud_count <= TX_baud_count + 1;
				TX_bit_count <= (others => '0');
				--data <= '1'; seperate because this is registered
				if TX_baud_count < bit_time then
					TX_state <= Stop_Bit;
				else
					TX_baud_count <= (others => '0');
					TX_state <= Check_Empty;
				end if;
			when others =>
				null;
		end case;
	end if;
	end process;
	
	--Shift Registering Process
	S2 : process(clk, clr, TX_nxt, TX_state)
   begin
		--Shift left to right (7543210)
		if clr = '1' then
			TX_q <= (others => '0');
		elsif clk'event and clk = '1' then
			if TX_state = Retrieve then
				TX_q <= TX_DOUT;
			elsif TX_nxt = '1' then
				TX_q(7) <= '1';	--I dont think it matters what I shift in, but 1 is idle so Im shifting that in
				TX_q(6 downto 0) <= TX_q(7 downto 1);
			end if;
		end if;
   end process;
   
	--Combinational assignments performed here 
	FSDO <= TX_q(0) when TX_state = Shift or TX_state = TX_Delay else
					'0' when TX_state = Start_Bit else '1';
	TX_nxt <= '1' when TX_state = Shift and TX_bit_count < "1000" else '0';
	TX_rdreq <= '1' when TX_state = Pop and TX_empty = '0' else '0';
	-------------------------------------------------------------------------------
	
	--Instantiation and Port map of FIFOs
	RX_FIFO : scfifo
		generic map(
			add_ram_output_register => "OFF",
			intended_device_family  => "Cyclone V",
			lpm_numwords            => 2048,
			lpm_showahead           => "ON",
			lpm_type                => "scfifo",
			lpm_width               => 8,
			lpm_widthu              => 11,
			overflow_checking       => "OFF",
			underflow_checking      => "ON",
			use_eab                 => "ON"
		 )
		 port map(
			sclr  => clr,
			clock => clk,
			data  => RX_DIN,
			rdreq => RX_RD,
			wrreq => RX_wrreq,
			empty => RX_empty,
			full  => RX_FULL,
			q     => RX_DOUT,
			usedw => RX_WORDS
		 );
		 
	 TX_FIFO : scfifo
		generic map(
			add_ram_output_register => "OFF",
			intended_device_family  => "Cyclone V",
			lpm_numwords            => 2048,
			lpm_showahead           => "ON",
			lpm_type                => "scfifo",
			lpm_width               => 8,
			lpm_widthu              => 11,
			overflow_checking       => "OFF",
			underflow_checking      => "ON",
			use_eab                 => "ON"
		 )
		 port map(
			sclr  => clr,
			clock => clk,
			data  => TX_DIN,
			rdreq => TX_rdreq,
			wrreq => TX_WR,
			empty => TX_empty,
			full  => TX_FULL,
			q     => TX_DOUT,
			usedw => TX_WORDS
		 );
end architecture RTL;