-- Driver for MAX7219 with 8 digit 7-segment display
-- sjm 15 May 2017
-- Modified to remove hex to 7-segment decoding by James Sweet
-- Added reset input to initialize display when system is reset

library ieee;
use ieee.std_logic_1164.all;

entity M7219 is
    port (
      clk : in std_logic;
      rst_n : in std_logic;
      parallel : in std_logic_vector(63 downto 0);
      clk_out : out std_logic;
      data_out : out std_logic;
      load : out std_logic
    );
end entity;

architecture rtl of M7219 is

attribute syn_encoding : string;

type state_machine is (init_1, init_2, init_3, init_4, read_data, dig_7, dig_6, dig_5, dig_4, dig_3, dig_2, dig_1, dig_0);
attribute syn_encoding of state_machine : type is "safe";
signal state : state_machine := init_1;

type driver_machine is (idle, start, clk_data, clk_high, clk_low, finished);
attribute syn_encoding of driver_machine : type is "safe";
signal driver_state : driver_machine := idle;

signal command : std_logic_vector(15 downto 0) := x"0000";
signal driver_start : std_logic := '0';


begin
process(clk, rst_n)
variable counter : integer := 0;
variable clk_counter : integer := 0;
variable latch_in : std_logic_vector(63 downto 0) := x"0000000000000000";
variable dig0_data : std_logic_vector(7 downto 0) := x"00";
variable dig1_data : std_logic_vector(7 downto 0) := x"00";
variable dig2_data : std_logic_vector(7 downto 0) := x"00";
variable dig3_data : std_logic_vector(7 downto 0) := x"00";
variable dig4_data : std_logic_vector(7 downto 0) := x"00";
variable dig5_data : std_logic_vector(7 downto 0) := x"00";
variable dig6_data : std_logic_vector(7 downto 0) := x"00";
variable dig7_data : std_logic_vector(7 downto 0) := x"00";
 
begin
if rst_n = '0' then
	state <= init_1;
	command <= (others => '0');
	clk_out <= '0';
	data_out <= '0';
	load <= '0';
elsif rising_edge(clk) then
	case state is
		when init_1 =>
			if (driver_state = idle) then
				command <= x"0c01"; -- shutdown / normal operation
				driver_state <= start;
				state <= init_2;
			end if;
		when init_2 =>
			if (driver_state = idle) then
				command <= x"0900"; -- decode mode
				driver_state <= start;
				state <= init_3;
			end if;
	when init_3 =>
			if (driver_state = idle) then
				command <= x"0A55"; -- intensity (was 0A00)
				driver_state <= start;
				state <= init_4;
			end if;
	when init_4 =>
			if (driver_state = idle) then
				command <= x"0B07"; -- scan limit
				driver_state <= start;
				state <= read_data;
			end if;
	when read_data =>
				latch_in := parallel;
				dig7_data := latch_in(63 downto 56);
				dig6_data := latch_in(55 downto 48);
				dig5_data := latch_in(47 downto 40);
				dig4_data := latch_in(39 downto 32);
				dig3_data := latch_in(31 downto 24);
				dig2_data := latch_in(23 downto 16);
				dig1_data := latch_in(15 downto 8);
				dig0_data := latch_in(7 downto 0);
				state <= dig_7;
	when dig_7 =>
			if (driver_state = idle) then
				command <= x"08" & dig7_data; 
				driver_state <= start;
				state <= dig_6;
			end if;
	when dig_6 =>
			if (driver_state = idle) then
				command <= x"07" & dig6_data; 
				driver_state <= start;
				state <= dig_5;
			end if;
	when dig_5 =>
			if (driver_state = idle) then
				command <= x"06" & dig5_data; 
				driver_state <= start;
				state <= dig_4;
			end if;
	when dig_4 =>
			if (driver_state = idle) then
				command <= x"05" & dig4_data; 
				driver_state <= start;
				state <= dig_3;
			end if;
	when dig_3 =>
			if (driver_state = idle) then
				command <= x"04" & dig3_data; 
				driver_state <= start;
				state <= dig_2;
			end if;
	when dig_2 =>
			if (driver_state = idle) then
				command <= x"03" & dig2_data; 
				driver_state <= start;
				state <= dig_1;
			end if;
	when dig_1 =>
			if (driver_state = idle) then
				command <= x"02" & dig1_data; 
				driver_state <= start;
				state <= dig_0;
			end if;
	when dig_0 =>
			if (driver_state = idle) then
				command <= x"01" & dig0_data; 
				driver_state <= start;
				state <= read_data;
			end if;
		when others => null;
	end case;

if (clk_counter < 100) then
	 clk_counter := clk_counter + 1;
else
	clk_counter := 0;
	case driver_state is
		when idle =>
			load <= '1';
			clk_out <= '0';
		when start =>
			load <= '0';
			counter := 16;
			driver_state <= clk_data;
		when clk_data =>
			counter := counter - 1;
			data_out <= command(counter);
			driver_state <= clk_high;
		when clk_high =>
			clk_out <= '1';
			driver_state <= clk_low;
		when clk_low =>
			clk_out <= '0';
			if (counter = 0) then
				load <= '1';
				driver_state <= finished;
			else
				driver_state <= clk_data;
			end if;
	when finished => 
			driver_state <= idle;
		when others => null;
	end case;
	end if; -- clk_counter
end if;
end process;

end architecture;

