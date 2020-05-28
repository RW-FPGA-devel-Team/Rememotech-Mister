--
-- sd_card.vhd - Access to SD card
--
-- I could use the CPU to bit-bash SPI to the SD card.
-- However, by implementing an 8-bit shift register, it gets done quicker.
--
-- We use the 50MHz clock as our master clock and on its rising edge we either
-- raise or lower the SPI clock, thus acheiving a highest speed of 25MHz.
-- Initially we need to clock the SPI at 0.4MHz, and can go to 25MHz later.
-- 25MHz/(62+1) = 0.4MHz approx, so divider needs to be 6 bits.
--
-- The send an x"ff" command allows the CPU to trigger the sending of the
-- x"ff" as a result of reading the previously returned response.
-- This allows block reads to go as fast as block writes.
--
-- Important: the process clocked on clk_50mhz that reads in bits can not be
-- sure that the newly arrived byte will be latched on the next cpu_clk.
-- Note that the CPU won't come and sample it that quickly anyway.
-- However, TimeQuest whinges about negative slack on setup, and I think that
-- Quartus's attempts to make the timings work here, breaks other timings.
-- By latching di in a process here, we somehow prevent this problem.
-- Some TimeQuest configuration of multi-cycles might also help.
--
-- References
--   http://en.wikipedia.org/wiki/Secure_Digital
--   http://en.wikipedia.org/wiki/Serial_Peripheral_Interface_Bus
--   http://arduino.cc/playground/Code/SDCARD  (careful, there are bugs)
--   http://www.chlazza.net/sdcardinfo.html
--   http://www.flashgenie.net/img/productmanualsdcardv2.2final.pdf
--   ftp://ftp.altera.com/up/pub/Altera_Material/11.0/Laboratory_Exercises/Embedded_Systems/DE1/embed_lab9.pdf
--
-- For Quartus DE1 SD_DAT v nCEO Pin_W20 conflict problem
--   http://alterauserforums.org/forum/showthread.php?p=126655
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sd_card_De1 is
  port
    (
    -- a nice fast clock
    clk_50mhz : in std_logic;
    reset     : in std_logic;
    divider   : in std_logic_vector(5 downto 0);
    -- bit level SPI interface to SD card
    SD_CLK    : out std_logic; -- clock, 0.4MHz initially, 25MHz later
    SD_CMD    : out std_logic; -- MOSI
    SD_DAT    : in  std_logic; -- MISO
    SD_DAT3   : out std_logic; -- chip select, active low
    -- byte interface to CPU
    clk_cpu   : in  std_logic;
    sel       : in  std_logic; -- select chip
    cmd       : in  std_logic; -- send command, as specified by do
    cmd_ff    : in  std_logic; -- send command, x"ff"
    do        : in  std_logic_vector(7 downto 0);
    ready     : out std_logic; -- command done, result in di
    di        : out std_logic_vector(7 downto 0)
    );
end sd_card_De1;

architecture behavior of sd_card_De1 is

  signal counter    : std_logic_vector(5 downto 0) := "000000";
  signal SD_CLK_int : std_logic := '0';
  signal se         : std_logic_vector(7 downto 0) := "00000000";
  signal so         : std_logic_vector(7 downto 0);
  signal si         : std_logic_vector(7 downto 0);

begin

  process ( clk_50mhz, reset )
  begin
    if reset = '1' then
      counter    <= "000000";
      SD_CLK_int <= '0';
      se         <= "00000000";
    elsif rising_edge(clk_50mhz) then
      SD_CLK_int <= SD_CLK_int;
      se         <= se;
      so         <= so;
      si         <= si;
      if cmd = '1' then
        -- CPU is telling us next output byte
        counter <= "000000";
        se <= "11111111"; -- shift out 8 bits
        so <= do;
      elsif cmd_ff = '1' then
        -- CPU is telling us next output x"ff"
        counter <= "000000";
        se <= "11111111"; -- shift out 8 bits
        so <= "11111111";
      elsif se(7) = '1' then
        -- more bits to do
        if counter = divider then
          counter <= "000000";
          if SD_CLK_int = '0' then
            -- outbound data is already valid
            -- raise clock, sample inbound
            SD_CLK_int     <= '1';
            si(7 downto 0) <= si(6 downto 0)&SD_DAT;
          else
            -- lower clock, select next outbound data bit
            SD_CLK_int     <= '0';
            so(7 downto 1) <= so(6 downto 0);
            se(7 downto 0) <= se(6 downto 0)&"0";
          end if;
        else
          counter <= counter+1;
        end if;
      end if;
    end if;
  end process;

  process ( clk_cpu )
  begin
    if rising_edge(clk_cpu) then
      ready <= not se(7);
      di    <= si;
    end if;
  end process;

  SD_DAT3 <= not sel;
  SD_CLK  <= SD_CLK_int;
  SD_CMD  <= so(7);

end behavior;
