--
-- dart.vhd - Dual Asynchronous Receiver Transmitter
--
-- Useful approximation to a Z80 DART.
-- No interrupts or modem control, always 8 bit characters.
-- Upto 19200 baud is reasonable.
-- 1.5 stop bits => 2 bits on output, 1 bit on input.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dart is
  port
    (
    -- CPU
    clk_cpu : in  std_logic;
    reset   : in  std_logic;
    b_not_a : in  std_logic;
    c_not_d : in  std_logic;
    cs      : in  std_logic;
    iorq_n  : in  std_logic;
    rd_n    : in  std_logic;
    wr_n    : in  std_logic;
    data_i  : in  std_logic_vector(7 downto 0);
    stat_a  : out std_logic_vector(7 downto 0);
    data_a  : out std_logic_vector(7 downto 0);
    stat_b  : out std_logic_vector(7 downto 0);
    data_b  : out std_logic_vector(7 downto 0);
    -- from CTC, 4MHz/13/n (n=1,2,4,...)
    clk_a   : in  std_logic;
    clk_b   : in  std_logic;
    -- to/from serial ports
    rx_a    : in  std_logic;
    tx_a    : out std_logic;
    rx_b    : in  std_logic;
    tx_b    : out std_logic
    );
end dart;

architecture behavior of dart is

  function parity8(v : std_logic_vector(7 downto 0))
    return std_logic is
  begin
    return v(7) xor v(6) xor v(5) xor v(4) xor v(3) xor v(2) xor v(1) xor v(0);
  end;

  function parity9(v : std_logic_vector(8 downto 0))
    return std_logic is
  begin
    return v(8) xor v(7) xor v(6) xor v(5) xor v(4) xor v(3) xor v(2) xor v(1) xor v(0);
  end;

  type rxbuf_t is array(0 to 3) of std_logic_vector(7 downto 0);
  type channel_t is record
    regnum       : std_logic_vector(2 downto 0);
    clockmode    : std_logic_vector(1 downto 0);
    parityenable : std_logic;
    parityeven   : std_logic;
    twostop      : std_logic;
    txenable     : std_logic;
    txclks       : integer range 0 to 64-1;
    txsend       : integer range 0 to 12;
    txdata       : std_logic_vector(9 downto 0);
    rxenable     : std_logic;
    rxclks       : integer range 0 to 96-1;
    rxrecv       : integer range 0 to 10;
    rxdata       : std_logic_vector(8 downto 0);
    rxprod       : integer range 0 to 3;
    rxcons       : integer range 0 to 3;
    rxbuf        : rxbuf_t;
    framingerror : std_logic;
    parityerror  : std_logic;
    overrun      : std_logic;
    clk_ch_last  : std_logic;
    rx_history   : std_logic_vector(3 downto 0);
    rx_clean     : std_logic;
    rx_prev      : std_logic;
  end record;
  type channels_t is array (0 to 1) of channel_t;

  type bytes_t is array (0 to 1) of std_logic_vector(7 downto 0);

  signal channels : channels_t;
  signal iorq_n_prev : std_logic := '1';
 
begin

  process ( clk_cpu, reset )
    variable ch : integer range 0 to 1;
    variable txempty : std_logic;
    variable rxempty : std_logic;
    variable clk_ch : std_logic_vector(0 to 1);
    variable rx : std_logic_vector(0 to 1);
    variable tx : std_logic_vector(0 to 1);
    variable data_o : bytes_t;
    variable stat_o : bytes_t;
  begin

    clk_ch(0) := clk_a;
    clk_ch(1) := clk_b;
    rx(0)     := rx_a;
    rx(1)     := rx_b;

    if reset = '1' then
      for c in 0 to 1 loop
        channels(c).regnum       <= "000";
        channels(c).clockmode    <= "01";
        channels(c).parityenable <= '0';
        channels(c).parityeven   <= '0';
        channels(c).twostop      <= '0';
        channels(c).txenable     <= '0';
        channels(c).txclks       <= 0;
        channels(c).txsend       <= 0;
        channels(c).rxenable     <= '0';
        channels(c).rxprod       <= 0;
        channels(c).rxcons       <= 0;
        channels(c).framingerror <= '0';
        channels(c).parityerror  <= '0';
        channels(c).overrun      <= '0';
      end loop;
    elsif rising_edge(clk_cpu) then

      for c in 0 to 1 loop

        -- advertise based on current state
        data_o(c) := channels(c).rxbuf(channels(c).rxcons);
        if channels(c).txsend = 0 and channels(c).txclks = 0 then
          txempty := '1';
        else
          txempty := '0';
        end if;
        if channels(c).rxprod = channels(c).rxcons then
          rxempty := '1';
        else
          rxempty := '0';
        end if;
        case channels(c).regnum is
          when "000" => -- RR0
            stat_o(c) := "00000" & txempty & "0" & not(rxempty);
          when "001" => -- RR1
            stat_o(c) := "00" & channels(c).overrun & channels(c).parityerror & "000" & txempty;
          when others =>
            stat_o(c) := (others => '1');
        end case;

        -- try to clean up RX signal
        channels(c).rx_history <= channels(c).rx_history(2 downto 0) & rx(c);
        if channels(c).rx_history = "1111" then
          channels(c).rx_clean <= '1';
        elsif channels(c).rx_history = "0000" then
          channels(c).rx_clean <= '0';
        end if;

        -- clock serial data in or out
        if channels(c).clk_ch_last = '0' and clk_ch(c) = '1' then

          if channels(c).txenable = '1' then
            if channels(c).txclks /= 0 then
              channels(c).txclks <= channels(c).txclks-1;
            elsif channels(c).txsend /= 0 then
              tx(c) := channels(c).txdata(0);
              channels(c).txdata <= "1" & channels(c).txdata(9 downto 1);
              channels(c).txsend <= channels(c).txsend-1;
              case channels(c).clockmode is
                when "00" => channels(c).txclks <=  1-1;
                when "01" => channels(c).txclks <= 16-1;
                when "10" => channels(c).txclks <= 32-1;
                when "11" => channels(c).txclks <= 64-1;
              end case;
            else
              tx(c) := '1';
            end if;
          else
            tx(c) := '1';
          end if; -- send

          channels(c).rx_prev <= channels(c).rx_clean;
          if channels(c).rxenable = '1' then
            if channels(c).rxclks /= 0 then
              channels(c).rxclks <= channels(c).rxclks-1;
            elsif channels(c).rxrecv = 2 and channels(c).parityenable = '0' then
              -- we have 8 bits data, and should be on stop
              if channels(c).rx_clean = '0' then
                channels(c).framingerror <= '1';
              elsif channels(c).rxprod+1 = channels(c).rxcons then
                channels(c).overrun <= '1';
              else
                channels(c).rxbuf(channels(c).rxprod) <= channels(c).rxdata(8 downto 1);
                channels(c).rxprod <= channels(c).rxprod+1;
              end if;
              channels(c).rxrecv <= 0;
            elsif channels(c).rxrecv = 1 then
              -- we have 8 bits data, 1 parity, and should be on stop
              if parity9(channels(c).rxdata) = channels(c).parityeven then
                channels(c).parityerror <= '1';
              elsif channels(c).rx_clean = '0' then
                channels(c).framingerror <= '1';
              elsif channels(c).rxprod+1 = channels(c).rxcons then
                channels(c).overrun <= '1';
              else
                channels(c).rxbuf(channels(c).rxprod) <= channels(c).rxdata(7 downto 0);
                channels(c).rxprod <= channels(c).rxprod+1;
              end if;
              channels(c).rxrecv <= 0;
            elsif channels(c).rxrecv /= 0 then
              -- sample another bit
              channels(c).rxdata <= channels(c).rx_clean & channels(c).rxdata(8 downto 1);
              channels(c).rxrecv <= channels(c).rxrecv-1;
              case channels(c).clockmode is
                when "00" => channels(c).rxclks <=  1-1;
                when "01" => channels(c).rxclks <= 16-1;
                when "10" => channels(c).rxclks <= 32-1;
                when "11" => channels(c).rxclks <= 64-1;
              end case;
            else
              -- look for start bit
              if channels(c).rx_prev = '1' and channels(c).rx_clean = '0' then
                case channels(c).clockmode is
                  when "00" => channels(c).rxclks <=  1-1; -- ouch, we want 1.5
                  when "01" => channels(c).rxclks <= 24-1;
                  when "10" => channels(c).rxclks <= 48-1;
                  when "11" => channels(c).rxclks <= 96-1;
                end case;
                channels(c).rxrecv <= 10;
              end if;
            end if;
          end if; -- receive

        end if; -- clock edge
        channels(c).clk_ch_last <= clk_ch(c);
      end loop; -- each channel

      data_a <= data_o(0);
      stat_a <= stat_o(0);
      data_b <= data_o(1);
      stat_b <= stat_o(1);
      tx_a   <= tx(0);
      tx_b   <= tx(1);

      -- I/O from the CPU
      iorq_n_prev <= iorq_n;
      if cs = '1' and iorq_n_prev = '1' and iorq_n = '0' then
        if b_not_a = '1' then
          ch := 1;
        else
          ch := 0;
        end if;
        if rd_n = '0' then
          -- CPU will sample data we already advertised above
          -- we only have to handle side effects of the read here
          if c_not_d = '1' then
            channels(ch).regnum <= "000";
          elsif channels(ch).rxcons /= channels(ch).rxprod then
            channels(ch).rxcons <= channels(ch).rxcons+1;
          end if;
        elsif wr_n = '0' then
          if c_not_d = '1' then
            case channels(ch).regnum is
              when "000" => -- WR0
                case data_i(5 downto 3) is
                  when "011" => -- channel reset
                    channels(ch).regnum       <= "000"; -- can't set regnum when doing channel reset
                    channels(ch).clockmode    <= "01";
                    channels(ch).parityenable <= '0';
                    channels(ch).parityeven   <= '0';
                    channels(ch).twostop      <= '0';
                    channels(ch).txenable     <= '0';
                    channels(ch).txclks       <= 0;
                    channels(ch).txsend       <= 0;
                    channels(ch).rxenable     <= '0';
                    channels(ch).rxprod       <= 0;
                    channels(ch).rxcons       <= 0;
                    channels(ch).framingerror <= '0';
                    channels(ch).parityerror  <= '0';
                    channels(ch).overrun      <= '0';
                  when "110" => -- error reset
                    channels(ch).framingerror <= '0';
                    channels(ch).parityerror  <= '0';
                    channels(ch).overrun      <= '0';
                    channels(ch).regnum       <= data_i(2 downto 0);
                  when others =>
                    channels(ch).regnum       <= data_i(2 downto 0);
                end case;
              when "011" => -- WR3
                channels(ch).rxenable <= data_i(0);
                channels(ch).regnum   <= "000";
              when "100" => -- WR4
                channels(ch).parityenable <= data_i(0);
                channels(ch).parityeven   <= data_i(1);
                channels(ch).twostop      <= data_i(3); -- 00 or 01 => 1, 10 or 11 => 2
                channels(ch).clockmode    <= data_i(7 downto 6);
                channels(ch).regnum       <= "000";
              when "101" => -- WR5
                channels(ch).txenable <= data_i(3);
                channels(ch).regnum   <= "000";
              when others =>
                channels(ch).regnum <= "000";
            end case;
          else
            channels(ch).txdata <= ( (parity8(data_i) xnor channels(ch).parityeven) or
                                     not channels(ch).parityenable )
                                 & data_i
                                 & "0";
            case std_logic_vector'(channels(ch).parityenable & channels(ch).twostop) is
              when "00" => channels(ch).txsend <= 10;
              when "01" => channels(ch).txsend <= 11;
              when "10" => channels(ch).txsend <= 11;
              when "11" => channels(ch).txsend <= 12;
            end case;
          end if;
        end if;
      end if;

    end if;

  end process;

end behavior;
