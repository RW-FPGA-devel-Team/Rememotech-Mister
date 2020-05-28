--
-- ps2_kbd.vhd - Field scan-codes from PS/2 keyboard
--
-- This is a purely passive implementation.
-- ie: the keyboard drives the communication.
--
-- PS2_CLK runs at 10-16.7 KHz (ie: 60us-100us)
-- We sample at 1 MHz (1us) so as to deglitch it.
--
-- In the scancodes, x"e0" or x"e1" is a prefix for a an extended key,
-- and x"f0" is a prefix for a key release (rather than a press).
--
-- We return the press/release status as a bit,
-- and extended keys have bit 8 set in their key_code.
--
-- References
--   http://www.computer-engineering.org/ps2protocol/
--   http://en.wikipedia.org/wiki/Scancode
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ps2_kbd is
  port
    (
    -- our sampling clock
    clk_1mhz   : in std_logic;
    -- bit level interface from PS/2 socket
    PS2_CLK    : in std_logic;
    PS2_DAT    : in std_logic;
    -- key-code interface
    key_ready  : out std_logic;
    key_stroke : out std_logic; -- 0=>press, 1=>release
    key_code   : out std_logic_vector(9 downto 0)
    );
end ps2_kbd;

architecture behavior of ps2_kbd is

  signal clk_history  : std_logic_vector(9 downto 0) := "0000000000";
  signal clk          : std_logic; -- deglitched and slightly delayed clock

  signal n_bits       : std_logic_vector(3 downto 0) := "0000";
  signal scan         : std_logic_vector(7 downto 0);

  signal ready        : std_logic := '0';
  signal extended     : std_logic_vector(1 downto 0) := "00";
  signal stroke       : std_logic := '0';

begin

  -- hide clock glitches shorter than 10us
  process ( clk_1mhz )
  begin
    if rising_edge(clk_1mhz) then
      key_ready <= '0';
      if clk_history = "0000000000" then
        clk <= '0';
      elsif clk_history = "1111111111" then

        if clk = '0' then
          -- deserialise scan codes
          if n_bits = "0000" then
            if PS2_DAT = '0' then
              -- start bit
              n_bits <= "0001";
              -- if we previous exposed a key code, reset
              if ready = '1' then
                ready    <= '0';
                extended <= "00";
                stroke   <= '0';
              end if;
            end if;
          elsif n_bits = "1001" then
            -- had start bit, 8 data bits
            if ( scan(0) xor scan(1) xor scan(2) xor scan(3) xor
                 scan(4) xor scan(5) xor scan(6) xor scan(7) ) = not PS2_DAT then
              -- parity is ok
              n_bits <= "1010";
            else
              -- parity is not ok, start again
              n_bits <= "0000";
            end if;
          elsif n_bits = "1010" then
            -- had start bit, 8 data bits and parity
            if PS2_DAT = '1' then
              -- stop bit is ok

              -- collect scan codes into key codes
              if scan = x"e0" then
                extended(0) <= '1';
              elsif scan = x"e1" then
                extended(1) <= '1';
              elsif scan = x"f0" then
                stroke <= '1';
              else
                ready      <= '1';
                key_ready  <= '1';
                key_stroke <= stroke;
                key_code   <= extended & scan;
              end if;

            end if;
            -- start again
            n_bits <= "0000";
          else
            scan <= PS2_DAT & scan(7 downto 1);
            n_bits <= n_bits + 1;
          end if;
        end if;

        clk <= '1';
      else
        clk <= clk;
      end if;
      clk_history <= clk_history(8 downto 0) & PS2_CLK;
    end if;
  end process;

end behavior;
