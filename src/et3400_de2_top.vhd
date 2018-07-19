-- Heathkit ET-3400 Microprocessor Trainer implemented in FPGA
-- Top level file for Terasic DE2
-- (c) 2018 James Sweet
--
--	There remains a minor bug that causes occasional glitches in
-- the 7-segment display outputs. The CPU68 core is also not 
-- cycle-accurate, causing most programs to run too fast. Otherwise
-- this is working well and runs all example programs I have tried.
--
-- This is free software: you can redistribute
-- it and/or modify it under the terms of the GNU General
-- Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your
-- option) any later version.
--
-- This is distributed in the hope that it will
-- be useful, but WITHOUT ANY WARRANTY; without even the
-- implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE. See the GNU General Public License
-- for more details.

library ieee;
use ieee.std_logic_1164.all;
use  IEEE.STD_LOGIC_ARITH.all;
use  IEEE.STD_LOGIC_UNSIGNED.all;

entity et3400_de2 is
	port(
		Clk_50		: in 		std_logic;
		Key			: in 		std_logic_vector(3 downto 0);
		Switches		: in  	std_logic_vector(17 downto 0);
		PS2_Clk		: in  	std_logic;
		PS2_Dat		: in  	std_logic;
		
		Hex7			: out 	std_logic_vector(6 downto 0);
		Hex6			: out 	std_logic_vector(6 downto 0);
		Hex5			: out 	std_logic_vector(6 downto 0);
		Hex4			: out 	std_logic_vector(6 downto 0);
		Hex3			: out 	std_logic_vector(6 downto 0);
		Hex2			: out 	std_logic_vector(6 downto 0);
		Hex1			: out 	std_logic_vector(6 downto 0);
		Hex0			: out 	std_logic_vector(6 downto 0);

		LEDR			: out 	std_logic_vector(17 downto 0);
		LEDG			: out 	std_logic_vector(8 downto 0);
		
		GPIO_0		: inout	std_logic_vector(35 downto 0);
		GPIO_1		: inout	std_logic_vector(35 downto 0)
		
		-- The rest of the DE2 hardware really should be filled in here too
	);
end et3400_de2;


architecture rtl of et3400_de2 is

signal Clk_16M			: std_logic;
signal Phi2				: std_logic;
signal VMA_phi2_n		: std_logic;

signal Reset_n			: std_logic;
signal ResetButton_n	: std_logic;

signal Kb_row			: std_logic_vector(5 downto 0);
signal Kb_col			: std_logic_vector(2 downto 0);

signal Hex_H			: std_logic_vector(7 downto 0);
signal Hex_I			: std_logic_vector(7 downto 0);
signal Hex_N			: std_logic_vector(7 downto 0);
signal Hex_Z			: std_logic_vector(7 downto 0);
signal Hex_V			: std_logic_vector(7 downto 0);
signal Hex_C			: std_logic_vector(7 downto 0);

signal RW_n				: std_logic;
signal NMI_n			: std_logic := '1';
signal IRQ_n 			: std_logic := '1';
signal Hold_n			: std_logic	:= '1';
signal Halt_n			: std_logic := '1';
signal CPU_Addr		: std_logic_vector(15 downto 0);
signal CPU_Dout		: std_logic_vector(7 downto 0);
signal CPU_Din			: std_logic_vector(7 downto 0);

signal PS2_Sample    : std_logic;
signal PS2_Data_s    : std_logic;
signal ScanCode      : std_logic_vector(7 downto 0);
signal Press         : std_logic;
signal Release      	: std_logic;
signal Reset         : std_logic;
signal Tick1us       : std_logic;
signal PS2Key 			: std_logic_vector(16 downto 0);

signal Keypd_row		: std_logic_vector(5 downto 0);
signal Keypd_col		: std_logic_vector(2 downto 0);


begin

-- Disable unused hardware
-- Turn off the LEDs we don't need
LEDR(15) <= '0';
LEDR(12) <= '0';
LEDR(11) <= '0';
--LEDR(8 downto 0) <= (others => '0');
ledr(8 downto 0) <= (others => '0');

--LEDG <= (others => '0');
LEDG(8) <= '0';

-- The DE2 has 8 display digits but the ET-3400 only needs 6
-- These could be used for something else, otherwise just turn them off
Hex1 <= (others => '1');
Hex0 <= (others => '1');



------------ Breadboard -----------------------------------------------------

-- These signals are inputs to the CPU, if not used leave them tied high
NMI_n <= '1';
IRQ_n <= '1';
Hold_n <= '1';
Halt_n <= '1';
CPU_Din <= x"FF";


-- Sample experiment, this implements a very simple output port connected to LEDs
-- Write to memory location x0200 to control the LEDs
output: process(Clk_16M, VMA_phi2_n)
begin
	if rising_edge(Clk_16M) then
		if CPU_addr(15 downto 0) = x"0200" then
			if VMA_phi2_n = '0' and RW_n = '0' then
				LEDG(7 downto 0) <= CPU_Dout;
			end if;
		end if;
	end if;
end process;
				


-- There are a few more VHDL components included in the "misc" folder that you can
-- try interfacing here
				
				





------------------------------------------------------------------------------


ResetButton_n <= Key(0);


-- PLL generates 16 MHz clock from 50 MHz oscillator
PLL: entity work.clk_pll
port map(
	inclk0 => Clk_50,
	c0		 => Clk_16M
	);
	
	
-- Unused inputs tied high, unused outputs left open. Connect these
-- to signals if you wish to use them.
ET3400: entity work.et3400_core
port map(
	Reset_n => Reset_n,
	Clk_16M => Clk_16M,
	Phi2 => Phi2,
	VMA_phi2_n => VMA_phi2_n,
	Seg_test_n => Key(1),
	Kb_row => Kb_row,
	Kb_col => Kb_col,
	Hex_H => Hex_H,
	Hex_I => Hex_I,
	Hex_N => Hex_N,
	Hex_Z => Hex_Z,
	Hex_V => Hex_V,
	Hex_C => Hex_C,
	IRQ_n => IRQ_n,
	NMI_n => NMI_n,
	Hold_n => Hold_n,
	Halt_n => Halt_n,
	RW_n => RW_n,
	CPU_addr => CPU_Addr,
	DBus_in => CPU_Din,
	CPU_Dout => CPU_Dout
	);

-- The segment wiring is also backwards compared to the DE2 default signal names	
-- 6 downto 0, G downto A
Hex7 <= Hex_H(0) & Hex_H(1) & Hex_H(2) & Hex_H(3) & Hex_H(4) & Hex_H(5) & Hex_H(6);
Hex6 <= Hex_I(0) & Hex_I(1) & Hex_I(2) & Hex_I(3) & Hex_I(4) & Hex_I(5) & Hex_I(6);
Hex5 <= Hex_N(0) & Hex_N(1) & Hex_N(2) & Hex_N(3) & Hex_N(4) & Hex_N(5) & Hex_N(6);
Hex4 <= Hex_Z(0) & Hex_Z(1) & Hex_Z(2) & Hex_Z(3) & Hex_Z(4) & Hex_Z(5) & Hex_Z(6);
Hex3 <= Hex_V(0) & Hex_V(1) & Hex_V(2) & Hex_V(3) & Hex_V(4) & Hex_V(5) & Hex_V(6);
Hex2 <= Hex_C(0) & Hex_C(1) & Hex_C(2) & Hex_C(3) & Hex_C(4) & Hex_C(5) & Hex_C(6);


-- Unfortunately the decimal points on the DE2 displays are not physically wired up
-- We can use some of the red LEDs instead, or you can use an external display as 
-- done with the Cyclone II mini board.
LEDR(17) <= not Hex_H(7);
LEDR(16) <= not Hex_I(7);
LEDR(14) <= not Hex_N(7);
LEDR(13) <= not Hex_Z(7);
LEDR(10) <= not Hex_V(7);
LEDR(9) <= not Hex_C(7);



-- ET-3400 keypad layout:
-- Columns are driven by bottom 3 lines of address bus and pull
-- the corresponding row low when a key is pressed.
-- Reset key is wired separately and not part of the matrix.
--
--								Column:
-- 					0			1			2
--					 ------------------------
-- Row:		0	|	D			E			F
--					|
--				1	|	A			B			C
--					|
--				2	|	7			8			9
--					|
--				3	|	4			5			6
--					|
-- 			4	|	1			2			3
--					|
--				5	|	0
--					|


-- Reset button on DE2 or 'Del' key on PS2 keyboard resets ET-3400 
Reset_n <= ResetButton_n and PS2Key(16); 

-- Map other keys to keypad matrix
Kb_row(0) <= Keypd_row(0) and (Kb_col(0) or PS2Key(13)) and (Kb_col(1) or PS2Key(14)) and (Kb_col(2) or PS2Key(15));
Kb_row(1) <= Keypd_row(1) and (Kb_col(0) or PS2Key(10)) and (Kb_col(1) or PS2Key(11)) and (Kb_col(2) or PS2Key(12));
Kb_row(2) <= Keypd_row(2) and (Kb_col(0) or PS2Key(7)) and (Kb_col(1) or PS2Key(8)) and (Kb_col(2) or PS2Key(9));
Kb_row(3) <= Keypd_row(3) and (Kb_col(0) or PS2Key(4)) and (Kb_col(1) or PS2Key(5)) and (Kb_col(2) or PS2Key(6));
Kb_row(4) <= Keypd_row(4) and (Kb_col(0) or PS2Key(1)) and (Kb_col(1) or PS2Key(2)) and (Kb_col(2) or PS2Key(3));
Kb_row(5) <= Keypd_row(5) and (Kb_col(0) or PS2Key(0));

Keypd_col <= Kb_col;

-- Keypad matrix can also be connected to GPIO pins
GPIO_0(2 downto 0) <= Keypd_col;
Keypd_row <= GPIO_0(8 downto 3);


-- Keyboard decoder
keyboard : entity work.ps2kbd
port map(
	Rst_n => ResetButton_n,
	Clk => Clk_16M,
	Tick1us => Tick1us,
	PS2_Clk => PS2_Clk,
	PS2_Data => PS2_Dat,
	Press => Press,
	Release => Release,
	Reset => Reset,
	ScanCode => ScanCode
	);
	

process (Clk_16M, ResetButton_n)
begin
	if ResetButton_n = '0' then
		PS2Key <= (others => '1');
	elsif rising_edge(Clk_16M) then
		if (Press or Release) = '1' then
			if ScanCode = x"70" or ScanCode = x"45" then    -- 1
				PS2Key(0) <= not Press;
			end if;
			if ScanCode = x"69" or ScanCode = x"16" then    -- 1
				PS2Key(1) <= not Press;
			end if;
			if ScanCode = x"72" or ScanCode = x"1E" then    -- 2
				PS2Key(2) <= not Press;
			end if;
			if ScanCode = x"7A" or ScanCode = x"26" then    -- 3
				PS2Key(3) <= not Press;
			end if;
			if ScanCode = x"6B" or ScanCode = x"25" then    -- 4
				PS2Key(4) <= not Press;
			end if;
			if ScanCode = x"73" or ScanCode = x"2E" then    -- 5
				PS2Key(5) <= not Press;
			end if;
			if ScanCode = x"74" or ScanCode = x"36" then    -- 6
				PS2Key(6) <= not Press;
			end if;
			if ScanCode = x"6C" or ScanCode = x"3D" then    -- 7
				PS2Key(7) <= not Press;
			end if;
			if ScanCode = x"75" or ScanCode = x"3E" then    -- 8
				PS2Key(8) <= not Press;
			end if;
			if ScanCode = x"7D" or ScanCode = x"46" then    -- 9
				PS2Key(9) <= not Press;
			end if;
			if ScanCode = x"1C" then    -- A
				PS2Key(10) <= not Press;
			end if;
			if ScanCode = x"32" then    -- B
				PS2Key(11) <= not Press;
			end if;
			if ScanCode = x"21" then    -- C
				PS2Key(12) <= not Press;
			end if;
			if ScanCode = x"23" then    -- D
				PS2Key(13) <= not Press;
			end if;
			if ScanCode = x"24" then    -- E
				PS2Key(14) <= not Press;
			end if;
			if ScanCode = x"2B" then    -- F
				PS2Key(15) <= not Press;
			end if;	
			if ScanCode = x"71" then    -- Numpad 'Del', map to ET-3400 Reset key
				PS2Key(16) <= not Press;
			end if;			
		end if;
		if Reset = '1' then
			PS2Key <= (others => '1');
		end if;
	end if;
end process;

-- Glue
--
process (ResetButton_n, Clk_16M)
	variable cnt : unsigned(3 downto 0);
begin
	if ResetButton_n = '0' then
		cnt := "0000";
		Tick1us <= '0';
	elsif rising_edge(Clk_16M) then
		Tick1us <= '0';
		if cnt = 15 then
			Tick1us <= '1';
			cnt := "0000";
		else
			cnt := cnt + 1;
		end if;
	end if;
end process;
	
end rtl;