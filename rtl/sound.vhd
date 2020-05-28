--
-- sound.vhd - SN76489A sound chip
--
-- References
--   http://www.smspower.org/Development/SN76489
--
-- Rewritten in 2017 to avoid using two seperate clock domains.
-- Instead do everything off of clk_cpu, and divide further so that we
-- update the waveform 250000 times per second (roughly).
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sound is
  port
    (
    -- processor interface
    clk_cpu   : in  std_logic;
    reset     : in  std_logic;
    reg_we    : in  std_logic;
    reg_value : in  std_logic_vector(7 downto 0);
    -- CPU speed, so we can further divide cpu_clk
    div_cpu   : in  std_logic_vector(2 downto 0);
    -- sound output
    output    : out std_logic_vector(7 downto 0)
    );
end sound;

architecture behavior of sound is

  -- tone channels
  type freq_t  is array (natural range 0 to 2) of std_logic_vector(9 downto 0);
  type phase_t is array (natural range 0 to 2) of std_logic;
  type atten_t is array (natural range 0 to 2) of std_logic_vector(3 downto 0);
  type level_t is array (natural range 0 to 2) of std_logic_vector(7 downto 0);
  signal freq    : freq_t := (others => "0000000000");
  signal count   : freq_t;
  signal phase   : phase_t;
  signal atten   : atten_t := (others => "1111");
  signal level   : level_t;
  signal channel : natural range 0 to 2;

  -- noise channel
  signal noise_fb        : std_logic;
  signal noise_freq_ctrl : std_logic_vector(1 downto 0);
  signal noise_count     : std_logic_vector(9 downto 0);
  signal noise_lfsr      : std_logic_vector(15 downto 0);
  signal noise_atten     : std_logic_vector(3 downto 0) := "1111";
  signal noise_level     : std_logic_vector(7 downto 0);

  -- use this to further divide clk_cpu down to 4MHz/16 approx
  signal clk_cpu_count : std_logic_vector(6 downto 0);

  signal output_int : std_logic_vector(10 downto 0) := "00000000000";

begin

  process ( clk_cpu, reset )
    variable o : std_logic_vector(10 downto 0);
  begin
    if reset = '1' then

      -- when chip is reset, it goes silent, and tone frequencies are reset
      for i in 0 to 2 loop
        freq(i)  <= "0000000000";
        atten(i) <= "1111";
      end loop;
      noise_fb        <= '0';
      noise_freq_ctrl <= "00";
      noise_atten     <= "1111";
      noise_lfsr      <= "1000000000000000";

    elsif rising_edge(clk_cpu) then

      -- generate waveform
      if clk_cpu_count = "0000000" then

        for i in 0 to 2 loop
          -- tone channel attenuation
          if phase(i) = '1' then
            level(i) <= "00001111" - ("0000"&atten(i)); -- 0 to +15
          else
            level(i) <= ("0000"&atten(i)) - "00001111"; -- -15 to 0
          end if;
          -- tone channel advance
          if count(i) = "0000000001" then
            count(i) <= freq(i);
            phase(i) <= not phase(i);
          else
            count(i) <= count(i)-1;
          end if;
        end loop;

        -- noise channel attenuation
        if noise_lfsr(0) = '1' then
          noise_level <= "00001111" - ("0000"&noise_atten); -- 0 to +15
        else
          noise_level <= ("0000"&noise_atten) - "00001111"; -- -15 to 0
        end if;

        -- noise channel advance
        if noise_count = "0000000001" then
          case noise_freq_ctrl is
            when "00" => noise_count <= "0000010000"; -- 16
            when "01" => noise_count <= "0000100000"; -- 16*2
            when "10" => noise_count <= "0001000000"; -- 16*4
            when "11" => noise_count <= freq(2);
          end case;
          if noise_fb = '1' then
            noise_lfsr <= ( noise_lfsr(0) xor noise_lfsr(3) ) & noise_lfsr(15 downto 1);
          else
            noise_lfsr <=   noise_lfsr(0)                     & noise_lfsr(15 downto 1);
          end if;
        else
          noise_count <= noise_count-1;
        end if;

        -- sum of levels is in the range -60 to 60
        -- so it becomes -480 to 480 here
        o := ( level(0)+level(1)+level(2)+noise_level ) & "000";

        -- try to smooth out the rough edges of the square waves
        -- after all, this was analog in the original chip
        -- new value = new*1/8 + old*7/8
        output_int <= ( o(10) & o(10) & o(10) & o(10 downto 3) )
                    + ( output_int(10) & output_int(10 downto 1) )
                    + ( output_int(10) & output_int(10) & output_int(10 downto 2) )
                    + ( output_int(10) & output_int(10) & output_int(10) & output_int(10 downto 3) );

        -- how many clk_cpu's to ignore before generating wavefrom again
        case div_cpu is
          when "000" =>
            clk_cpu_count <= "1100011"; -- 25.000MHz/(99+1) = 250000Hz
          when "001" =>
            clk_cpu_count <= "0110001"; -- 12.500MHz/(49+1) = 250000Hz
          when "010" =>
            clk_cpu_count <= "0100000"; --  8.333MHz/(32+1) = 252525Hz +1% error
          when "011" =>
            clk_cpu_count <= "0011000"; --  6.250MHz/(24+1) = 250000Hz
          when "100" =>
            clk_cpu_count <= "0010011"; --  5.000MHz/(19+1) = 250000Hz
          when "101" =>
            clk_cpu_count <= "0001111"; --  4.166MHz/(15+1) = 260416Hz +4% error
          when "110" =>
            clk_cpu_count <= "0001101"; --  3.571MHz/(13+1) = 255102Hz +2% error
          when "111" =>
            clk_cpu_count <= "0001011"; --  3.125MHz/(11+1) = 260416Hz +4% error
        end case;
      else
        clk_cpu_count <= clk_cpu_count-1;
      end if;

      -- writes to sound registers
      if reg_we = '1' then
        if reg_value(7) = '1' then
          -- write to register
          case reg_value(6 downto 4) is
            when "000" =>
              freq(0)(3 downto 0) <= reg_value(3 downto 0);
              channel <= 0;
            when "001" =>
              atten(0) <= reg_value(3 downto 0);
              channel <= 0;
            when "010" =>
              freq(1)(3 downto 0) <= reg_value(3 downto 0);
              channel <= 1;
            when "011" =>
              atten(1) <= reg_value(3 downto 0);
              channel <= 1;
            when "100" =>
              freq(2)(3 downto 0) <= reg_value(3 downto 0);
              channel <= 2; 
            when "101" =>
              atten(2) <= reg_value(3 downto 0);
              channel <= 2; 
            when "110" =>
              noise_fb        <= reg_value(2);
              noise_freq_ctrl <= reg_value(1 downto 0);
              noise_lfsr      <= "1000000000000000";
            when "111" =>
              noise_atten <= reg_value(3 downto 0);
          end case;
        else
          -- set high 6 bits of frequency
          freq(channel)(9 downto 4) <= reg_value(5 downto 0);
        end if;
      end if;

    end if;
  end process;

  output <= output_int(10 downto 3);

end behavior;
