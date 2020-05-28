--
-- vdp_palette.vhd - VDP Palette
--
-- Transparent maps to black.
--
-- References
--   http://users.stargate.net/~drushel/pub/coleco/twwmca/wk970202.html 
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vdp_palette is
  port
    (
    -- the VDP colour
    colour : in  std_logic_vector(3 downto 0);
    -- which palette to use
    hw_pal : in  std_logic;
    -- the resulting output VGA colour values
    r      : out std_logic_vector(3 downto 0);
    g      : out std_logic_vector(3 downto 0);
    b      : out std_logic_vector(3 downto 0)
    );
end vdp_palette;

architecture behavior of vdp_palette is

begin

  process ( colour, hw_pal )
  begin
    if hw_pal = '1' then
      -- richer palette said to align with the hardware
      case colour is
        when "0000" => r <= "0000"; g <= "0000"; b <= "0000"; -- transparent
        when "0001" => r <= "0000"; g <= "0000"; b <= "0000"; -- black
        when "0010" => r <= "0010"; g <= "1100"; b <= "0010"; -- medium green
        when "0011" => r <= "0110"; g <= "1100"; b <= "0110"; -- light green
        when "0100" => r <= "0010"; g <= "0010"; b <= "1110"; -- dark blue
        when "0101" => r <= "0100"; g <= "0110"; b <= "1110"; -- light blue
        when "0110" => r <= "1010"; g <= "0010"; b <= "0010"; -- dark red
        when "0111" => r <= "0100"; g <= "1100"; b <= "1110"; -- cyan
        when "1000" => r <= "1110"; g <= "0010"; b <= "0010"; -- medium red
        when "1001" => r <= "1110"; g <= "0110"; b <= "0110"; -- light red
        when "1010" => r <= "1100"; g <= "1100"; b <= "0010"; -- dark yellow
        when "1011" => r <= "1100"; g <= "1100"; b <= "1000"; -- light yellow
        when "1100" => r <= "0010"; g <= "1000"; b <= "0010"; -- dark green
        when "1101" => r <= "1100"; g <= "0100"; b <= "1010"; -- magenta
        when "1110" => r <= "1010"; g <= "1010"; b <= "1010"; -- grey
        when "1111" => r <= "1110"; g <= "1110"; b <= "1110"; -- white
        when others => r <= "0000"; g <= "0000"; b <= "0000"; -- black
      end case;
    else
      -- these look realistic and reflect what I remember
      case colour is
        when "0000" => r <= "0000"; g <= "0000"; b <= "0000"; -- transparent
        when "0001" => r <= "0000"; g <= "0000"; b <= "0000"; -- black
        when "0010" => r <= "0100"; g <= "1011"; b <= "0011"; -- medium green
        when "0011" => r <= "0111"; g <= "1100"; b <= "0110"; -- light green
        when "0100" => r <= "0101"; g <= "0100"; b <= "1111"; -- dark blue
        when "0101" => r <= "1000"; g <= "0111"; b <= "1111"; -- light blue
        when "0110" => r <= "1011"; g <= "0110"; b <= "0100"; -- dark red
        when "0111" => r <= "0101"; g <= "1100"; b <= "1110"; -- cyan
        when "1000" => r <= "1101"; g <= "0110"; b <= "0100"; -- medium red
        when "1001" => r <= "1111"; g <= "1000"; b <= "0110"; -- light red
        when "1010" => r <= "1100"; g <= "1100"; b <= "0100"; -- dark yellow
        when "1011" => r <= "1101"; g <= "1101"; b <= "0111"; -- light yellow
        when "1100" => r <= "0011"; g <= "1001"; b <= "0010"; -- dark green
        when "1101" => r <= "1011"; g <= "0110"; b <= "1100"; -- magenta
        when "1110" => r <= "1100"; g <= "1100"; b <= "1100"; -- grey
        when "1111" => r <= "1111"; g <= "1111"; b <= "1111"; -- white
        when others => r <= "0000"; g <= "0000"; b <= "0000"; -- black
      end case;
    end if;
  end process;

end behavior;
