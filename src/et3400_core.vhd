-- Heathkit ET-3400 Microprocessor Trainer implemented in FPGA
-- This is a popular trainer from the late 1970s based on the 
-- Motorola 6800 microprocessor
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
use ieee.std_logic_arith.all;

entity et3400_core is
	port(
		Reset_n		: in 		std_logic;
		Clk_16M		: in 		std_logic;
		Phi2		: buffer 	std_logic;
		VMA_phi2_n	: buffer 	std_logic;
		Seg_test_n	: in		std_logic;
		Kb_row		: in 		std_logic_vector(5 downto 0);
		Kb_col		: out 		std_logic_vector(2 downto 0);
		Hex_H		: out 		std_logic_vector(7 downto 0);
		Hex_I		: out 		std_logic_vector(7 downto 0);
		Hex_N		: out		std_logic_vector(7 downto 0);
		Hex_Z 		: out		std_logic_vector(7 downto 0);
		Hex_V		: out 		std_logic_vector(7 downto 0);
		Hex_C		: out 		std_logic_vector(7 downto 0);
		IRQ_n		: in  		std_logic := '1';
		NMI_n		: in  		std_logic := '1';
		Hold_n		: in  		std_logic := '1';
		Halt_n		: in  		std_logic := '1';
		RW_n		: buffer	std_logic;
		CPU_addr	: buffer 	std_logic_vector(15 downto 0);
		DBus_in		: in		std_logic_vector(7 downto 0);
		CPU_Dout	: buffer	std_logic_vector(7 downto 0)
	);
end et3400_core;

architecture rtl of et3400_core is

signal cpu_vma					: std_logic;
signal cpu_hold					: std_logic;
signal cpu_halt					: std_logic;
signal cpu_irq					: std_logic;
signal cpu_nmi					: std_logic;
signal cpu_din					: std_logic_vector(7 downto 0);

signal rom_dout					: std_logic_vector(7 downto 0);
signal rom_cs					: std_logic;

signal ram1_ce					: std_logic := '0';
signal ram2_ce					: std_logic := '0';
signal ram1_wren			 	: std_logic := '0';
signal ram2_wren			 	: std_logic := '0';
signal ram1_dout				: std_logic_vector(7 downto 0);
signal ram2_dout				: std_logic_vector(7 downto 0);

signal kb_cs_n					: std_logic;

signal hexH_en					: std_logic;
signal hexI_en					: std_logic;
signal hexN_en					: std_logic;
signal hexZ_en					: std_logic;
signal hexV_en					: std_logic;
signal hexC_en					: std_logic;

signal clkdiv					: std_logic_vector(23 downto 0);
signal clk_500k					: std_logic;
signal phi1					: std_logic;
signal mem_phi2					: std_logic;

signal reset_h					: std_logic;
signal RnW					: std_logic;

	
begin

Reset_h <= (not Reset_n);

	
-- Divide the 16 MHz pll output down to 500 kHz CPU clock	
Clock_Divider: process(Clk_16M)
begin
	if rising_edge(Clk_16M) then
		clkdiv <= clkdiv + '1';
		Clk_500k <= clkdiv(4);
	end if;
end process;


-- Clock signals
Phi1 <= Clk_500k;
Phi2 <=  not  Clk_500k;
mem_phi2 <=  Clk_500k; -- This really should be phi2, need to look into this



-- Address decoding
-- The original Heathkit design used cascaded 7442 decoders combined with some glue logic.
-- Here it's easier to just model the behavior.

-- ROM enable
rom_cs <= 	'1' when vma_phi2_n = '0' and cpu_addr(15 downto 10) = "111111" else '0';

-- RAM enables 
ram1_ce <= 	'1' when vma_phi2_n = '0' and cpu_addr(15 downto 8) = "00000000" else '0';
ram2_ce <= 	'1' when vma_phi2_n = '0' and cpu_addr(15 downto 8) = "00000001" else '0';
ram1_wren <= '1' when RnW = '1' and ram1_ce = '1' else '0'; 
ram2_wren <= '1' when RnW = '1' and ram2_ce = '1' else '0';

-- Keyboard enable
kb_cs_n <= '0' when vma_phi2_n = '0' and cpu_addr(15 downto 8) = "11000000" else '1';

-- Enables for 7 segment hex displays
hexC_en <= '0' when vma_phi2_n = '0' and cpu_addr(15 downto 8) = "11000001" and cpu_addr(6 downto 4) = "001" else '1';
hexV_en <= '0' when vma_phi2_n = '0' and cpu_addr(15 downto 8) = "11000001" and cpu_addr(6 downto 4) = "010" else '1';
hexZ_en <= '0' when vma_phi2_n = '0' and cpu_addr(15 downto 8) = "11000001" and cpu_addr(6 downto 4) = "011" else '1';
hexN_en <= '0' when vma_phi2_n = '0' and cpu_addr(15 downto 8) = "11000001" and cpu_addr(6 downto 4) = "100" else '1';
hexI_en <= '0' when vma_phi2_n = '0' and cpu_addr(15 downto 8) = "11000001" and cpu_addr(6 downto 4) = "101" else '1';
hexH_en <= '0' when vma_phi2_n = '0' and cpu_addr(15 downto 8) = "11000001" and cpu_addr(6 downto 4) = "110" else '1';


-- VMA signal is associated with phase 2 clock
vma_phi2_n <= (cpu_vma nand mem_phi2);


-- Keyboard matrix columns are driven directly from address bus
kb_col <= cpu_addr(2 downto 0);

	
-- 6800 CPU
-- Note the CPU68 core is not cycle accurate at all
CPU: entity work.cpu68
port map(
	clk => Phi1,
	rst => Reset_h,
	rw => RW_n,
	vma => CPU_vma,
	address	=> CPU_addr,
	data_in	=> CPU_din,
	data_out => CPU_dout,
	hold => CPU_hold,
	halt =>	CPU_halt,
	irq => CPU_irq,
	nmi => CPU_nmi
	);

-- On a real 6800 these signals are active-low, CPU68 core uses active high for some reason	
CPU_hold <= not Hold_n;
CPU_halt <= not Halt_n;
CPU_nmi <= not NMI_n;
CPU_irq <= not IRQ_n;
	
RnW <= not RW_n;
	
-- 256 Byte RAM IC14-IC15
RAM1: entity work.ram_256b
port map(
	address => CPU_addr(7 downto 0),
	clock => Clk_16M,
	data => CPU_dout,
	wren => RAM1_wren, 
	q => RAM1_dout
	);

-- 256 Byte RAM IC16-IC17
RAM2: entity work.ram_256b
port map(
	address => CPU_addr(7 downto 0),
	clock => Clk_16M,
	data => CPU_dout,
	wren => RAM2_wren,
	q => RAM2_dout
	);
	
	
-- 1K ROM
ROM: entity work.ET3400_ROM
port map(
	address	=> CPU_addr(9 downto 0),
	clock => Clk_16M,
	q => ROM_dout
	);

	
-- LED display demux/latch drivers
HEXH_DEMUX: entity work.ls259
port map(
	Clk => Clk_16M,
	A => cpu_addr(2 downto 0),
	D => not cpu_dout(0),
	E_n => hexH_en,
	C_n => Seg_test_n,
	Q_out => hex_h
	);

HEXI_DEMUX: entity work.ls259
port map(
	Clk => Clk_16M,
	A => cpu_addr(2 downto 0),
	D => not cpu_dout(0),
	E_n => hexI_en,
	C_n => Seg_test_n,
	Q_out => hex_i
	);
	
HEXN_DEMUX: entity work.ls259
port map(
	Clk => Clk_16M,
	A => cpu_addr(2 downto 0),
	D => not cpu_dout(0),
	E_n => hexN_en,
	C_n => Seg_test_n,
	Q_out => hex_n
	);

HEXZ_DEMUX: entity work.ls259
port map(
	Clk => Clk_16M,
	A => cpu_addr(2 downto 0),
	D => not cpu_dout(0),
	E_n => hexZ_en,
	C_n => Seg_test_n,
	Q_out => hex_z
	);	

HEXV_DEMUX: entity work.ls259
port map(
	Clk => Clk_16M,
	A => cpu_addr(2 downto 0),
	D => not cpu_dout(0),
	E_n => hexV_en,
	C_n => Seg_test_n,
	Q_out => hex_v
	);
	
HEXC_DEMUX: entity work.ls259
port map(
	Clk => Clk_16M,
	A => cpu_addr(2 downto 0),
	D => not cpu_dout(0),
	E_n => hexC_en,
	C_n => Seg_test_n,
	Q_out => hex_c
	);
	
	
-- CPU data-in MUX	
cpu_din <= rom_dout when rom_cs = '1' else 
	   ram1_dout when ram1_ce = '1' else
	   ram2_dout when ram2_ce = '1' else
	   "00" & kb_row when kb_cs_n = '0' else
	   --DBus_in when ... -- Add address decoding logic if you want to use this for external peripherals
	   x"FF"; 	
	
end;
