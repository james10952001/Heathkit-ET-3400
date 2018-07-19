----------------------------------------------------------------------------------
-- Engineer: Mike Field   <hamster@snap.net.nz>
-- 
-- Description:  Driver for the DealExteme display board, 
--  8 x 7 segs
--  8 x bi-colour LED
--  8 x buttons
--
-- Dependencies: None
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
-- Modifications by James Sweet
-- Remove BCD decoding and route digit segments to single 
-- 64 bit wide input. LEDs changed to active high.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_UNSIGNED.all;


entity tm1638 is
Port ( 	
		clk       		: in  std_logic;
		digits			: in	std_logic_vector(63 downto 0);
		leds_green_in	: in 	std_logic_vector(7 downto 0);
		leds_red_in		: in 	std_logic_vector(7 downto 0);

		d_strobe  		: out std_logic; -- outputs to drive the display
		d_clk     		: out std_logic;
		d_data 			: out std_logic
		);				
end tm1638;


architecture Behavioral of tm1638 is
signal counter    		: std_logic_vector(4 downto 0) := (others => '0');
signal nextcounter 		: unsigned(4 downto 0);
signal segData				: std_logic_vector(31 downto 0);
signal byte					: std_logic_vector(7 downto 0);
signal endcmd				: std_logic;
signal newData				: std_logic;
signal adv					: std_logic;

signal thisEndCmd     	: std_logic;
signal thisByte       	: std_logic_vector(7 downto 0)  := (others => '0');
signal bitsLeftToSend 	: std_logic_vector(6 downto 0)  := (others => '0');
signal state          	: std_logic_vector(2 downto 0)  := (others => '0');
signal divider        	: std_logic_vector(63 downto 0) := x"1000000000000000";

signal leds_green 		: std_logic_vector(7 downto 0);
signal leds_red			: std_logic_vector(7 downto 0);
signal reset				: std_logic;
signal reset_count 		: std_logic_vector(15 downto 0);
	
begin
nextcounter <= unsigned(counter) + 1;

leds_green <= leds_green_in;
leds_red <= leds_red_in;

	
data_proc: process(counter,segData, digits, leds_green, leds_red)
begin
	case counter is
		when  "00000" => byte <= x"40"; endCmd <= '1'; newData <= '1';   -- Set address mode - auto inc
		when  "00001" => byte <= x"8C"; endCmd <= '1'; newData <= '1';   -- Turn display on, brightness 4 of 7
		when  "00010" => byte <= x"C0"; endCmd <= '0'; newData <= '1';   -- Write at the left display
		when  "00011" => byte <= digits(63 downto 56); endCmd <= '0'; newData <= '1';
		when  "00100" => -- LED1 
			byte    <= "000000" & leds_red(0) & leds_green(0); 
			endCmd  <= '0'; 
			newData <= '1'; 
			
		when  "00101" => byte <= digits(55 downto 48); endCmd <= '0'; newData <= '1';   
		when  "00110" => -- LED2 
			byte    <= "000000" & leds_red(1) & leds_green(1); 
			endCmd  <= '0'; 
			newData <= '1'; 
			
		when  "00111" => byte <= digits(47 downto 40); endCmd <= '0'; newData <= '1';
		when  "01000" => -- LED3 red
			byte <= "000000" & leds_red(2) & leds_green(2); 
			endCmd <= '0'; 
			newData <= '1'; 
			
		when  "01001" => byte <= digits(39 downto 32); endCmd <= '0'; newData <= '1';
		when  "01010" => -- LED4 green
			byte <= "000000" & leds_red(3) & leds_green(3); 
			endCmd <= '0'; 
			newData <= '1'; 
			
		when  "01011" => byte <= digits(31 downto 24); endCmd <= '0'; newData <= '1';
		when  "01100" => -- LED5
			byte <= "000000" & leds_red(4) & leds_green(4); 
			endCmd <= '0'; 
			newData <= '1'; 
			
		when  "01101" => byte <= digits(23 downto 16); endCmd <= '0'; newData <= '1';
		when  "01110" => -- LED6 
			byte <= "000000" & leds_red(5) & leds_green(5); 
			endCmd <= '0'; 
			newData <= '1';   
 
		when  "01111" => byte <= digits(15 downto 8); endCmd <= '0'; newData <= '1';
		when  "10000" => -- led 7
			byte <= "000000" & leds_red(6) & leds_green(6); 
			endCmd <= '0'; 
			newData <= '1';
				
		when  "10001" =>  byte <= digits(7 downto 0); endCmd <= '0'; newData <= '1';   
		when  "10010" => -- led 8
			byte <= "000000" & leds_red(7) & leds_green(7); 
			endCmd <= '1'; 
			newData <= '1';
			
		when  others => byte <= x"FF"; endCmd <= '1'; newData <= '0';  -- End of data / idle
		
	end case;
end process;
	
	
txmt_proc: process(clk)
begin
	if rising_edge(clk) then
		divider <= divider(0) & divider(63 downto 1);
		adv      <= '0';
		
		if reset = '1'  then
			thisByte   <= (others => '0');
			thisEndCmd <= endCmd;
			state      <= (others => '0');
			d_strobe <= '1';
			d_clk    <= '1';
			d_data   <= '1';
			divider  <= x"1000000000000000";
		elsif divider(0) = '1' then
			d_strobe <= '1';
			d_clk    <= '1';
			d_data   <= '1';
			case state is 
				when "000" =>      -- Idle, without an open command
					if newData = '1' then
						state    <= std_logic_vector(unsigned(state)+1);
						thisByte <= byte;
						thisEndCmd <= endCmd;
						adv       <= '1';

						d_strobe <= '0';
						d_clk    <= '1';
						d_data   <= '1';
					else
						d_strobe <= '1';
						d_clk    <= '1';
						d_data   <= '1';
					end if;
					bitsLeftToSend <= (others => '1');
					
				when "001" =>   -- transfer a bot
					state    <= std_logic_vector(unsigned(state)+1);
					d_strobe <= '0';
					d_clk    <= '0';
					d_data   <= thisByte(0);
				when "010" =>
					if bitsLeftToSend(0) = '1' then -- Still got a bit to send?
						state    <= std_logic_vector(unsigned(state)-1);
					elsif thisEndCmd = '1' then
						state    <= "011";   -- close off command
					else
						state    <= "100";   -- keep command open
					end if;
					d_strobe <= '0';
					d_clk    <= '1';
					d_data   <= thisByte(0);
					thisByte <= '1' & thisByte(7 downto 1);
					bitsLeftToSend <= '0' & bitsLeftToSend(6 downto 1);
					
				when "011" => --- ending the command by rasing d_strobe, the going back to idle state
					state    <= "000";
					d_strobe <= '1';
					d_clk    <= '1';
					d_data   <= thisByte(0);
					
				when "100" =>      -- Waiting for data, withan open command
					d_strobe <= '0';
					d_clk    <= '1';
					d_data   <= '1';
					if newData = '1' then
						state      <= "001"; -- start transfering bits
						thisByte   <= byte;
						thisEndCmd <= endCmd;
						adv       <= '1';
						bitsLeftToSend <= (others => '1');
					end if;
				
				when others =>      -- performa a reset
					thisByte <= (others => '0');
					state    <= (others => '0');
					d_strobe <= '1';
					d_clk    <= '1';
					d_data   <= '1';
			end case;
		end if;
	end if;
end process;	
	
	
clk_proc: process(clk)
begin
	if rising_edge(clk) then
		if reset = '1' then 
			counter <= (others => '0');
		elsif adv = '1' and counter /= "11111" then
			counter <= std_logic_vector(nextcounter);
		end if;
	end if;	
end process;

	
reset_proc: process(clk, reset_count)
begin	
	if rising_edge(clk) then	
		reset_count <= reset_count + '1';
	end if;
	reset <= reset_count(15);
end process;
	
end Behavioral;
