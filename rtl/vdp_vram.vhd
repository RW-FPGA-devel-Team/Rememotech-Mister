--
-- vdp_vram.vhd - VDP VRAM, dual port RAM
--
-- This model allows read/write access on the host interface,
-- and read only access on the VDP interface.
-- During a write, the data outputs show the old value. Doesn't matter.
--
-- This is a synchronous implementation, which seems to be necessary to
-- avoid Quartus using double the number of M4Ks (which are scarce).
-- To read, present addr, clk, read on next clk.
-- To write, present addr, we, data, clk.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vdp_vram is
  port
    (
    -- host read/write side
    clk_host  : in  std_logic;
    d_host    : in  std_logic_vector(7 downto 0);
    addr_host : in  std_logic_vector(13 downto 0);
    we_host   : in  std_logic;
    q_host    : out std_logic_vector(7 downto 0);
    -- VDP read-only side
    clk_vdp   : in  std_logic;
    addr_vdp  : in  std_logic_vector(13 downto 0);
    q_vdp     : out std_logic_vector(7 downto 0)
    );
end vdp_vram;

architecture behavior of vdp_vram is

  type ram_type is array (0 to 2**14-1) of std_logic_vector(7 downto 0);
  signal r : ram_type;

  -- Ensure Quartus II infers a single BIDIR_DUAL_PORT ALTSYNCRAM,
  -- rather than a pair of DUAL_PORT ALTSYNCRAMs
  attribute ramstyle : string;
  attribute ramstyle of r : signal is "no_rw_check";

begin

  process ( clk_host )
  begin
    if rising_edge(clk_host) then
      if we_host = '1' then
        r(to_integer(unsigned(addr_host))) <= d_host;
      end if;
      q_host <= r(to_integer(unsigned(addr_host)));
    end if;
  end process;

  process ( clk_vdp )
  begin
    if rising_edge(clk_vdp) then
      q_vdp <= r(to_integer(unsigned(addr_vdp)));
    end if;
  end process;

end behavior;
