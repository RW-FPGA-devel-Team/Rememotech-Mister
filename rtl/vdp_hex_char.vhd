--
-- vdp_hex_char.vhd - VDP hex digits for character
--
-- This VDP has a debug feature where instead of displaying pattern data
-- it can display the hex code of the character or sprite.
--
-- Builds a picture like this
--
--   ##....#.
--   ..#.#.#.
--   .#..###.
--   ..#...#.
--   ##....#.
--   ........
--   ###.....
--   ........

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vdp_hex_char is
  port
    (
    byte   : in  std_logic_vector(7 downto 0);
    scan   : in  std_logic_vector(2 downto 0);
    pixels : out std_logic_vector(7 downto 0)
    );
end vdp_hex_char;

architecture behavior of vdp_hex_char is

  component vdp_hex
    port
      (
      digit  : in  std_logic_vector(3 downto 0);
      scan   : in  std_logic_vector(2 downto 0);
      pixels : out std_logic_vector(2 downto 0)
      );
  end component;

  signal pixels_h : std_logic_vector(2 downto 0);
  signal pixels_l : std_logic_vector(2 downto 0);

begin

  U_HEX_H : vdp_hex
    port map (
      digit  => byte(7 downto 4),
      scan   => scan,
      pixels => pixels_h
      );

  U_HEX_L : vdp_hex
    port map (
      digit  => byte(3 downto 0),
      scan   => scan,
      pixels => pixels_l
      );

  pixels <= ( pixels_h & "0" & pixels_l & "0" )
            when ( scan /= "110" ) else "11100000";

end behavior;
