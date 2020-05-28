--
-- mon_cell.vhd - Cell memory, dual port RAM
--
-- This model allows read/write access on the host interface,
-- and read only access on the mon interface.
-- During a write, the data outputs show the old value. Doesn't matter.
--
-- This is a synchronous implementation, which seems to be necessary to
-- avoid Quartus using double the number of M4Ks (which are scarce).
-- To read, present addr, clk, read on next clk.
-- To write, present addr, we, data, clk.
--
-- 80x48 = 3840 cells, less than 4096 cells, ie: 8KB
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mon_cell is
  port
    (
    clk_host    : in  std_logic;
    d_host_atr  : in  std_logic_vector(7 downto 0);
    d_host_asc  : in  std_logic_vector(7 downto 0);
    addr_host   : in  std_logic_vector(11 downto 0);
    we_host_atr : in  std_logic;
    we_host_asc : in  std_logic;
    q_host_atr  : out std_logic_vector(7 downto 0);
    q_host_asc  : out std_logic_vector(7 downto 0);
    clk_mon     : in  std_logic;
    addr_mon    : in  std_logic_vector(11 downto 0);
    q_mon_atr   : out std_logic_vector(7 downto 0);
    q_mon_asc   : out std_logic_vector(7 downto 0)
    );
end mon_cell;

architecture behavior of mon_cell is

  type ram_type is array (0 to 2**12-1) of std_logic_vector(7 downto 0);
  signal atr : ram_type;
  signal asc : ram_type;

  -- Ensure Quartus II infers a single BIDIR_DUAL_PORT ALTSYNCRAM for each,
  -- rather than a pair of DUAL_PORT ALTSYNCRAMs for each
  attribute ramstyle : string;
  attribute ramstyle of atr : signal is "no_rw_check";
  attribute ramstyle of asc : signal is "no_rw_check";

begin

  process ( clk_host )
  begin
    if rising_edge(clk_host) then
      if we_host_atr = '1' then
        atr(to_integer(unsigned(addr_host))) <= d_host_atr;
      end if;
      if we_host_asc = '1' then
        asc(to_integer(unsigned(addr_host))) <= d_host_asc;
      end if;
      q_host_atr <= atr(to_integer(unsigned(addr_host)));
      q_host_asc <= asc(to_integer(unsigned(addr_host)));
    end if;
  end process;

  process ( clk_mon )
  begin
    if rising_edge(clk_mon) then
      q_mon_atr <= atr(to_integer(unsigned(addr_mon)));
      q_mon_asc <= asc(to_integer(unsigned(addr_mon)));
    end if;
  end process;

end behavior;
