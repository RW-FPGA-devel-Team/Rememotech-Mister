--
-- vdp_hex.vhd - VDP hex digit
--
-- This VDP has a debug feature where instead of displaying pattern data
-- it can display the hex code of the character or sprite.
--
-- Builds a picture like this
--
--   ##.
--   ..#
--   .#.
--   ..#
--   ##.
--   ...
--   ...
--   ...
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vdp_hex is
  port
    (
    digit  : in  std_logic_vector(3 downto 0);
    scan   : in  std_logic_vector(2 downto 0);
    pixels : out std_logic_vector(2 downto 0)
    );
end vdp_hex;

architecture behavior of vdp_hex is

begin

  process ( digit, scan )
  begin
    case digit & scan is
      -- 0
      when "0000000" => pixels <= "111";
      when "0000001" => pixels <= "101";
      when "0000010" => pixels <= "101";
      when "0000011" => pixels <= "101";
      when "0000100" => pixels <= "111";
      -- 1
      when "0001000" => pixels <= "010";
      when "0001001" => pixels <= "110";
      when "0001010" => pixels <= "010";
      when "0001011" => pixels <= "010";
      when "0001100" => pixels <= "111";
      -- 2
      when "0010000" => pixels <= "110";
      when "0010001" => pixels <= "001";
      when "0010010" => pixels <= "010";
      when "0010011" => pixels <= "100";
      when "0010100" => pixels <= "111";
      -- 3
      when "0011000" => pixels <= "110";
      when "0011001" => pixels <= "001";
      when "0011010" => pixels <= "010";
      when "0011011" => pixels <= "001";
      when "0011100" => pixels <= "110";
      -- 4
      when "0100000" => pixels <= "001";
      when "0100001" => pixels <= "101";
      when "0100010" => pixels <= "111";
      when "0100011" => pixels <= "001";
      when "0100100" => pixels <= "001";
      -- 5
      when "0101000" => pixels <= "111";
      when "0101001" => pixels <= "100";
      when "0101010" => pixels <= "110";
      when "0101011" => pixels <= "001";
      when "0101100" => pixels <= "110";
      -- 6
      when "0110000" => pixels <= "011";
      when "0110001" => pixels <= "100";
      when "0110010" => pixels <= "110";
      when "0110011" => pixels <= "101";
      when "0110100" => pixels <= "010";
      -- 7
      when "0111000" => pixels <= "111";
      when "0111001" => pixels <= "001";
      when "0111010" => pixels <= "010";
      when "0111011" => pixels <= "010";
      when "0111100" => pixels <= "010";
      -- 8
      when "1000000" => pixels <= "010";
      when "1000001" => pixels <= "101";
      when "1000010" => pixels <= "010";
      when "1000011" => pixels <= "101";
      when "1000100" => pixels <= "010";
      -- 9
      when "1001000" => pixels <= "010";
      when "1001001" => pixels <= "101";
      when "1001010" => pixels <= "011";
      when "1001011" => pixels <= "001";
      when "1001100" => pixels <= "110";
      -- A
      when "1010000" => pixels <= "010";
      when "1010001" => pixels <= "101";
      when "1010010" => pixels <= "111";
      when "1010011" => pixels <= "101";
      when "1010100" => pixels <= "101";
      -- B
      when "1011000" => pixels <= "110";
      when "1011001" => pixels <= "101";
      when "1011010" => pixels <= "110";
      when "1011011" => pixels <= "101";
      when "1011100" => pixels <= "110";
      -- C
      when "1100000" => pixels <= "010";
      when "1100001" => pixels <= "101";
      when "1100010" => pixels <= "100";
      when "1100011" => pixels <= "101";
      when "1100100" => pixels <= "010";
      -- D
      when "1101000" => pixels <= "110";
      when "1101001" => pixels <= "101";
      when "1101010" => pixels <= "101";
      when "1101011" => pixels <= "101";
      when "1101100" => pixels <= "110";
      -- E
      when "1110000" => pixels <= "111";
      when "1110001" => pixels <= "100";
      when "1110010" => pixels <= "110";
      when "1110011" => pixels <= "100";
      when "1110100" => pixels <= "111";
      -- F
      when "1111000" => pixels <= "111";
      when "1111001" => pixels <= "100";
      when "1111010" => pixels <= "110";
      when "1111011" => pixels <= "100";
      when "1111100" => pixels <= "100";
      -- others
      when others    => pixels <= "000";
    end case;
  end process;

end behavior;
