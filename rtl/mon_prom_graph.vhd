--
-- mon_prom_graph.vhd - Graph character generator
--
-- This is the 80 column character set.
-- We avoid storing the data, and compute it instead.
-- We implement the same kind of interface as a memory based implementation.
-- This should avoid using 2.5KB of memory.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mon_prom_graph is
  port
    (
    clk  : in  std_logic;
    addr : in  std_logic_vector(11 downto 0);
    q    : out std_logic_vector(7 downto 0)
    );
end mon_prom_graph;

architecture behavior of mon_prom_graph is
begin

  process ( clk )
  begin
    if rising_edge(clk) then
      case addr(11 downto 8) is
        when "0000" | "0001" | "0010" =>
          q <= addr(0)&addr(0)&addr(0)&addr(0) & addr(1)&addr(1)&addr(1)&addr(1);
        when "0011" | "0100" =>
          q <= addr(2)&addr(2)&addr(2)&addr(2) & addr(3)&addr(3)&addr(3)&addr(3);
        when "0101" | "0110" =>
          q <= addr(4)&addr(4)&addr(4)&addr(4) & addr(5)&addr(5)&addr(5)&addr(5);
        when "0111" | "1000" | "1001" =>
          q <= addr(6)&addr(6)&addr(6)&addr(6) & addr(7)&addr(7)&addr(7)&addr(7);
        when others =>
          q <= "XXXXXXXX"; -- won't happen
      end case;
    end if;
  end process;

end behavior;
