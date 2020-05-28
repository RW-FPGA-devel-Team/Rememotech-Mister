--
-- accelerator.vhd - Numeric accelerator
--
-- Understands 32 bit integers, unsigned or signed.
-- Understands MTX style floating point of the form (-1)^s x 1.m x 2^(e-129)
--   s is sign, 0 for +ve and 1 for -ve
--   m is mantissa, 31 bits, corresponding to 2^-1 to 2^-31
--   e is exponent, range 1 to 255, corresponding to 2^-128 to 2^126
--   s=m=e=0 represents zero, although in fact e=0 is enough
-- Looking the scan of MTX ROM listing
--   MTXROM_035_096.pdf
--     p15 has numeric format
--     p44 has some constants, for sin
--   MTXROM_255_300.pdf
--     p24 has some maths routines
--     p28 has some constants, for atn, log, exp
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity accelerator is
  port
    (
    enabled  : in    std_logic;
    RESET    : in    std_logic; 
    PHI      : in    std_logic;
    IORQ_n   : in    std_logic;
    RD_n     : in    std_logic;
    WR_n     : in    std_logic;
    A        : in    std_logic_vector(7 downto 0);
    DI       : in    std_logic_vector(7 downto 0);
    DO       : out   std_logic_vector(7 downto 0);
    DO_valid : out   std_logic
    );
end accelerator;

architecture behavior of accelerator is

  signal prev_IO : std_logic_vector(1 downto 0) := "00";

  -- stack
  signal tos : std_logic_vector(39 downto 0);
  signal nos : std_logic_vector(39 downto 0);
  constant stack_size : natural := 8;
  type stack_t is array (0 to stack_size-1) of std_logic_vector(39 downto 0);
  signal stack : stack_t;
  signal stack_pointer : integer range 0 to stack_size := 0;

  -- multiplication and division related
  signal neg_flag : std_logic;

  function neg(v : std_logic_vector)
    return std_logic_vector is
  begin
    return std_logic_vector( -signed(v) );
  end;

  function neg_if(v : std_logic_vector; flag : std_logic)
    return std_logic_vector is
  begin
    if flag = '1' then
      return neg(v);
    else
      return v;
    end if;
  end;

  -- multiplication related
  signal product : std_logic_vector(63 downto 0);

  -- division related
  signal numerator   : std_logic_vector(64 downto 0);
  signal denominator : std_logic_vector(64 downto 0);
  signal scale       : std_logic_vector(33 downto 0);
  signal quotient    : std_logic_vector(33 downto 0);
  signal divided     : std_logic;

  -- state machine
  constant S_IDLE    : natural := 0;
  constant S_MUL     : natural := 1;
  constant S_DIV     : natural := 2;
  constant S_MOD     : natural := 3;
  constant S_FMUL    : natural := 4;
  constant S_FDIV    : natural := 5;
  constant S_POP_NOS : natural := 6;

  -- commands
  constant C_INIT : std_logic_vector(7 downto 0) := x"00";
  constant C_LIT  : std_logic_vector(7 downto 0) := x"01";
  constant C_DUP  : std_logic_vector(7 downto 0) := x"02";
  constant C_DROP : std_logic_vector(7 downto 0) := x"03";
  constant C_SWAP : std_logic_vector(7 downto 0) := x"04";
  constant C_OVER : std_logic_vector(7 downto 0) := x"05";
  constant C_OK   : std_logic_vector(7 downto 0) := x"06";
  constant C_1    : std_logic_vector(7 downto 0) := x"10";
  constant C_INEG : std_logic_vector(7 downto 0) := x"20";
  constant C_INOT : std_logic_vector(7 downto 0) := x"21";
  constant C_ILSL : std_logic_vector(7 downto 0) := x"22";
  constant C_ILSR : std_logic_vector(7 downto 0) := x"23";
  constant C_IASR : std_logic_vector(7 downto 0) := x"24";
  constant C_IABS : std_logic_vector(7 downto 0) := x"25";
  constant C_ISGN : std_logic_vector(7 downto 0) := x"26";
  constant C_IADD : std_logic_vector(7 downto 0) := x"30";
  constant C_ISUB : std_logic_vector(7 downto 0) := x"31";
  constant C_UMUL : std_logic_vector(7 downto 0) := x"32";
  constant C_SMUL : std_logic_vector(7 downto 0) := x"33";
  constant C_UDIV : std_logic_vector(7 downto 0) := x"34";
  constant C_SDIV : std_logic_vector(7 downto 0) := x"35";
  constant C_UMOD : std_logic_vector(7 downto 0) := x"36";
  constant C_SMOD : std_logic_vector(7 downto 0) := x"37";
  constant C_HMUL : std_logic_vector(7 downto 0) := x"38";
  constant C_1P0  : std_logic_vector(7 downto 0) := x"40";
  constant C_2P0  : std_logic_vector(7 downto 0) := x"41";
  constant C_10P0 : std_logic_vector(7 downto 0) := x"42";
  constant C_PI   : std_logic_vector(7 downto 0) := x"43";
  constant C_PI2  : std_logic_vector(7 downto 0) := x"44";
  constant C_2PI  : std_logic_vector(7 downto 0) := x"45";
  constant C_R2   : std_logic_vector(7 downto 0) := x"46";
  constant C_R3   : std_logic_vector(7 downto 0) := x"47";
  constant C_R5   : std_logic_vector(7 downto 0) := x"48";
  constant C_R7   : std_logic_vector(7 downto 0) := x"49";
  constant C_R9   : std_logic_vector(7 downto 0) := x"4A";
  constant C_R11  : std_logic_vector(7 downto 0) := x"4B";
  constant C_R13  : std_logic_vector(7 downto 0) := x"4C";
  constant C_R15  : std_logic_vector(7 downto 0) := x"4D";
  constant C_R17  : std_logic_vector(7 downto 0) := x"4E";
  constant C_R3F  : std_logic_vector(7 downto 0) := x"4F";
  constant C_R4F  : std_logic_vector(7 downto 0) := x"50";
  constant C_R5F  : std_logic_vector(7 downto 0) := x"51";
  constant C_R6F  : std_logic_vector(7 downto 0) := x"52";
  constant C_R7F  : std_logic_vector(7 downto 0) := x"53";
  constant C_R8F  : std_logic_vector(7 downto 0) := x"54";
  constant C_R9F  : std_logic_vector(7 downto 0) := x"55";
  constant C_R11F : std_logic_vector(7 downto 0) := x"56";
  constant C_R13F : std_logic_vector(7 downto 0) := x"57";
  constant C_L2E  : std_logic_vector(7 downto 0) := x"58";
  constant C_LE2  : std_logic_vector(7 downto 0) := x"59";
  constant C_FNEG : std_logic_vector(7 downto 0) := x"60";
  constant C_FABS : std_logic_vector(7 downto 0) := x"61";
  constant C_FSGN : std_logic_vector(7 downto 0) := x"62";
  constant C_FINT : std_logic_vector(7 downto 0) := x"63";
  constant C_FADD : std_logic_vector(7 downto 0) := x"70";
  constant C_FSUB : std_logic_vector(7 downto 0) := x"71";
  constant C_FMUL : std_logic_vector(7 downto 0) := x"72";
  constant C_FDIV : std_logic_vector(7 downto 0) := x"73";
  constant C_UTOF : std_logic_vector(7 downto 0) := x"80";
  constant C_FTOU : std_logic_vector(7 downto 0) := x"81";

  -- result
  constant R_BUSY  : natural := 0;
  constant R_OK    : natural := 1;
  constant R_DIV0  : natural := 2;
  constant R_OVER  : natural := 3;
  constant R_UNDR  : natural := 4;

  signal state  : natural range 0 to 6; -- S_ value
  signal result : natural range 1 to 4; -- R_ value

  function denormalize(n : std_logic_vector; shift : unsigned)
    return std_logic_vector is
  begin
    if shift < n'length then
      return std_logic_vector( shift_right( unsigned(n), to_integer(shift) ) );
    else
      return std_logic_vector( to_unsigned(0, n'length) );
    end if;
  end;

  function leading_zeroes32( bits : std_logic_vector(0 to 31) )
    return unsigned is
  begin
    for i in 0 to 31 loop
      if bits(i) = '1' then
        return to_unsigned(i,5);
      end if;
    end loop;
    return to_unsigned(0,5); -- never happens
  end;

  function leading_zeroes64( bits : std_logic_vector(0 to 63) )
    return unsigned is
  begin
    for i in 0 to 63 loop
      if bits(i) = '1' then
        return to_unsigned(i,6);
      end if;
    end loop;
    return to_unsigned(0,6); -- never happens
  end;

begin

  process ( PHI, RESET )

    -- multiplication related
    variable mulop1 : std_logic_vector(31 downto 0);
    variable mulop2 : std_logic_vector(31 downto 0);

    -- addition and subtraction related
    variable nose : unsigned(7 downto 0);          -- nos exponent
    variable tose : unsigned(7 downto 0);          -- tos exponent
    variable sume : unsigned(9 downto 0);          -- result exponent
    variable noss : std_logic;                     -- nos sign
    variable toss : std_logic;                     -- tos sign
    variable nosm : std_logic_vector(63 downto 0); -- nos mantissa
    variable tosm : std_logic_vector(63 downto 0); -- tos mantissa
    variable summ : std_logic_vector(64 downto 0); -- result mantissa
    variable lz6  : unsigned(5 downto 0);

    -- conversion related
    variable mask : signed(31 downto 0);
    variable val  : std_logic_vector(31 downto 0);
    variable lz5  : unsigned(4 downto 0);

  begin
    if rising_edge(PHI) then
      if RESET = '1' then
        stack_pointer <= 0;
        state         <= S_IDLE;
        result        <= R_OK;
      else

        -- one step of the divide algorithm
        if divided = '0' and numerator >= denominator then
          numerator <= numerator - denominator;
          quotient  <= quotient or scale;
        end if;
        denominator <= "0" & denominator(64 downto 1);
        scale       <= "0" & scale      (33 downto 1);
        divided     <= divided or scale(0);

        -- continue processing of existing multi-step operations
        case state is
          when S_IDLE =>

          when S_MUL =>
            tos(31 downto 0) <= neg_if( product(31 downto 0), neg_flag );
            state            <= S_POP_NOS;

          when S_DIV =>
            if divided = '1' then
              tos(31 downto 0) <= neg_if( quotient(31 downto 0), neg_flag );
              state            <= S_POP_NOS;
            end if;

          when S_MOD =>
            if divided = '1' then
              tos(31 downto 0) <= neg_if( numerator(31 downto 0), neg_flag );
              state            <= S_POP_NOS;
            end if;

          when S_FMUL =>
            nose := unsigned( nos(39 downto 32) );
            tose := unsigned( tos(39 downto 32) );
            sume := ( "00" & nose ) + ( "00" & tose ) - x"81";
            -- sume in range 1..255 + 1.255 - 129 = -127..383
            summ(64 downto 30) := "0" & product(63 downto 30);
            if summ(63) = '1' then
              sume := sume + 1;
            else
              summ(63 downto 31) := summ(62 downto 30);
            end if;
            -- round
            summ(64 downto 32) := summ(64 downto 32) + summ(31);
            if summ(64) = '1' then
              -- overflow
              sume               := sume + 1;
              summ(63 downto 32) := summ(64 downto 33);
            end if;
            tos(39 downto 32) <= std_logic_vector( sume(7 downto 0) );
            tos(31)           <= tos(31) xor nos(31);
            tos(30 downto  0) <= summ(62 downto 32);
            if sume = "0000000000" or sume(9) = '1' then
              result <= R_UNDR;
            elsif sume(8) = '1' then
              result <= R_OVER;
            end if;
            state <= S_POP_NOS;

          when S_FDIV =>
            if divided = '1' then
              nose := unsigned( nos(39 downto 32) );
              tose := unsigned( tos(39 downto 32) );
              sume := ( "00" & nose ) - ( "00" & tose ) + x"81";
              summ(64 downto 30) := "0" & quotient(33 downto 0);
              if summ(63) = '0' then
                sume := sume - 1;
                summ(63 downto 31) := summ(62 downto 30);
              end if;
              -- round
              summ(64 downto 32) := summ(64 downto 32) + summ(31);
              if summ(64) = '1' then
                -- overflow
                sume               := sume + 1;
                summ(63 downto 32) := summ(64 downto 33);
              end if;
              tos(39 downto 32) <= std_logic_vector( sume(7 downto 0) );
              tos(31)           <= tos(31) xor nos(31);
              tos(30 downto  0) <= summ(62 downto 32);
              if sume = "0000000000" or sume(9) = '1' then
                result <= R_UNDR;
              elsif sume(8) = '1' then
                result <= R_OVER;
              end if;
              state <= S_POP_NOS;
            end if;

          -- this is used at the end of most binary operations
          when S_POP_NOS =>
            nos           <= stack(stack_pointer-1);
            stack_pointer <= stack_pointer-1;
            state         <= S_IDLE;

          when others =>
        end case;

        -- IO write
        prev_IO <= "0" & prev_io(1);
        if WR_n = '0' and IORQ_n = '0' and prev_IO = "00" then
          prev_IO <= "11"; -- suppress IO write on next two cycles
          case A is

            -- set tos
            when x"A0" =>
              tos(7  downto  0) <= DI;
            when x"A1" =>
              tos(15 downto  8) <= DI;
            when x"A2" =>
              tos(23 downto 16) <= DI;
            when x"A3" =>
              tos(31 downto 24) <= DI;
            when x"A4" =>
              tos(39 downto 32) <= DI;

            -- perform arithmetic operation
            when x"A5" =>
              case DI is

                -- control
                when C_INIT =>
                  -- reset to initial state
                  stack_pointer <= 0;
                  result        <= R_OK;
                  state         <= S_IDLE;
                when C_LIT =>
                  -- new literal on stack, initial value zero
                  -- both integer 0 and float 0.0 have the same representation
                  stack(stack_pointer) <= nos;
                  stack_pointer        <= stack_pointer+1;
                  nos                  <= tos;
                  tos                  <= x"0000000000";
                when C_DUP =>
                  stack(stack_pointer) <= nos;
                  stack_pointer        <= stack_pointer+1;
                  nos                  <= tos;
                when C_DROP =>
                  tos                  <= nos;
                  state                <= S_POP_NOS;
                when C_SWAP =>
                  nos                  <= tos;
                  tos                  <= nos;
                when C_OVER =>
                  stack(stack_pointer) <= nos;
                  stack_pointer        <= stack_pointer+1;
                  nos                  <= tos;
                  tos                  <= nos;
                when C_OK =>
                  result <= R_OK;

                -- set tos to integer literal values
                when C_1 =>
                  tos <= x"0000000001"; -- = 1

                -- integer unary operations
                when C_INEG =>
                  tos(31 downto 0) <= neg( tos(31 downto 0) );
                when C_INOT =>
                  tos(31 downto 0) <= not tos(31 downto 0);
                when C_ILSL =>
                  tos(31 downto 0) <= tos(30 downto 0) & "0";
                when C_ILSR =>
                  tos(31 downto 0) <= "0" & tos(31 downto 1);
                when C_IASR =>
                  tos(30 downto 0) <= tos(31 downto 1);
                when C_IABS =>
                  tos(31 downto 0) <= neg_if( tos(31 downto 0), tos(31) );
                when C_ISGN =>
                  if tos(31 downto 0) = x"00000000" then
                    -- no change
                  elsif tos(31) = '0' then
                    tos(31 downto 0) <= x"00000001";
                  else
                    tos(31 downto 0) <= x"ffffffff";
                  end if;

                -- integer binary operations
                when C_IADD =>
                  tos           <= nos + tos;
                  state         <= S_POP_NOS;
                when C_ISUB =>
                  tos           <= nos - tos;
                  state         <= S_POP_NOS;
                when C_UMUL =>
                  -- umul
                  mulop1        := tos(31 downto 0);
                  mulop2        := nos(31 downto 0);
                  neg_flag      <= '0';
                  state         <= S_MUL;
                when C_SMUL =>
                  -- the low part of the result matches unsigned multiply
                  -- the high part of the result differs though
                  mulop1        := neg_if( nos(31 downto 0), nos(31) );
                  mulop2        := neg_if( tos(31 downto 0), tos(31) );
                  neg_flag      <= nos(31) xor tos(31);
                  state         <= S_MUL;
                when C_UDIV =>
                  if tos(31 downto 0) = x"00000000" then
                    -- x/0 = 0 with /0 result
                    result        <= R_DIV0;
                    state         <= S_POP_NOS;
                  else
                    numerator     <= "0" & x"00000000" & nos(31 downto 0);
                    denominator   <= "0" & tos(31 downto 0) & x"00000000";
                    scale         <= "01" & x"00000000";
                    quotient      <= "00" & x"00000000";
                    neg_flag      <= '0';
                    divided       <= '0';
                    state         <= S_DIV;
                  end if;
                when C_SDIV =>
                  if tos(31 downto 0) = x"00000000" then
                    result        <= R_DIV0;
                    state         <= S_POP_NOS;
                  else
                    numerator     <= "0" & x"00000000" & neg_if( nos(31 downto 0), nos(31) );
                    denominator   <= "0" & neg_if( tos(31 downto 0), tos(31) ) & x"00000000";
                    scale         <= "01" & x"00000000";
                    quotient      <= "00" & x"00000000";
                    neg_flag      <= nos(31) xor tos(31);
                    divided       <= '0';
                    state         <= S_DIV;
                  end if;
                when C_UMOD =>
                  if tos(31 downto 0) = x"00000000" then
                    result <= R_DIV0;
                    state  <= S_POP_NOS;
                  else
                    numerator     <= "0" & x"00000000" & nos(31 downto 0);
                    denominator   <= "0" & tos(31 downto 0) & x"00000000";
                    scale         <= "01" & x"00000000";
                    quotient      <= "00" & x"00000000";
                    neg_flag      <= '0';
                    divided       <= '0';
                    state         <= S_MOD;
                  end if;
                when C_SMOD =>
                  -- sign of modulus reflects dividend
                  -- see http://en.wikipedia.org/wiki/Modulo_operation
                  if tos(31 downto 0) = x"00000000" then
                    result <= R_DIV0;
                    state  <= S_POP_NOS;
                  else
                    numerator     <= "0" & x"00000000" & neg_if( nos(31 downto 0), nos(31) );
                    denominator   <= "0" & neg_if( tos(31 downto 0), tos(31) ) & x"00000000";
                    scale         <= "01" & x"00000000";
                    quotient      <= "00" & x"00000000";
                    neg_flag      <= nos(31);
                    divided       <= '0';
                    state         <= S_MOD;
                  end if;
                when C_HMUL =>
                  -- access high part of multiply result
                  stack(stack_pointer) <= nos;
                  stack_pointer        <= stack_pointer+1;
                  nos                  <= tos;
                  tos                  <= x"00" & product(63 downto 32);

                -- set tos to float literal values
                -- costs 1% of chip flip-flops, LUTs, occupied slices
                when C_1P0 =>
                  tos <= x"8100000000"; -- 1.0
                when C_2P0 =>
                  tos <= x"8200000000"; -- 2.0
                when C_10P0 =>
                  tos <= x"8420000000"; -- 10.0
                when C_PI =>
                  tos <= x"82490FDAA2"; -- pi
                when C_PI2 =>
                  tos <= x"81490FDAA2"; -- pi/2
                when C_2PI =>
                  tos <= x"83490FDAA2"; -- 2pi
                when C_R2 =>
                  tos <= x"8000000000"; -- 1/2
                when C_R3 =>
                  tos <= x"7F2AAAAAAA"; -- 1/3 
                when C_R5 =>
                  tos <= x"7E4CCCCCCD"; -- 1/5 
                when C_R7 =>
                  tos <= x"7E12492492"; -- 1/7 
                when C_R9 =>
                  tos <= x"7D638E38E4"; -- 1/9 
                when C_R11 =>
                  tos <= x"7D3A2E8BA3"; -- 1/11
                when C_R13 =>
                  tos <= x"7D1D89D89E"; -- 1/13
                when C_R15 =>
                  tos <= x"7D08888889"; -- 1/15
                when C_R17 =>
                  tos <= x"7D70F0F0F1"; -- 1/17
                when C_R3F =>
                  tos <= x"7E2AAAAAAB"; -- 1/3!
                when C_R4F =>
                  tos <= x"7C2AAAAAAB"; -- 1/4!
                when C_R5F =>
                  tos <= x"7A08888889"; -- 1/5!
                when C_R6F =>
                  tos <= x"77360B60B6"; -- 1/6!
                when C_R7F =>
                  tos <= x"74300D00D0"; -- 1/7!
                when C_R8F =>
                  tos <= x"71500D00D0"; -- 1/8!
                when C_R9F =>
                  tos <= x"6E38EF1D2B"; -- 1/9!
                when C_R11F =>
                  tos <= x"6737322B40"; -- 1/11!
                when C_R13F =>
                  tos <= x"603092309D"; -- 1/13!
                when C_L2E =>
                  tos <= x"8138AA3B29"; -- log2(e)
                when C_LE2 =>
                  tos <= x"80317217F8"; -- loge(2)

                -- floating point unary operations
                when C_FNEG =>
                  if tos(39 downto 32) /= x"00" then
                    tos(31) <= not tos(31);
                  end if;
                when C_FABS =>
                  tos(31) <= '0';
                when C_FSGN =>
                  if tos(39 downto 32) = x"00" then
                    -- no change
                  elsif tos(31) = '0' then
                    tos(39 downto 0) <= x"8100000000";
                  else
                    tos(39 downto 0) <= x"8180000000";
                  end if;
                when C_FINT =>
                  -- keep integer part only
                  if tos(39 downto 32) = x"00" then
                    -- already all zeroes
                  elsif tos(39 downto 32) < x"81" then
                    -- less than 1, so answer is 0
                    tos <= x"0000000000";
                  elsif tos(39 downto 32) < x"81"+31 then
                    mask := x"80000000"; -- this is signed
                    mask := shift_right( mask, to_integer( unsigned( tos(39 downto 32) - x"81" ) ) );
                    tos(30 downto 0) <= tos(30 downto 0) and std_logic_vector(mask(30 downto 0));
                  else
                    -- already no fractional part
                  end if;

                -- floating point binary operations
                when C_FADD | C_FSUB =>
                  -- note: C_FADD must be even and C_FSUB must be odd
                  if tos(39 downto 32) = x"00" then
                    -- nos+0 = nos
                    -- nos-0 = nos
                    tos <= nos;
                  elsif nos(39 downto 32) = x"00" then
                    -- 0+tos =  tos
                    -- 0-tos = -tos
                    tos(31) <= tos(31) xor DI(0);
                  else
                    -- determine largest exponent and align mantissi
                    nose := unsigned( nos(39 downto 32) );
                    tose := unsigned( tos(39 downto 32) );
                    noss := nos(31);
                    toss := tos(31) xor DI(0);
                    nosm := "1" & nos(30 downto 0) & x"00000000";
                    tosm := "1" & tos(30 downto 0) & x"00000000";
                    if tose >= nose then
                      sume := "00" & tose;
                      nosm := denormalize( nosm, tose-nose );
                    else
                      sume := "00" & nose;
                      tosm := denormalize( tosm, nose-tose );
                    end if;
                    if noss = toss then
                      -- signs the same, so add mantissi
                      summ := ( "0"&nosm ) + ( "0"&tosm );
                      -- round up
                      summ(64 downto 32) := summ(64 downto 32) + summ(31);
                      if summ(64) = '1' then
                        -- overflow
                        sume               := sume + 1;
                        summ(63 downto 32) := summ(64 downto 33);
                      end if;
                      tos(39 downto 32) <= std_logic_vector( sume(7 downto 0) );
                      tos(31)           <= toss;
                      tos(30 downto  0) <= summ(62 downto 32);
                      if sume(8) = '1' then
                        result <= R_OVER;
                      end if;
                    else
                      -- signs different, so difference mantissi
                      if nosm = tosm then
                        tos <= x"0000000000";
                      else
                        if nosm >= tosm then
                          summ := "0" & ( nosm - tosm );
                          tos(31) <= noss;
                        else
                          summ := "0" & ( tosm - nosm );
                          tos(31) <= toss;
                        end if;
                        -- renormalise
                        lz6 := leading_zeroes64(summ(63 downto 0));
                        sume := sume - lz6; -- could now be 0 or less
                        summ := std_logic_vector( shift_left( unsigned(summ), to_integer(lz6) ) );
                        -- round up
                        summ(64 downto 32) := summ(64 downto 32) + summ(31);
                        tos(39 downto 32) <= std_logic_vector( sume(7 downto 0) );
                        tos(30 downto  0) <= summ(62 downto 32);
                      end if;
                      if sume = "0000000000" or sume(9) = '1' then
                        result <= R_UNDR;
                      end if;
                    end if;
                  end if;
                  state <= S_POP_NOS;
                when C_FMUL =>
                  if nos(39 downto 32) = x"00" or tos(39 downto 32) = x"00" then
                    tos   <= x"0000000000";
                    state <= S_POP_NOS;
                  else
                    mulop1 := "1" & nos(30 downto 0);
                    mulop2 := "1" & tos(30 downto 0);
                    state  <= S_FMUL;
                  end if;
                when C_FDIV =>
                  if tos(39 downto 32) = x"00" then
                    result <= R_DIV0;
                    state  <= S_POP_NOS;
                  elsif nos(39 downto 32) = x"00" then
                    tos   <= x"0000000000";
                    state <= S_POP_NOS;
                  else
                    numerator   <= "1" & nos(30 downto 0) & "0" & x"00000000";
                    denominator <= "1" & tos(30 downto 0) & "0" & x"00000000";
                    scale       <= "10" & x"00000000";
                    quotient    <= "00" & x"00000000";
                    divided     <= '0';
                    state       <= S_FDIV;
                  end if;

                -- conversion related
                when C_UTOF =>
                  if tos(31 downto 0) = x"00000000" then
                    tos(39 downto 32) <= x"00";
                  else
                    lz5 := leading_zeroes32( tos(31 downto 0) );
                    tos(39 downto 32) <= std_logic_vector( x"81" + 31 - lz5 );
                    tos(31          ) <= '0';
                    tos(30 downto  0) <= std_logic_vector( shift_left( unsigned( tos(30 downto 0) ), to_integer(lz5) ) );
                  end if;
                when C_FTOU =>
                  if tos(39 downto 32) = x"00" then
                    -- already all zeroes
                  elsif tos(31) = '1' then
                    result <= R_UNDR;
                  elsif tos(39 downto 32) < x"81" then
                    tos(39 downto 0) <= x"0000000000";
                  elsif tos(39 downto 32) > x"81" + 31 then
                    result <= R_OVER;
                  else
                    val := "1" & tos(30 downto 0);
                    val := std_logic_vector( shift_right( unsigned(val), to_integer( x"81" + 31 - unsigned( tos(39 downto 32) ) ) ) );
                    tos(39 downto 32) <= x"00";
                    tos(31 downto  0) <= val;
                  end if;

                when others =>
              end case;
            when others =>
          end case;
        end if;

        product <= mulop1 * mulop2;

      end if; -- not reset
    end if; -- rising_edge(PHI)

  end process;

  -- are we supplying data
  DO_valid <= '1'
    when ( RD_n = '0' and IORQ_n = '0' and enabled = '1' and
           ( A = x"A0" or
             A = x"A1" or
             A = x"A2" or
             A = x"A3" or
             A = x"A4" or
             A = x"A5"
           )
         )
  else '0';

  -- what value are we supplying
  DO <= tos( 7 downto  0)
    when ( RD_n = '0' and IORQ_n = '0' and A = x"A0" )
  else tos(15 downto 8)
    when ( RD_n = '0' and IORQ_n = '0' and A = x"A1" )
  else tos(23 downto 16)
    when ( RD_n = '0' and IORQ_n = '0' and A = x"A2" )
  else tos(31 downto 24)
    when ( RD_n = '0' and IORQ_n = '0' and A = x"A3" )
  else tos(39 downto 32)
    when ( RD_n = '0' and IORQ_n = '0' and A = x"A4" )
  else std_logic_vector(to_unsigned(R_BUSY, 8))
    when ( RD_n = '0' and IORQ_n = '0' and A = x"A5" and state /= S_IDLE )
  else std_logic_vector(to_unsigned(result, 8))
    when ( RD_n = '0' and IORQ_n = '0' and A = x"A5" and state  = S_IDLE )

  else "XXXXXXXX";

end behavior;
