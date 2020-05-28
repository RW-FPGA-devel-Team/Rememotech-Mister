--
-- ctc.vhd - Counter Timer Chip
--
-- Useful approximation to a Z80 CTC.
-- We don't differentiate between rising and falling edges.
-- We don't support the "timer trigger" bit.
-- We don't support the daisy chaining of CTCs.
-- We work with a timer input which is already divided by 16.
--
-- Interaction
--   first rising edge
--     CTC determines that channel(s) are pending
--     interrupt line becomes '1', which results in CPU INT_n = '0'
--   later rising edge
--     CPU notices, and sets M1_n = '0' and IORQ_n = '0'
--     this results in re_vector = '1'
--     CTC prepares vector and removes corresponding pending flag
--   next rising edge
--     CPU reads the vector, and does its thing
--
-- We support the MTX PANEL and VDEB hack, allowing single stepping of ROM.
-- Channel 2 put in timer mode with counter of 13 and prescaler of 16.
-- 208 clocks later, we are single stepping the next instruction.
-- Interrupt happens, debugger gets control again.
-- The hack is clearly commented as such in the code below.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ctc is
  port
    (
    -- CPU side
    clk_cpu    : in  std_logic;
    reset      : in  std_logic;
    channel    : in  std_logic_vector(1 downto 0);
    we         : in  std_logic;
    data_write : in  std_logic_vector(7 downto 0);
    data_read  : out std_logic_vector(7 downto 0);
    interrupt  : out std_logic;
    re_vector  : in  std_logic;
    vector     : out std_logic_vector(7 downto 1);
    -- Inputs
    timer16    : in  std_logic;
    count0     : in  std_logic;
    count1     : in  std_logic;
    count2     : in  std_logic;
    count3     : in  std_logic;
    -- Outputs
    zcto0      : out std_logic;
    zcto1      : out std_logic;
    zcto2      : out std_logic
    );
end ctc;

architecture behavior of ctc is

  type bit_per_channel_t    is array (natural range 0 to 3) of std_logic;
  type nibble_per_channel_t is array (natural range 0 to 3) of std_logic_vector(3 downto 0);
  type byte_per_channel_t   is array (natural range 0 to 3) of std_logic_vector(7 downto 0);

  signal int_enabled   : bit_per_channel_t := (others => '0');
  signal counter_mode  : bit_per_channel_t := (others => '0');
  signal prescaler_256 : bit_per_channel_t := (others => '0');
  signal konstant_load : bit_per_channel_t := (others => '0');
  signal reset_channel : bit_per_channel_t := (others => '1');

  signal prescaler : nibble_per_channel_t := (others => "0000");
  signal konstant  : byte_per_channel_t   := (others => "00000000");
  signal counter   : byte_per_channel_t   := (others => "00000000");
  signal pending   : bit_per_channel_t    := (others => '0');

  signal vector_int : std_logic_vector(7 downto 1) := "0000011";

  signal prev_count   : bit_per_channel_t := (others => '0');
  signal prev_timer16 : std_logic         := '0';

  signal re_vector_old : std_logic := '0';

  -- PANEL hack counter
  signal panel_counter : std_logic_vector(7 downto 0) := "00000000";
  -- end PANEL hack counter

begin

  process ( clk_cpu, reset )
    variable ch         : integer range 0 to 3;
    variable this_count : bit_per_channel_t;
    variable this_zcto  : bit_per_channel_t;
  begin

    if reset = '1' then

      for i in 0 to 3 loop
        int_enabled(i)   <= '0';
        counter_mode(i)  <= '0';
        prescaler_256(i) <= '0';
        konstant_load(i) <= '0';
        reset_channel(i) <= '1';
        prescaler(i)     <= "0000";
        konstant(i)      <= "00000000";
        pending(i)       <= '0';
      end loop;
      vector_int    <= "0000011";
      re_vector_old <= '0';

    elsif rising_edge(clk_cpu) then

      -- write registers
      ch := to_integer(unsigned(channel));
      if we = '1' then
        if konstant_load(ch) = '1' then
          konstant_load(ch) <= '0';
          reset_channel(ch) <= '0';
          konstant(ch)      <= data_write;
            -- constant of 0 is treated as 256
            -- the counter is not reloaded,
            -- nor is the prescaler

          -- enable PANEL hack
          if ch = 2 and 
             int_enabled(2) = '1' and
             counter_mode(2) = '0' and
             prescaler_256(2) = '0' and
             data_write = "00001101" then
            panel_counter <= "11010000"; -- 208 clocks until interrupt
            int_enabled(2) <= '0'; -- normal channel 2 activity can't cause pending
          end if;
          -- end enable PANEL hack

        elsif data_write(0) = '1' then
          int_enabled(ch)   <= data_write(7);
          counter_mode(ch)  <= data_write(6);
          prescaler_256(ch) <= data_write(5);
          konstant_load(ch) <= data_write(2);
          reset_channel(ch) <= data_write(1);
            -- The Zilog CTC manual says that reset channel is set
            -- the bits in the control register are not changed,
            -- but we have changed them. Oops!

          -- disable PANEL hack
          if ch = 2 then
            panel_counter <= "00000000";
          end if;
          -- end disable PANEL hack

        else
          if ch = 0 then
            vector_int(7 downto 3) <= data_write(7 downto 3);
          end if;
        end if;
      end if;

      -- interrupt acknowledgement handling
      if re_vector_old = '0' and re_vector = '1' then
        -- CPU has requested the vector,
        -- so calculate it
        if pending(0) = '1' then
          vector_int(2 downto 1) <= "00";
        elsif pending(1) = '1' then
          vector_int(2 downto 1) <= "01";
        elsif pending(2) = '1' then
          vector_int(2 downto 1) <= "10";
        else
          vector_int(2 downto 1) <= "11";
        end if;
      elsif re_vector_old = '1' and re_vector = '0' then
        -- CPU has read the vector,
        -- so the corresponding interrupt no longer pending
        case vector_int(2 downto 1) is
          when "00" =>
            pending(0) <= '0';
          when "01" =>
            pending(1) <= '0';
          when "10" =>
            pending(2) <= '0';
          when "11" =>
            pending(3) <= '0';
        end case;
      end if;
      re_vector_old <= re_vector;

      -- do counter/timer logic
      -- we count rising edges of the counter/timer inputs
      -- we rely on the CPU clock running much faster than the inputs change
      -- and this includes the timer input, which is already divided by 16
      this_count(0) := count0;
      this_count(1) := count1;
      this_count(2) := count2;
      this_count(3) := count3;
      this_zcto(0) := '0';
      this_zcto(1) := '0';
      this_zcto(2) := '0';
      this_zcto(3) := '0';
      for i in 0 to 3 loop
        if konstant_load(i) = '0' and reset_channel(i) = '0' then
          if counter_mode(i) = '1' then
            -- counter logic
            if prev_count(i) = '0' and this_count(i) = '1' then
              if counter(i) /= "00000001" then
                counter(i) <= counter(i)-1;
              else
                this_zcto(i) := '1';
                counter(i) <= konstant(i);
                if int_enabled(i) = '1' then
                  pending(i) <= '1';
                end if;
              end if;
            end if;
          else
            -- timer logic
            if prev_timer16 = '0' and timer16 = '1' then
              if prescaler(i) /= "0000" then
                prescaler(i) <= prescaler(i)-1;
              else
                if prescaler_256(i) = '1' then
                  prescaler(i) <= "1111";
                end if;
                if counter(i) /= "00000001" then
                  counter(i) <= counter(i)-1;
                else
                  this_zcto(i) := '1';
                  counter(i) <= konstant(i);
                  if int_enabled(i) = '1' then
                    pending(i) <= '1';
                  end if;
                end if;
              end if;
            end if;
          end if;
        end if;
        prev_count(i) <= this_count(i);
      end loop;
      prev_timer16 <= timer16;

      -- expose zero count / timeout pulses
      -- note that real CTC doesn't have a pin for channel 3
      zcto0 <= this_zcto(0);
      zcto1 <= this_zcto(1);
      zcto2 <= this_zcto(2);

      -- PANEL hack
      if panel_counter = "00000001" then
        panel_counter <= "00000000";
        pending(2) <= '1';
      elsif panel_counter /= "00000000" then
        panel_counter <= panel_counter-1;
      end if;
      -- end PANEL hack

    end if;

  end process;

  -- counter is there if the CPU cares to read it
  data_read <= counter(to_integer(unsigned(channel)));

  -- interrupt is asserted if any channel is pending
  interrupt <= pending(0) or pending(1) or pending(2) or pending(3);

  -- interrupt vector is there if the CPU reads it
  vector(7 downto 1) <= vector_int;

end behavior;
