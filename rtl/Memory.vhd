--
-- Memory.vhd - Single port RAM
--
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

entity Memory is
  port
    (
    -- host read/write side
    clk_host  : in  std_logic;

    addr_host : in  std_logic_vector(17 downto 0);
    d_host    : in  std_logic_vector(15 downto 0);
    lb_host   : in  std_logic;	--TODO
    ub_host   : in  std_logic;	--TODO
    we_host   : in  std_logic;	-- Write Enable
    ce_host   : in  std_logic;	--TODO CLock Enable
    oe_host   : in  std_logic;	--TODO Output Enable
	 
    q_host    : out std_logic_vector(15 downto 0)

    );
end Memory;

architecture behavior of Memory is

  type mem_type is array (0 to 2**18-1) of std_logic_vector(15 downto 0);
--  type ram_type is array (0 to 2**18-1) of std_logic_vector(15 downto 0);
  signal mem : mem_type;

  -- Ensure Quartus II infers a single BIDIR_DUAL_PORT ALTSYNCRAM,
  -- rather than a pair of DUAL_PORT ALTSYNCRAMs
  attribute ramstyle : string;
  attribute ramstyle of mem : signal is "no_rw_check";

begin

  process ( clk_host )
  begin
    if rising_edge(clk_host) then
      if we_host = '1' then
        mem(to_integer(unsigned(addr_host))) <= d_host;
      end if;
      q_host <= mem(to_integer(unsigned(addr_host)));
    end if;
  end process;

end behavior;
