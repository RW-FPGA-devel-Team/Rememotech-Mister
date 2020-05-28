--
-- vdp.vhd - VDP
--
-- Outputs to standard 640x480@60Hz VGA. Also outputs at 50Hz, which your
-- monitor may not support - you may need to use a TV which is also a monitor.
--
-- Supports mode I, mode II and Text mode, doesn't support Multicolor mode.
-- Doesn't support external video input.
-- Doesn't support a 4KB VRAM option.
-- Doesn't support known but undocumented features.
--
-- References
--   http://tinyvga.com/vga-timing/640x480@60Hz
--   http://www.epanorama.net/faq/vga2rgb/calc.html, for 50Hz
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vdp is
  port
    (
    clk_25mhz     : in  std_logic;
    -- access to VRAM
    vram_addr     : out std_logic_vector(13 downto 0);
    vram_q        : in  std_logic_vector(7 downto 0);
    -- processor interface
    clk_cpu       : in  std_logic;
    reg_re        : in  std_logic;
    reg_we        : in  std_logic;
    reg_number    : in  std_logic_vector(2 downto 0);
    reg_value     : in  std_logic_vector(7 downto 0);
    status        : out std_logic_vector(7 downto 0);
    interrupt     : out std_logic;
    -- configuration
    hw_pal        : in  std_logic; -- '0' for normal, '1' for Marat
    frame_rate    : in  std_logic; -- '0' for 50Hz, '1' for 60Hz
    debug_patnam  : in  std_logic; -- '1' => pat at posn computed from posn
    debug_patgen  : in  std_logic; -- '1' => graphic reflects pattern number
    debug_patcol  : in  std_logic; -- '1' => palcol is fixed colour pair
    debug_sprgen  : in  std_logic; -- '1' => graphic reflects sprite number
    -- video outputs
    vga_r         : out std_logic_vector(3 downto 0);
    vga_g         : out std_logic_vector(3 downto 0);
    vga_b         : out std_logic_vector(3 downto 0);
    vga_hsync     : out std_logic;
    vga_vsync     : out std_logic;
	 vga_hblank		: out std_logic;
	 vga_vblank		: out std_logic
    );
end vdp;

architecture behavior of vdp is

  component vdp_palette
    port
      (
      colour : in  std_logic_vector(3 downto 0);
      hw_pal : in  std_logic;
      r      : out std_logic_vector(3 downto 0);
      g      : out std_logic_vector(3 downto 0);
      b      : out std_logic_vector(3 downto 0)
      );
  end component;

  component vdp_hex_char
    port
      (
      byte   : in  std_logic_vector(7 downto 0);
      scan   : in  std_logic_vector(2 downto 0);
      pixels : out std_logic_vector(7 downto 0)
      );
  end component;

  -- VGA parameters
  constant H_FP_60 : integer := 16;
  constant H_SY_60 : integer := 96;
  constant H_BP_60 : integer := 48;
  constant V_FP_60 : integer := 10;
  constant V_SY_60 : integer := 2;
  constant V_BP_60 : integer := 33;
  constant H_FP_50 : integer := 16;
  constant H_SY_50 : integer := 64;
  constant H_BP_50 : integer := 120;
  constant V_FP_50 : integer := 51;
  constant V_SY_50 : integer := 3;
  constant V_BP_50 : integer := 66;

  -- the overall geometry of the display
  signal frame_rate_int : std_logic := '0';
  signal h_count        : integer range 0 to H_FP_50+H_SY_50+H_BP_50+640-1 := 0;
  signal v_count        : integer range 0 to V_FP_50+V_SY_50+V_BP_50+480-1 := 0;
  signal h_active       : std_logic;
  signal v_active       : std_logic;
  signal h_sync         : std_logic;
  signal v_sync         : std_logic;
  signal h_pixels       : std_logic := '0';
  signal v_pixels       : std_logic := '0';

  signal h_pref         : std_logic := '0';

  signal h_cell         : integer range 0 to 39;
  signal v_cell         : integer range 0 to 23;
  signal h_pixel        : integer range 0 to 15;
  signal v_pixel        : integer range 0 to 15;

  signal vram_addr_int : std_logic_vector(13 downto 0);
  signal pixels        : std_logic_vector(7 downto 0);
  signal fgcol         : std_logic_vector(3 downto 0);
  signal bgcol         : std_logic_vector(3 downto 0);
  signal colour        : std_logic_vector(3 downto 0);
  signal next_pixels   : std_logic_vector(7 downto 0);

  -- VDP registers
  signal r_mode        : std_logic_vector(2 downto 0) := "000";
  signal r_blank       : std_logic := '0';
  signal r_ie          : std_logic := '0';
  signal r_size        : std_logic := '0';
  signal r_mag         : std_logic := '0';
  signal r_patnam      : std_logic_vector(13 downto 10);
  signal r_patcol      : std_logic_vector(13 downto  6);
  signal r_patgen      : std_logic_vector(13 downto 11);
  signal r_spratt      : std_logic_vector(13 downto  7);
  signal r_sprgen      : std_logic_vector(13 downto 11);
  signal r_fgcol       : std_logic_vector(3 downto 0);
  signal r_bgcol       : std_logic_vector(3 downto 0);
  -- VDP status register
  signal r_f           : std_logic := '0';
  signal r_5s          : std_logic := '0';
  signal r_c           : std_logic := '0';
  signal r_fsn         : std_logic_vector(4 downto 0) := "00000";
  -- VDP status register at next end of frame
  signal next_5s       : std_logic;
  signal next_c        : std_logic;
  signal next_fsn      : std_logic_vector(4 downto 0);
  -- internal view of the frame bit
  signal r_f_int       : std_logic := '0';
  signal r_f_int_prev  : std_logic := '0';
  signal reg_re_prev   : std_logic := '0';

  signal r_mode_int    : std_logic_vector(2 downto 0);

  -- spr_state values
  constant S_INIT      : natural :=  0;
  constant S_REQ_Y     : natural :=  1;
  constant S_PROC_Y    : natural :=  2;
  constant S_REQ_X     : natural :=  3;
  constant S_PROC_X    : natural :=  4;
  constant S_REQ_NUM   : natural :=  5;
  constant S_PROC_NUM  : natural :=  6;
  constant S_REQ_ATT   : natural :=  7;
  constant S_PROC_ATT  : natural :=  8;
  constant S_REQ_PATL  : natural :=  9;
  constant S_PROC_PATL : natural := 10;
  constant S_REQ_PATR  : natural := 11;
  constant S_PROC_PATR : natural := 12;
  constant S_MAG       : natural := 13;
  constant S_EC        : natural := 14;
  constant S_NEXT      : natural := 15;
  constant S_FIFTH     : natural := 16;
  constant S_DONE      : natural := 17;

  signal spr_state : natural range 0 to 17; -- S_ value
  signal spr_index : natural range 0 to 31;
  signal spr_y_off : std_logic_vector(3 downto 0);
  signal spr_num   : std_logic_vector(7 downto 0);
  signal spr_ec    : std_logic;
  signal spr_bits  : std_logic_vector(31 downto 0);

  signal spr_count : natural range 0 to 4;
  type x_t   is array (natural range 0 to 3) of std_logic_vector(7 downto 0);
  type pat_t is array (natural range 0 to 3) of std_logic_vector(31 downto 0);
  type col_t is array (natural range 0 to 3) of std_logic_vector(3 downto 0);
  signal spr_x     : x_t;
  signal spr_pat   : pat_t;
  signal spr_col   : col_t;

  signal hexchar_pat_byte   : std_logic_vector(7 downto 0);
  signal hexchar_pat_scan   : std_logic_vector(2 downto 0);
  signal hexchar_pat_pixels : std_logic_vector(7 downto 0);

begin

  U_PALETTE : vdp_palette
    port map (
      colour => colour,
      hw_pal => hw_pal,
      r      => vga_r,
      g      => vga_g,
      b      => vga_b
      );

  U_HEXCHAR_PAT : vdp_hex_char
    port map (
      byte   => hexchar_pat_byte,
      scan   => hexchar_pat_scan,
      pixels => hexchar_pat_pixels
      );

  -- writes to VDP registers
  process ( clk_cpu )
  begin
    if rising_edge(clk_cpu) then

      if reg_we = '1' then
        case reg_number is
          when "000" =>
            r_mode(0) <= reg_value(1); -- M3
          when "001" =>
            r_blank   <= reg_value(6);
            r_ie      <= reg_value(5);
            r_mode(2) <= reg_value(4); -- M1
            r_mode(1) <= reg_value(3); -- M2
            r_size    <= reg_value(1);
            r_mag     <= reg_value(0);
          when "010" =>
            r_patnam  <= reg_value(3 downto 0);
          when "011" =>
            r_patcol  <= reg_value;
          when "100" =>
            r_patgen  <= reg_value(2 downto 0);
          when "101" =>
            r_spratt  <= reg_value(6 downto 0);
          when "110" =>
            r_sprgen  <= reg_value(2 downto 0);
          when "111" =>
            r_fgcol   <= reg_value(7 downto 4);
            r_bgcol   <= reg_value(3 downto 0);
          when others =>
        end case;
      end if;

      if reg_re_prev = '0' and reg_re = '1' then
        -- on this clock, the CPU is reading status
        -- turn off frame bit
        r_f <= '0';
      end if;
      reg_re_prev <= reg_re;

      if r_f_int_prev = '0' and r_f_int = '1' then
        r_f <= '1';
      elsif r_f_int_prev = '1' and r_f_int = '0' then
        r_f <= '0';
      end if;
      r_f_int_prev <= r_f_int;

    end if;
  end process;

  status <= r_f & r_5s & r_c & r_fsn;

  -- outputting the screen
  process ( clk_25mhz )

    variable y_off      : std_logic_vector(7 downto 0);
    variable spr_pixels : std_logic_vector(3 downto 0);

  begin

    if rising_edge(clk_25mhz) then

      h_count   <= h_count;
      v_count   <= v_count;
      h_active  <= h_active;
      v_active  <= v_active;
      h_sync    <= h_sync;
      v_sync    <= v_sync;
      h_pixels  <= h_pixels;
      v_pixels  <= v_pixels;
      h_cell    <= h_cell;
      v_cell    <= v_cell;
      h_pixel   <= h_pixel;
      v_pixel   <= v_pixel;

      vga_hsync <= h_sync;
      vga_vsync <= v_sync;

		
      if v_pixels = '1' then
        -- on a line with pixels, so advance the sprite reader state machine
        -- our budget is 160, ie: horizontal left porch, sync, right porch
        case spr_state is
          when S_INIT =>
            spr_count <= 0;
            if r_mode = "000" or r_mode = "001" then
              spr_index <= 0;
              vram_addr_int <= r_spratt & "0000000";
              spr_state <= S_REQ_Y;
            else
              spr_state <= S_DONE;
            end if;
          when S_PROC_Y =>
            if vram_q = x"d0" then
              spr_state <= S_DONE;
            else
              y_off := ( std_logic_vector(to_unsigned(v_cell,5)) &
                         std_logic_vector(to_unsigned(v_pixel/2,3)) ) -
                       ( vram_q+1 );
              if    y_off <  8 and r_size = '0' and r_mag = '0' then
                if spr_count = 4 then
                  spr_state <= S_FIFTH;
                else
                  spr_y_off <= "0" & y_off(2 downto 0);
                  vram_addr_int(0) <= '1';
                  spr_state <= S_REQ_X;
                end if;
              elsif y_off < 16 and r_size = '0' and r_mag = '1' then
                if spr_count = 4 then
                  spr_state <= S_FIFTH;
                else
                  spr_y_off <= "0" & y_off(3 downto 1);
                  vram_addr_int(0) <= '1';
                  spr_state <= S_REQ_X;
                end if;
              elsif y_off < 16 and r_size = '1' and r_mag = '0' then
                if spr_count = 4 then
                  spr_state <= S_FIFTH;
                else
                  spr_y_off <= y_off(3 downto 0);
                  vram_addr_int(0) <= '1';
                  spr_state <= S_REQ_X;
                end if;
              elsif y_off < 32 and r_size = '1' and r_mag = '1' then
                if spr_count = 4 then
                  spr_state <= S_FIFTH;
                else
                  spr_y_off <= y_off(4 downto 1);
                  vram_addr_int(0) <= '1';
                  spr_state <= S_REQ_X;
                end if;
              else
                if spr_index = 31 then
                  spr_state <= S_DONE;
                else
                  vram_addr_int <=
                    r_spratt &
                    std_logic_vector(to_unsigned(spr_index+1,5)) &
                    "00";
                  spr_index <= spr_index+1;
                  spr_state <= S_REQ_Y;
                end if;
              end if;
            end if;
          when S_PROC_X =>
            spr_x(spr_count) <= vram_q;
            vram_addr_int(1 downto 0) <= "10";
            spr_state <= S_REQ_NUM;
          when S_PROC_NUM =>
            spr_num <= vram_q;
            vram_addr_int(0) <= '1';
            spr_state <= S_REQ_ATT;
          when S_PROC_ATT =>
            spr_ec <= vram_q(7);
            spr_col(spr_count) <= vram_q(3 downto 0);
            if r_size = '0' then
              vram_addr_int <=
                r_sprgen &
                spr_num & 
                spr_y_off(2 downto 0);
              hexchar_pat_byte <=
                spr_num;
            else
              vram_addr_int <=
                r_sprgen &
                spr_num(7 downto 2) &
                "0" &
                spr_y_off;
              hexchar_pat_byte <=
                spr_num(7 downto 2) &
                "0" &
                spr_y_off(3);
            end if;
            hexchar_pat_scan <=
              spr_y_off(2 downto 0);
            spr_state <= S_REQ_PATL;
          when S_PROC_PATL =>
            if debug_sprgen = '0' then
              spr_bits(31 downto 24) <= vram_q;
            else
              spr_bits(31 downto 24) <= hexchar_pat_pixels;
            end if;
            vram_addr_int(4) <= '1';
            hexchar_pat_byte(1) <= '1';
            spr_state <= S_REQ_PATR;
          when S_PROC_PATR =>
            if r_size = '1' then
              if debug_sprgen = '0' then
                spr_bits(23 downto 16) <= vram_q;
              else
                spr_bits(23 downto 16) <= hexchar_pat_pixels;
              end if;
            else
              spr_bits(23 downto 16) <= (others => '0');
            end if;
            spr_state <= S_MAG;
          when S_MAG =>
            if r_mag = '1' then
              spr_bits <=
                spr_bits(31)&spr_bits(31)&
                spr_bits(30)&spr_bits(30)&
                spr_bits(29)&spr_bits(29)&
                spr_bits(28)&spr_bits(28)&
                spr_bits(27)&spr_bits(27)&
                spr_bits(26)&spr_bits(26)&
                spr_bits(25)&spr_bits(25)&
                spr_bits(24)&spr_bits(24)&
                spr_bits(23)&spr_bits(23)&
                spr_bits(22)&spr_bits(22)&
                spr_bits(21)&spr_bits(21)&
                spr_bits(20)&spr_bits(20)&
                spr_bits(19)&spr_bits(19)&
                spr_bits(18)&spr_bits(18)&
                spr_bits(17)&spr_bits(17)&
                spr_bits(16)&spr_bits(16);
            else
              spr_bits(15 downto 0) <= (others => '0');
            end if;
            if spr_ec = '1' then
              spr_state <= S_EC;
            else
              spr_state <= S_NEXT;
            end if;
          when S_EC =>
            if spr_x(spr_count)(7 downto 5) = "000" then
              -- what a barrel of laughs
              spr_bits <= (others => '0');
              case spr_x(spr_count)(4 downto 0) is
                when "00001" => spr_bits(31          ) <= spr_bits(          0);
                when "00010" => spr_bits(31 downto 30) <= spr_bits( 1 downto 0);
                when "00011" => spr_bits(31 downto 29) <= spr_bits( 2 downto 0);
                when "00100" => spr_bits(31 downto 28) <= spr_bits( 3 downto 0);
                when "00101" => spr_bits(31 downto 27) <= spr_bits( 4 downto 0);
                when "00110" => spr_bits(31 downto 26) <= spr_bits( 5 downto 0);
                when "00111" => spr_bits(31 downto 25) <= spr_bits( 6 downto 0);
                when "01000" => spr_bits(31 downto 24) <= spr_bits( 7 downto 0);
                when "01001" => spr_bits(31 downto 23) <= spr_bits( 8 downto 0);
                when "01010" => spr_bits(31 downto 22) <= spr_bits( 9 downto 0);
                when "01011" => spr_bits(31 downto 21) <= spr_bits(10 downto 0);
                when "01100" => spr_bits(31 downto 20) <= spr_bits(11 downto 0);
                when "01101" => spr_bits(31 downto 19) <= spr_bits(12 downto 0);
                when "01110" => spr_bits(31 downto 18) <= spr_bits(13 downto 0);
                when "01111" => spr_bits(31 downto 17) <= spr_bits(14 downto 0);
                when "10000" => spr_bits(31 downto 16) <= spr_bits(15 downto 0);
                when "10001" => spr_bits(31 downto 15) <= spr_bits(16 downto 0);
                when "10010" => spr_bits(31 downto 14) <= spr_bits(17 downto 0);
                when "10011" => spr_bits(31 downto 13) <= spr_bits(18 downto 0);
                when "10100" => spr_bits(31 downto 12) <= spr_bits(19 downto 0);
                when "10101" => spr_bits(31 downto 11) <= spr_bits(20 downto 0);
                when "10110" => spr_bits(31 downto 10) <= spr_bits(21 downto 0);
                when "10111" => spr_bits(31 downto  9) <= spr_bits(22 downto 0);
                when "11000" => spr_bits(31 downto  8) <= spr_bits(23 downto 0);
                when "11001" => spr_bits(31 downto  7) <= spr_bits(24 downto 0);
                when "11010" => spr_bits(31 downto  6) <= spr_bits(25 downto 0);
                when "11011" => spr_bits(31 downto  5) <= spr_bits(26 downto 0);
                when "11100" => spr_bits(31 downto  4) <= spr_bits(27 downto 0);
                when "11101" => spr_bits(31 downto  3) <= spr_bits(28 downto 0);
                when "11110" => spr_bits(31 downto  2) <= spr_bits(29 downto 0);
                when "11111" => spr_bits(31 downto  1) <= spr_bits(30 downto 0);
                when others =>
              end case;
              spr_x(spr_count)(4 downto 0) <= "00000";
            else
              spr_x(spr_count) <= spr_x(spr_count)-32;
            end if;
            spr_state <= S_NEXT;
          when S_NEXT =>
            spr_pat(spr_count) <= spr_bits;
            spr_count <= spr_count+1;
            if spr_index = 31 then
              spr_state <= S_DONE;
            else
              vram_addr_int <=
                r_spratt &
                std_logic_vector(to_unsigned(spr_index+1,5)) &
                "00";
              spr_index <= spr_index+1;
              spr_state <= S_REQ_Y;
            end if;
          when S_FIFTH =>
            if next_5s = '0' then
              next_5s  <= '1';
              next_fsn <= std_logic_vector(to_unsigned(spr_index,5));
            end if;
            -- state remains like this until next scan line
          when S_DONE =>
            -- state remains like this until next scan line
          when others =>
            -- this is where the VRAM reads the address and asserts the data
            spr_state <= spr_state+1;
        end case;
      end if;

      if h_active = '1' and v_active = '1' then
        -- in the VGA active area

        -- output the right pixel
        if h_pixels = '1' and v_pixels = '1' and r_blank = '1' then

          for i in 0 to 3 loop
            if spr_count >= i and spr_x(i) = "00000000" and spr_col(i) /= "0000" then
              spr_pixels(i) := spr_pat(i)(31);
            else
              spr_pixels(i) := '0';
            end if;
          end loop;

          if spr_pixels(0) = '1' then
            colour <= spr_col(0);
          elsif spr_pixels(1) = '1' then
            colour <= spr_col(1);
          elsif spr_pixels(2) = '1' then
            colour <= spr_col(2);
          elsif spr_pixels(3) = '1' then
            colour <= spr_col(3);
          elsif pixels(7) = '1' then
            if fgcol = "0000" then
              colour <= r_bgcol;
            else
              colour <= fgcol;
            end if;
          else
            if bgcol = "0000" then
              colour <= r_bgcol;
            else
              colour <= bgcol;
            end if;
          end if;

          case spr_pixels is
            when "0000" | "0001" | "0010" | "0100" | "1000" =>
              -- no coincidence, so fine
            when others =>
              r_c <= '1';
          end case;

          if std_logic_vector(to_unsigned(h_pixel, 4))(0) = '1' then
            pixels(7 downto 1) <= pixels(6 downto 0);
            for i in 0 to 3 loop
              if spr_x(i) /= "00000000" then
                spr_x(i) <= spr_x(i)-1;
              else
                spr_pat(i)(31 downto 1) <= spr_pat(i)(30 downto 0);
                spr_pat(i)(0)           <= '0';
              end if;
            end loop;
          end if;

        else
          colour <= r_bgcol; -- set border colour
        end if;

        -- step and prefetch logic
        h_pixel <= h_pixel+1;
        if h_pref = '1' then
          -- should be prefetching
          case r_mode_int is
            when "000" =>
              -- Graphics I
              case h_pixel is
                when 9 =>
                  vram_addr_int <=
                    r_patnam &
                    std_logic_vector(to_unsigned(v_cell,5)) & 
                    std_logic_vector(to_unsigned(h_cell,5));
                when 11 =>
                  if debug_patnam = '1' then
                    vram_addr_int <=
                      r_patgen(13 downto 11) &
                      vram_addr_int(7 downto 0) &
                      std_logic_vector(to_unsigned(v_pixel/2,3));
                    hexchar_pat_byte <=
                      vram_addr_int(7 downto 0);
                  else
                    vram_addr_int <=
                      r_patgen(13 downto 11) & 
                      vram_q &
                      std_logic_vector(to_unsigned(v_pixel/2,3));
                    hexchar_pat_byte <=
                      vram_q;
                  end if;
                  hexchar_pat_scan <=
                    std_logic_vector(to_unsigned(v_pixel/2,3));
                when 13 =>
                  if debug_patgen = '1' then
                    next_pixels <= hexchar_pat_pixels;
                  else
                    next_pixels <= vram_q;
                  end if;
                  vram_addr_int <=
                    r_patcol & "0" &
                    vram_addr_int(10 downto 6);
                when 15 =>
                  pixels <= next_pixels;
                  if debug_patcol = '1' then
                    fgcol <= "1000"; -- medium red
                    bgcol <= "0001"; -- black
                  else
                    fgcol <= vram_q(7 downto 4);
                    bgcol <= vram_q(3 downto 0);
                  end if;
                  h_cell  <= h_cell+1;
                  h_pixel <= 0;
                when others =>
              end case;
            when "001" =>
              -- Graphics II
              case h_pixel is
                when 9 =>
                  vram_addr_int <=
                    r_patnam &
                    std_logic_vector(to_unsigned(v_cell,5)) & 
                    std_logic_vector(to_unsigned(h_cell,5));
                when 11 =>
                  -- we don't look at all of r_patgen
                  -- we don't honor any undocumented behaviours
                  if debug_patnam = '1' then
                    vram_addr_int <=
                      r_patgen(13) &
                      std_logic_vector(to_unsigned(v_cell/8,2)) &
                      vram_addr_int(7 downto 0) &
                      std_logic_vector(to_unsigned(v_pixel/2,3));
                    hexchar_pat_byte <=
                      vram_addr_int(7 downto 0);
                  else
                    vram_addr_int <=
                      r_patgen(13) &
                      std_logic_vector(to_unsigned(v_cell/8,2)) &
                      vram_q &
                      std_logic_vector(to_unsigned(v_pixel/2,3));
                    hexchar_pat_byte <=
                      vram_q;
                  end if;
                  hexchar_pat_scan <=
                    std_logic_vector(to_unsigned(v_pixel/2,3));
                when 13 =>
                  if debug_patgen = '1' then
                    next_pixels <= hexchar_pat_pixels;
                  else
                    next_pixels <= vram_q;
                  end if;
                  -- we don't look at all of r_patcol
                  -- we don't honor any undocumented behaviours
                  vram_addr_int(13) <=
                    r_patcol(13);
                when 15 =>
                  pixels <= next_pixels;
                  if debug_patcol = '1' then
                    fgcol <= "0010"; -- medium green
                    bgcol <= "0001"; -- black
                  else
                    fgcol <= vram_q(7 downto 4);
                    bgcol <= vram_q(3 downto 0);
                  end if;
                  h_cell  <= h_cell+1;
                  h_pixel <= 0;
                when others =>
              end case;
            when "100" =>
              -- Text mode
              case h_pixel is
                when 11 =>
                  vram_addr_int <=
                    r_patnam &
                    std_logic_vector(to_unsigned(v_cell*40+h_cell,10));
                when 13 =>
                  if debug_patnam = '1' then
                    vram_addr_int <=
                      r_patgen &
                      vram_addr_int(7 downto 0) &
                      std_logic_vector(to_unsigned(v_pixel/2,3));
                    hexchar_pat_byte <=
                      vram_addr_int(7 downto 0);
                  else
                    vram_addr_int <=
                      r_patgen &
                      vram_q &
                      std_logic_vector(to_unsigned(v_pixel/2,3));
                    hexchar_pat_byte <=
                      vram_q;
                  end if;
                  hexchar_pat_scan <=
                    std_logic_vector(to_unsigned(v_pixel/2,3));
                when 15 =>
                  if debug_patgen = '1' then
                    -- note that there are 8 pixels supplied,
                    -- and we can only output 6
                    if debug_sprgen = '1' then
                      pixels(7 downto 2) <= hexchar_pat_pixels(5 downto 0);
                    else
                      pixels <= hexchar_pat_pixels;
                    end if;
                  else
                    pixels(7 downto 2) <= vram_q(7 downto 2);
                  end if;
                  if debug_patcol = '1' then
                    fgcol <= "0101"; -- light blue
                    bgcol <= "0001"; -- black
                  else
                    fgcol <= r_fgcol;
                    bgcol <= r_bgcol;
                  end if;
                  h_cell  <= h_cell+1;
                  h_pixel <= 4;
                when others =>
              end case;
            when others =>
              -- Unsupported mode, set it to the background
              pixels <= "00000000";
              bgcol  <= r_bgcol;
          end case;
        end if;

      else
        colour <= "0000"; -- non-VGA-active area must be black
      end if;

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
-- 		if ( frame_rate_int = '1' and h_count = H_FP_60+H_SY_60+H_BP_60+640-1 ) or
--            ( frame_rate_int = '0' and h_count = H_FP_50+H_SY_50+H_BP_50+640-1 ) then
--			vga_hblank <= '1';
--
--			if ( frame_rate_int = '1' and v_count = V_FP_60+V_SY_60+V_BP_60+480-1 ) or
--            ( frame_rate_int = '0' and v_count = V_FP_50+V_SY_50+V_BP_50+480-1 ) then
--				vga_vblank <= '1';
--
--			end if;
--		end if;
		


      if ( frame_rate_int = '1' and h_count = H_FP_60-1 ) or
         ( frame_rate_int = '0' and h_count = H_FP_50-1 ) then
        -- horizontal sync
        h_sync <= '0';
      elsif ( frame_rate_int = '1' and h_count = H_FP_60+H_SY_60-1 ) or
            ( frame_rate_int = '0' and h_count = H_FP_50+H_SY_50-1 ) then
        -- back porch
        h_sync <= '1';
      elsif ( frame_rate_int = '1' and h_count = H_FP_60+H_SY_60+H_BP_60-1 ) or
            ( frame_rate_int = '0' and h_count = H_FP_50+H_SY_50+H_BP_50-1 ) then
        -- active
        h_active <= '1';
      elsif ( frame_rate_int = '1' and h_count = H_FP_60+H_SY_60+H_BP_60+64-1 -16 and r_mode_int /= "100" ) or
            ( frame_rate_int = '1' and h_count = H_FP_60+H_SY_60+H_BP_60+80-1 -16 and r_mode_int  = "100" ) or
            ( frame_rate_int = '0' and h_count = H_FP_50+H_SY_50+H_BP_50+64-1 -16 and r_mode_int /= "100" ) or
            ( frame_rate_int = '0' and h_count = H_FP_50+H_SY_50+H_BP_50+80-1 -16 and r_mode_int  = "100" ) then
        -- prefetch begins
        h_pref  <= '1';
        h_cell  <= 0;
        h_pixel <= 0;
      elsif ( frame_rate_int = '1' and h_count = H_FP_60+H_SY_60+H_BP_60+64-1 and r_mode_int /= "100" ) or
            ( frame_rate_int = '1' and h_count = H_FP_60+H_SY_60+H_BP_60+80-1 and r_mode_int  = "100" ) or
            ( frame_rate_int = '0' and h_count = H_FP_50+H_SY_50+H_BP_50+64-1 and r_mode_int /= "100" ) or
            ( frame_rate_int = '0' and h_count = H_FP_50+H_SY_50+H_BP_50+80-1 and r_mode_int  = "100" ) then
        -- VDP pixel area begins
        h_pixels <= '1';
      elsif ( frame_rate_int = '1' and h_count = H_FP_60+H_SY_60+H_BP_60+64+512-1 and r_mode_int /= "100" ) or
            ( frame_rate_int = '1' and h_count = H_FP_60+H_SY_60+H_BP_60+80+480-1 and r_mode_int  = "100" ) or
            ( frame_rate_int = '0' and h_count = H_FP_50+H_SY_50+H_BP_50+64+512-1 and r_mode_int /= "100" ) or
            ( frame_rate_int = '0' and h_count = H_FP_50+H_SY_50+H_BP_50+80+480-1 and r_mode_int  = "100" ) then
        -- VDP pixel area ends
        h_pixels <= '0';
        h_pref   <= '0';
      elsif ( frame_rate_int = '1' and h_count = H_FP_60+H_SY_60+H_BP_60+640-1 ) or
            ( frame_rate_int = '0' and h_count = H_FP_50+H_SY_50+H_BP_50+640-1 ) then
        -- front porch
        h_count  <= 0;
        h_active <= '0';
        v_count <= v_count+1;
        if v_pixel = 15 then
          v_pixel <= 0;
          v_cell  <= v_cell+1;
        else
          v_pixel <= v_pixel+1;
        end if;
        spr_state <= S_INIT;
        if ( frame_rate_int = '1' and v_count = V_FP_60-1 ) or
           ( frame_rate_int = '0' and v_count = V_FP_50-1 ) then
          -- vertical sync
          v_sync <= '0';
        elsif ( frame_rate_int = '1' and v_count = V_FP_60+V_SY_60-1 ) or
              ( frame_rate_int = '0' and v_count = V_FP_50+V_SY_50-1 ) then
          -- back porch
          v_sync <= '1';
        elsif ( frame_rate_int = '1' and v_count = V_FP_60+V_SY_60+V_BP_60-1 ) or
              ( frame_rate_int = '0' and v_count = V_FP_50+V_SY_50+V_BP_50-1 ) then
          -- active
          v_active <= '1';
        elsif ( frame_rate_int = '1' and v_count = V_FP_60+V_SY_60+V_BP_60+48-1 ) or
              ( frame_rate_int = '0' and v_count = V_FP_50+V_SY_50+V_BP_50+48-1 ) then
          -- VDP pixel area begins
          v_pixels <= '1';
          v_cell   <= 0;
          v_pixel  <= 0;
          next_5s  <= '0';
          next_c   <= '0';
          next_fsn <= "00000";
        elsif ( frame_rate_int = '1' and v_count = V_FP_60+V_SY_60+V_BP_60+48+384-1 ) or
              ( frame_rate_int = '0' and v_count = V_FP_50+V_SY_50+V_BP_50+48+384-1 ) then
          -- VDP pixel area ends
          v_pixels <= '0';
          -- update the status register
          r_f_int <= '1';
          r_5s    <= next_5s;
          r_c     <= next_c;
          r_fsn   <= next_fsn;
        elsif ( frame_rate_int = '1' and v_count = V_FP_60+V_SY_60+V_BP_60+480-1 ) or
              ( frame_rate_int = '0' and v_count = V_FP_50+V_SY_50+V_BP_50+480-1 ) then
          -- front porch
          r_f_int  <= '0';
          v_count  <= 0;
          v_active <= '0';
          -- these are values that will remain unchanged for
          -- the duration of generating the next whole VGA frame
          frame_rate_int <= frame_rate;
          r_mode_int     <= r_mode;
        end if;
      end if; -- pixel counters advanced

    end if;

  end process;

  vram_addr <= vram_addr_int;

  interrupt <= r_f and r_ie;

end behavior;
