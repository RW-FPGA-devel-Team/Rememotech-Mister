--
-- memory_map.vhd - MTX Compatible Memory Map
--
-- Map memory map registers and Z80 address to chip enable,
-- write enable and physical address. 
--
-- Can exploit upto 16KB on-chip memory, 512KB SRAM, upto 4MB Flash.
-- This fits nicely in (and makes good use of) the Altera DE1 and DE2 boards.
-- Provides fixed 8KB ROM, 8x8KB ROM pages, 24x16KB=384KB RAM pages.
-- There is 512-8-64-384=56KB of SRAM not visible in the normal way.
--
-- The memory map also provides access to on-chip memory, read/write backdoors
-- to all of SRAM, and access to all of Flash.
-- Set iobyte to x"8f" on processor reset.
--
-- The largest amount of RAM ever seen in a MTX was 64+512=576KB.
-- Providing more is pointless, as there is no software to exploit it.
-- The largest this design could ever allow would be 64+13*48=688KB,
-- because we'd want to leave a gap between RAM and our magic RAM page 15.
-- In theory, the address space allows for 64+15*48=784KB.
--
-- SRAM is considered broken into 16KB pages
--   page 00000x has RAM page alpha
--   page 00001x has RAM page beta
--   page 00010x has RAM page gamma
--   page 00011x has RAM page delta
-- then into 8KB pages
--   page 001000 has ROM page 0
--   page 001001 has ROM page 1
--   page 001010 has ROM page 2
--   page 001011 has ROM page 3
--   page 001100 has ROM page 4
--   page 001101 has ROM page 5
--   page 001110 has ROM page 6
--   page 001111 has ROM page 7
--   page 010000 has fixed ROM
--   page 010001 is start of free space
--   ...
--   page 010111 is end of free space
-- then in 16KB pages
--   page 01100x has RAM page a
--   ...
--   page 11111x has RAM page t
--
-- Flash is 256 16KB pages
--
--   iobyte    page1     page2     addr      oe  se  fe  we  phys_addr             comment
--   --------  --------  --------  --------  --  --  --  --  --------------        ------------------
--   XXXXXXXX  XXXXXXXX  XXXXXXXX  11h       0   1   0   1   00001000h             RAM page alpha
--   0XXXXXXX  XXXXXXXX  XXXXXXXX  000       0   1   0   0   000001000             fixed ROM
--   0rrrXXXX  XXXXXXXX  XXXXXXXX  001       0   1   0   0   000000rrr             ROM pages
--   0XXXRRRR  XXXXXXXX  XXXXXXXX  01h..10h  0   1   0   1   00001001h..00011111h  RAM pages per p246
--   0XXXRRRR  XXXXXXXX  XXXXXXXX  01h..10h  0   0   0   0   XXXXXXXXX             beyond 432KB RAM
--   1XXXRRRR  XXXXXXXX  XXXXXXXX  00h..10h  0   1   0   1   00001001h..00011111h  RAM pages per p247
--   1XXXRRRR  XXXXXXXX  XXXXXXXX  00h..10h  0   0   0   0   XXXXXXXXX             beyond 432KB RAM
--   0XXX1110  pppppppp  XXXXXXXX  01h       0   1   0   1   pppppppph             SRAM backdoor
--   0XXX1110  XXXXXXXX  qqqqqqqq  10h       0   0   1   1   qqqqqqqqh             SRAM backdoor
--   0XXX1111  pppppppp  XXXXXXXX  01h       0   1   0   1   pppppppph             SRAM backdoor
--   0XXX1111  XXXXXXXX  qqqqqqqq  10h       0   0   1   1   qqqqqqqqh             Flash backdoor
--   1XXX1111  XXXXXXXX  XXXXXXXX  00h       1   0   0   1   00000000h             On chip memory
--   1XXX1111  pppppppp  XXXXXXXX  01h       0   1   0   1   pppppppph             SRAM backdoor
--   1XXX1111  XXXXXXXX  qqqqqqqq  10h       0   0   1   1   qqqqqqqqh             Flash backdoor
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity memory_map is
  port
    (
    iobyte    : in  std_logic_vector(7 downto 0);   -- IOBYTE
    page1     : in  std_logic_vector(7 downto 0);   -- Page register 1
    page2     : in  std_logic_vector(7 downto 0);   -- Page register 2
    addr      : in  std_logic_vector(15 downto 13); -- Top bits of Z80 address
    erom      : in  std_logic;                      -- There is external EEPROM
    oe        : out std_logic;                      -- On-chip memory enable
    se        : out std_logic;                      -- SRAM enable
    fe        : out std_logic;                      -- Flash enable
    ere       : out std_logic;                      -- External EEPROM enable
    we        : out std_logic;                      -- Write enable
    phys_addr : out std_logic_vector(21 downto 13)  -- Top of Physical address
    );
end memory_map;

architecture behavior of memory_map is
begin
  process (iobyte, page1, page2, addr, erom)
  begin
    -- most likely outcome is writeable SRAM
    oe  <= '0';
    se  <= '1';
    fe  <= '0';
    ere <= '0';
    we  <= '1';
    -- now adjust
    if addr(15 downto 14) = "11" then
      -- Top RAM page
      phys_addr <= "00000000" & addr(13); -- RAM page alpha
    elsif iobyte(7) = '0' then
      if addr = "000" then
        -- Fixed ROM page
        we <= '0';
        phys_addr <= "000010000";
      elsif addr = "001" then
        -- ROM pages
        we <= '0';
        if erom = '1' and iobyte(6 downto 4) = "010" then
          se  <= '0';
          ere <= '1';
          phys_addr <= ( others => 'X' );
        else
          phys_addr <= "000001" & iobyte(6 downto 4);
        end if;
      else
        -- RAM pages, per p246
        case iobyte(3 downto 0) & addr(15 downto 14) is
          when "000010" => phys_addr <= "00000001" & addr(13); -- RAM page beta
          when "000001" => phys_addr <= "00000010" & addr(13); -- RAM page gamma
          when "000110" => phys_addr <= "00000011" & addr(13); -- RAM page delta
          when "000101" => phys_addr <= "00001100" & addr(13); -- RAM page a
          when "001010" => phys_addr <= "00001101" & addr(13); -- RAM page b
          when "001001" => phys_addr <= "00001110" & addr(13); -- RAM page c
          when "001110" => phys_addr <= "00001111" & addr(13); -- RAM page d
          when "001101" => phys_addr <= "00010000" & addr(13); -- RAM page e
          when "010010" => phys_addr <= "00010001" & addr(13); -- RAM page f
          when "010001" => phys_addr <= "00010010" & addr(13); -- RAM page g
          when "010110" => phys_addr <= "00010011" & addr(13); -- RAM page h
          when "010101" => phys_addr <= "00010100" & addr(13); -- RAM page i
          when "011010" => phys_addr <= "00010101" & addr(13); -- RAM page j
          when "011001" => phys_addr <= "00010110" & addr(13); -- RAM page k
          when "011110" => phys_addr <= "00010111" & addr(13); -- RAM page l
          when "011101" => phys_addr <= "00011000" & addr(13); -- RAM page m
          when "100010" => phys_addr <= "00011001" & addr(13); -- RAM page n
          when "100001" => phys_addr <= "00011010" & addr(13); -- RAM page o
          when "100110" => phys_addr <= "00011011" & addr(13); -- RAM page p
          when "100101" => phys_addr <= "00011100" & addr(13); -- RAM page q
          when "101010" => phys_addr <= "00011101" & addr(13); -- RAM page r
          when "101001" => phys_addr <= "00011110" & addr(13); -- RAM page s
          when "101110" => phys_addr <= "00011111" & addr(13); -- RAM page t
          -- sneaky backdoor to any 16KB SRAM page
          when "111001" => phys_addr <= page1 & addr(13);
          -- sneaky backdoor to any 16KB SRAM page
          when "111010" => phys_addr <= page2 & addr(13);
          -- sneaky backdoor to any 16KB SRAM page
          when "111101" => phys_addr <= page1 & addr(13);
          -- sneaky backdoor to any 16KB Flash page
          when "111110" => phys_addr <= page2 & addr(13); se <= '0'; fe <= '1';
          -- empty otherwise
          when others   => phys_addr <= "XXXXXXXXX"; se <= '0'; we <= '0';
        end case;
      end if;
    else
      -- RAM pages, per p247
      case iobyte(3 downto 0) & addr(15 downto 14) is
        when "000000" => phys_addr <= "00000011" & addr(13); -- RAM page delta
        when "000001" => phys_addr <= "00000010" & addr(13); -- RAM page gamma
        when "000010" => phys_addr <= "00000001" & addr(13); -- RAM page beta
        when "000100" => phys_addr <= "00001100" & addr(13); -- RAM page a
        when "000101" => phys_addr <= "00001101" & addr(13); -- RAM page b
        when "000110" => phys_addr <= "00001110" & addr(13); -- RAM page c
        when "001000" => phys_addr <= "00001111" & addr(13); -- RAM page d
        when "001001" => phys_addr <= "00010000" & addr(13); -- RAM page e
        when "001010" => phys_addr <= "00010001" & addr(13); -- RAM page f
        when "001100" => phys_addr <= "00010010" & addr(13); -- RAM page g
        when "001101" => phys_addr <= "00010011" & addr(13); -- RAM page h
        when "001110" => phys_addr <= "00010100" & addr(13); -- RAM page i
        when "010000" => phys_addr <= "00010101" & addr(13); -- RAM page j
        when "010001" => phys_addr <= "00010110" & addr(13); -- RAM page k
        when "010010" => phys_addr <= "00010111" & addr(13); -- RAM page l
        when "010100" => phys_addr <= "00011000" & addr(13); -- RAM page m
        when "010101" => phys_addr <= "00011001" & addr(13); -- RAM page n
        when "010110" => phys_addr <= "00011010" & addr(13); -- RAM page o
        when "011000" => phys_addr <= "00011011" & addr(13); -- RAM page p
        when "011001" => phys_addr <= "00011100" & addr(13); -- RAM page q
        when "011010" => phys_addr <= "00011101" & addr(13); -- RAM page r
        when "011100" => phys_addr <= "00011110" & addr(13); -- RAM page s
        when "011101" => phys_addr <= "00011111" & addr(13); -- RAM page t
        -- on chip memory (execution starts in here)
        when "111100" => phys_addr <= "00000000" & addr(13); se <= '0'; oe <= '1';
        -- sneaky backdoor to any 16KB SRAM page
        when "111101" => phys_addr <= page1 & addr(13);
        -- sneaky backdoor to any 16KB Flash page
        when "111110" => phys_addr <= page2 & addr(13); se <= '0'; fe <= '1';
          -- empty otherwise
        when others   => phys_addr <= "XXXXXXXXX"; se <= '0'; we <= '0';
      end case;
    end if;
  end process;
end behavior;
