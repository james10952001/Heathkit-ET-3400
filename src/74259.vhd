-- 74259 8-bit addressable latch/demux
-- Unlike the original part, this one is synchronous, all changes occurring 
-- on the rising edge of the clock
-- (c) 2018 James Sweet
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


entity ls259 is
Port(	
	Clk	: instd_logic;				-- Synchronous clock
	A 	: in  std_logic_vector(2 downto 0);	-- Address input
      	D 	: in  std_logic;			-- Data input
      	E_n 	: in  std_logic;			-- Enable (active low)
      	C_n 	: in  std_logic;			-- Clear (active low)
      	Q_out	: out std_logic_vector(7 downto 0)	-- Output
	);
end ls259;

architecture rtl of ls259 is


begin

process(Clk, D, A, E_n, C_n)
begin
	if rising_edge(Clk) then
		if C_n = '0' then
			if E_n = '1' then	-- Clear mode
				Q_out <= (others => '0'); 
			else
				case A is	-- Demux mode
					when "000" => Q_out <= "00000001";
					when "001" => Q_out <= "00000010";
					when "010" => Q_out <= "00000100";
					when "011" => Q_out <= "00001000";
					when "100" => Q_out <= "00010000";
					when "101" => Q_out <= "00100000";
					when "110" => Q_out <= "01000000";
					when "111" => Q_out <= "10000000";
					when others => null;
				end case;
			end if;
		elsif E_n = '0' then -- Clear is high (inactive) and Enable is low (active)
				case A is		-- Addressable latch mode
					when "000" => Q_out(0) <= D;
					when "001" => Q_out(1) <= D;
					when "010" => Q_out(2) <= D;
					when "011" => Q_out(3) <= D;
					when "100" => Q_out(4) <= D;
					when "101" => Q_out(5) <= D;
					when "110" => Q_out(6) <= D;
					when "111" => Q_out(7) <= D;
					when others => null;
				end case;		
		else  -- "Memory" mode
			null;
		end if;
	end if;
end process;

end rtl;
