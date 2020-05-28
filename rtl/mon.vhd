--
-- mon.vhd - 80 Column Card monitor
--
-- Per Memotech FDX.
-- 80x24 (or 80x48) cells.
-- 256 alpha characters and 256 graphics characters.
-- 8 foreground and background colours, with foreground flash.
-- 8 bit character, 8 bits attribute.
-- 640x480 60Hz VGA display.
-- Timings from http://tinyvga.com/vga-timing/640x480@60Hz
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mon is
  port
    (
    clk_25mhz     : in  std_logic;
    cell_addr     : out std_logic_vector(11 downto 0); -- 0 to 80*48-1
    cell_data_atr : in  std_logic_vector(7 downto 0); -- cell attribute
    cell_data_asc : in  std_logic_vector(7 downto 0); -- cell character
    base          : in  std_logic_vector(11 downto 0); -- 0 to 4095
    cursor        : in  std_logic_vector(11 downto 0); -- 0 to 4095
    cursor_vis    : in  std_logic;
    mode          : in  std_logic; -- 0 => 24 lines, 1 => 48 lines
    cursor_r      : in  std_logic;
    cursor_g      : in  std_logic;
    cursor_b      : in  std_logic;
    vga_r         : out std_logic;
    vga_g         : out std_logic;
    vga_b         : out std_logic;
    vga_hsync     : out std_logic;
    vga_vsync     : out std_logic;
    vga_hblank    : out std_logic;
    vga_vblank    : out std_logic
    );
end mon;

architecture behavior of mon is

  -- Alpha character generator
  component mon_prom_alpha
    port
      (
      clk  : in  std_logic;
      addr : in  std_logic_vector(11 downto 0);
      q    : out std_logic_vector(7 downto 0)
      );
  end component;

  -- Graph character generator
  component mon_prom_graph
    port
      (
      clk  : in  std_logic;
      addr : in  std_logic_vector(11 downto 0);
      q    : out std_logic_vector(7 downto 0)
      );
  end component;

  -- VGA parameters
  constant H_FP : integer := 16;
  constant H_SY : integer := 96;
  constant H_BP : integer := 48;
  constant V_FP : integer := 10;
  constant V_SY : integer := 2;
  constant V_BP : integer := 33;

  -- overall geometry of the display
  signal f_count         : unsigned(5 downto 0);
  signal h_count         : integer range 0 to H_FP+H_SY+H_BP+640-1 := 0;
  signal v_count         : integer range 0 to V_FP+V_SY+V_BP+480-1 := 0;
  signal h_active        : std_logic;
  signal v_active        : std_logic;
  signal h_sync          : std_logic;
  signal v_sync          : std_logic;

  -- what we put on the active part
  signal h_pixel         : integer range  0 to  7;
  signal v_pixel         : integer range  0 to  9;
  signal h_cell          : integer range -1 to 79;
  signal v_cell          : integer range  0 to 47;
  signal cell_ptr_fetch  : std_logic_vector(11 downto 0);
  signal cell_ptr_show   : std_logic_vector(11 downto 0);
  signal attr            : std_logic_vector(6 downto 0);
  signal prom_addr       : std_logic_vector(11 downto 0);
  signal prom_alpha_data : std_logic_vector(7 downto 0);
  signal prom_graph_data : std_logic_vector(7 downto 0);
  signal pixels          : std_logic_vector(7 downto 0);

begin

  U_ALPHA : mon_prom_alpha
    port map (
      clk  => clk_25mhz,
      addr => prom_addr,
      q    => prom_alpha_data
      );

  U_GRAPH : mon_prom_graph
    port map (
      clk  => clk_25mhz,
      addr => prom_addr,
      q    => prom_graph_data
      );

  process ( clk_25mhz )
  begin

    if rising_edge(clk_25mhz) then

      -- our state doesn't change, unless we say so below
      f_count        <= f_count;
      h_count        <= h_count;
      v_count        <= v_count;
      h_active       <= h_active;
      v_active       <= v_active;
      h_sync         <= h_sync;
      v_sync         <= v_sync;
      h_pixel        <= h_pixel;
      h_cell         <= h_cell;
      v_pixel        <= v_pixel;
      v_cell         <= v_cell;
      cell_ptr_fetch <= cell_ptr_fetch;
      cell_ptr_show  <= cell_ptr_show;
      attr           <= attr;
      prom_addr      <= prom_addr;
      pixels         <= pixels;

      -- output syncs
      vga_hsync <= h_sync;
      vga_vsync <= v_sync;
		
		vga_hblank <= not h_active;
		vga_vblank <= not v_active;
		

      -- active area
      if h_active = '1' and v_active = '1' then

        -- display the current pixel
        if cursor = cell_ptr_show and
           cursor_vis = '1' and f_count(4) = '1' then
          -- cursor is here, its on, and it is blink-on
          vga_r <= cursor_r;
          vga_g <= cursor_g;
          vga_b <= cursor_b;
        elsif pixels(7) = '1' and ( attr(6) = '0' or f_count(5) = '1' ) then
          -- character is drawn here, and its not blinking, or it is blink-on
          vga_r <= attr(0);
          vga_g <= attr(1);
          vga_b <= attr(2);
        else
          -- background colour
          vga_r <= attr(3);
          vga_g <= attr(4);
          vga_b <= attr(5);
        end if;

        -- do prefetch logic, and advance counters
        h_pixel            <= h_pixel+1;
        pixels(7 downto 1) <= pixels(6 downto 0);
        if h_pixel = 3 then
          -- assert cell address
          cell_addr <= cell_ptr_fetch;
        elsif h_pixel = 5 then
          -- read cell data
          -- assert font address
          prom_addr <= std_logic_vector(to_unsigned(v_pixel,4)) & cell_data_asc;
        elsif h_pixel = 7 then
          -- read font data
          h_pixel <= 0;
          if cell_data_atr(7) = '0' then
            pixels <= prom_alpha_data;
          else
            pixels <= prom_graph_data;
          end if;
          attr <= cell_data_atr(6 downto 0);
          cell_ptr_show <= cell_ptr_fetch;
          -- advance
          if h_cell /= 79 then
            -- advance to next character within the same scan line
            cell_ptr_fetch <= std_logic_vector(to_unsigned(to_integer(unsigned(cell_ptr_fetch))+1,12));
            h_cell <= h_cell+1;
          elsif mode = '0' and std_logic_vector(to_unsigned(v_count,1))(0) = '1' then
            -- repeat the same scan line
            cell_ptr_fetch <= std_logic_vector(to_unsigned(to_integer(unsigned(cell_ptr_fetch))-80,12));
            h_cell <= -1;
          elsif v_pixel /= 9 then
            -- advance to next scan line of this line of text
            cell_ptr_fetch <= std_logic_vector(to_unsigned(to_integer(unsigned(cell_ptr_fetch))-80,12));
            h_cell <= -1;
            v_pixel <= v_pixel+1;
          else
            -- to next line of text
            h_cell  <= -1;
            v_pixel <= 0;
            if v_count = 10+2+33+480-1 then
              v_cell <= 0;
            else
              v_cell <= v_cell+1;
            end if;
          end if;
        end if; -- end prefetch and advance

      else

        -- not in active area
        vga_r <= '0';
        vga_g <= '0';
        vga_b <= '0';

      end if; -- pixel displayed

      -- advance pixel counters
      h_count <= h_count+1;
		
		
		-- Calculo Señales Blank
		vga_hblank <= not h_active;
		vga_vblank <= not v_active;
		
--		if (h_count = 640-1 ) then
--			vga_hblank <= '0';
--
--			if (v_count = 480-1 ) then
--				vga_vblank <= '0';
--			end if;
--		end if;
-- 		if ( h_count = H_FP+H_SY+H_BP+640-1 ) then
--			vga_hblank <= '1';
--
--			if ( v_count = V_FP+V_SY+V_BP+480-1 ) then
--				vga_vblank <= '1';
--
--			end if;
--		end if;
			
		
      if h_count = H_FP-1 then
        -- horizontal sync
        h_sync <= '0';
      elsif h_count = H_FP+H_SY-1 then
        -- back porch
        h_sync <= '1';
      elsif h_count = H_FP+H_SY+H_BP-1 -8 then
        -- active
        h_active <= '1';
        -- we start active area 8 pixels too early
        -- because we output 1+80 cells
        -- and we ensure the first cell is black
        -- during its output, we are prefetching the first real cell
        attr(5 downto 0) <= "000000";
      elsif h_count = H_FP+H_SY+H_BP+640-1 then
        -- front porch
        h_count  <= 0;
        h_active <= '0';
        v_count <= v_count+1;
        if v_count = V_FP-1 then
          -- vertical sync
          v_sync <= '0';
        elsif v_count = V_FP+V_SY-1 then
          -- back porch
          v_sync <= '1';
        elsif v_count = V_FP+V_SY+V_BP-1 then
          -- active
          v_active <= '1';
          -- INITIALISE EVERYTHING
          h_cell <= -1;
          v_cell <= 0;
          h_pixel <= 0;
          v_pixel <= 0;
          cell_ptr_fetch <= base;
          f_count <= f_count+1;
        elsif v_count = V_FP+V_SY+V_BP+480-1 then
          -- front porch
          v_count  <= 0;
          v_active <= '0';
        end if;
      end if; -- pixel counters advanced

    end if; -- clk25_mhz

  end process;

end behavior;
