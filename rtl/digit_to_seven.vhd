--
-- digit_to_seven.vhd - convert hex digit to seven segments
--
-- Output bits are set to 0 to light them
--
--   --0--
--  |     |
--  5     1
--  |     |
--   --6--
--  |     |
--  4     2
--  |     |
--   --3--
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity digit_to_seven is
  port
    (
    digit : in  std_logic_vector(3 downto 0);
    seven : out std_logic_vector(6 downto 0)
    );
end digit_to_seven;

architecture behavior of digit_to_seven is

begin

  process ( digit )
  begin
    case digit is
      when "0000" => seven <= "1000000";
      when "0001" => seven <= "1111001";
      when "0010" => seven <= "0100100";
      when "0011" => seven <= "0110000";
      when "0100" => seven <= "0011001";
      when "0101" => seven <= "0010010";
      when "0110" => seven <= "0000010";
      when "0111" => seven <= "1111000";
      when "1000" => seven <= "0000000";
      when "1001" => seven <= "0010000";
      when "1010" => seven <= "0001000";
      when "1011" => seven <= "0000011";
      when "1100" => seven <= "1000110";
      when "1101" => seven <= "0100001";
      when "1110" => seven <= "0000110";
      when "1111" => seven <= "0001110";
      when others => seven <= "1111111"; -- all off
    end case;
  end process;

end behavior;
