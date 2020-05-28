--------------------------------------------------------------------------------
-- Overlay
--------------------------------------------------------------------------------
-- DO 10/2017
--------------------------------------------------------------------------------

--Inputs are the in0 and in1 vectors. Each characters uses 5 bits :
--0xxxx : Hex value
--10000 : Space
--1xxxx : Symbols such as : ( ) + - < > , .
--i_ and o_ are the video signals before and after the block.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY ovo IS
  GENERIC (
    COLS  : natural :=4;--32;
    LINES : natural :=6;
    RGB   : unsigned(23 DOWNTO 0) :=x"FFFFFF";
	 LChar : natural :=4);
  PORT (
    -- VGA IN
    i_r   : IN  unsigned(7 DOWNTO 0);
    i_g   : IN  unsigned(7 DOWNTO 0);
    i_b   : IN  unsigned(7 DOWNTO 0);
    i_hs  : IN  std_logic;
    i_vs  : IN  std_logic;
    i_de  : IN  std_logic;
    i_en  : IN  std_logic;
    i_clk : IN  std_logic;

    -- VGA_OUT
    o_r   : OUT unsigned(7 DOWNTO 0);
    o_g   : OUT unsigned(7 DOWNTO 0);
    o_b   : OUT unsigned(7 DOWNTO 0);
    o_hs  : OUT std_logic;
    o_vs  : OUT std_logic;
    o_de  : OUT std_logic;

    -- Control
    ena  : IN std_logic; -- Overlay ON/OFF

    -- Probes
    in0 : IN unsigned(0 TO COLS*LChar-1);
    in1 : IN unsigned(0 TO COLS*LChar-1):=(OTHERS =>'0');
    in2 : IN unsigned(0 TO COLS*LChar-1):=(OTHERS =>'0');
    in3 : IN unsigned(0 TO COLS*LChar-1):=(OTHERS =>'0');
    in4 : IN unsigned(0 TO COLS*LChar-1):=(OTHERS =>'0');
    in5 : IN unsigned(0 TO COLS*LChar-1):=(OTHERS =>'0');
    in6 : IN unsigned(0 TO COLS*LChar-1):=(OTHERS =>'0');
    in7 : IN unsigned(0 TO COLS*LChar-1):=(OTHERS =>'0')
	 
    );
END ENTITY ovo;

--##############################################################################
ARCHITECTURE rtl OF ovo IS
  TYPE arr_slv8 IS ARRAY (natural RANGE <>) OF unsigned(7 DOWNTO 0);
  CONSTANT chars : arr_slv8 :=(
    x"3E", x"63", x"73", x"7B", x"6F", x"67", x"3E", x"00",  -- 0
    x"0C", x"0E", x"0C", x"0C", x"0C", x"0C", x"3F", x"00",  -- 1
    x"1E", x"33", x"30", x"1C", x"06", x"33", x"3F", x"00",  -- 2
    x"1E", x"33", x"30", x"1C", x"30", x"33", x"1E", x"00",  -- 3
    x"38", x"3C", x"36", x"33", x"7F", x"30", x"78", x"00",  -- 4
    x"3F", x"03", x"1F", x"30", x"30", x"33", x"1E", x"00",  -- 5
    x"1C", x"06", x"03", x"1F", x"33", x"33", x"1E", x"00",  -- 6
    x"3F", x"33", x"30", x"18", x"0C", x"0C", x"0C", x"00",  -- 7
    x"1E", x"33", x"33", x"1E", x"33", x"33", x"1E", x"00",  -- 8
    x"1E", x"33", x"33", x"3E", x"30", x"18", x"0E", x"00",  -- 9
    x"0C", x"1E", x"33", x"33", x"3F", x"33", x"33", x"00",  -- A
    x"3F", x"66", x"66", x"3E", x"66", x"66", x"3F", x"00",  -- B
    x"3C", x"66", x"03", x"03", x"03", x"66", x"3C", x"00",  -- C
    x"1F", x"36", x"66", x"66", x"66", x"36", x"1F", x"00",  -- D
    x"7F", x"46", x"16", x"1E", x"16", x"46", x"7F", x"00",  -- E
    x"7F", x"46", x"16", x"1E", x"16", x"06", x"0F", x"00",  -- F
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",  --' ' 10
    x"00", x"00", x"3F", x"00", x"00", x"3F", x"00", x"00",  -- =  11
    x"00", x"0C", x"0C", x"3F", x"0C", x"0C", x"00", x"00",  -- +  12
    x"00", x"00", x"00", x"3F", x"00", x"00", x"00", x"00",  -- -  13
    x"18", x"0C", x"06", x"03", x"06", x"0C", x"18", x"00",  -- <  14
    x"06", x"0C", x"18", x"30", x"18", x"0C", x"06", x"00",  -- >  15
    x"08", x"1C", x"36", x"63", x"41", x"00", x"00", x"00",  -- ^  16
    x"08", x"1C", x"36", x"63", x"41", x"00", x"00", x"00",  -- v  17
    x"18", x"0C", x"06", x"06", x"06", x"0C", x"18", x"00",  -- (  18
    x"06", x"0C", x"18", x"18", x"18", x"0C", x"06", x"00",  -- )  19
    x"00", x"0C", x"0C", x"00", x"00", x"0C", x"0C", x"00",  -- :  1A
    x"00", x"00", x"00", x"00", x"00", x"0C", x"0C", x"00",  -- .  1B
    x"00", x"00", x"00", x"00", x"00", x"0C", x"0C", x"06",  -- ,  1C
    x"1E", x"33", x"30", x"18", x"0C", x"00", x"0C", x"00",  -- ?  1D
    x"18", x"18", x"18", x"00", x"18", x"18", x"18", x"00",  -- |  1E
    x"36", x"36", x"7F", x"36", x"7F", x"36", x"36", x"00"); -- #  1F
  SIGNAL vcpt,hcpt,hcpt2 : natural RANGE 0 TO 4095;
  SIGNAL vin0,vin1,vin2,vin3,vin4,vin5,vin6,vin7 : unsigned(0 TO COLS*LChar-1);
  SIGNAL t_r,t_g,t_b : unsigned(7 DOWNTO 0);
  SIGNAL t_hs,t_vs,t_de : std_logic;
  SIGNAL col : unsigned(7 DOWNTO 0);
  SIGNAL de : std_logic;

  SIGNAL in0s,in1s,in2s,in3s,in4s,in5s,in6s,in7s : unsigned(in0'range);
BEGIN

  in0s<=in0 WHEN rising_edge(i_clk);
  in1s<=in1 WHEN rising_edge(i_clk);
  in2s<=in2 WHEN rising_edge(i_clk);
  in3s<=in3 WHEN rising_edge(i_clk);
  in4s<=in4 WHEN rising_edge(i_clk);
  in5s<=in5 WHEN rising_edge(i_clk);
  in6s<=in6 WHEN rising_edge(i_clk);
  in7s<=in7 WHEN rising_edge(i_clk);
  
  ----------------------------------------------------------
  Megamix:PROCESS(i_clk) IS
    VARIABLE vin_v  : unsigned(0 TO COLS*LChar-1);
    VARIABLE char_v : unsigned(4 DOWNTO 0);
  BEGIN
    IF rising_edge(i_clk) THEN
      IF i_en='1' THEN
        ----------------------------------
        -- Propagate VGA signals. 2 cycles delay
        t_r<=i_r;
        t_g<=i_g;
        t_b<=i_b;
        t_hs<=i_hs;
        t_vs<=i_vs;
        t_de<=i_de;
       
        o_r<=t_r;
        o_g<=t_g;
        o_b<=t_b;
        o_hs<=t_hs;
        o_vs<=t_vs;
        o_de<=t_de;
       
        ----------------------------------
        -- Latch sampled values during vertical sync
        IF i_vs='1' THEN
          vin0<=in0s;
          vin1<=in1s;
          vin2<=in2s;
          vin3<=in3s;
          vin4<=in4s;
          vin5<=in5s;
          vin6<=in6s;
          vin7<=in7s;
        END IF;
       
        ----------------------------------
        IF i_vs='1' THEN
          vcpt<=0;
          de<='0';
        ELSIF i_hs='1' AND t_hs='0' AND de='1' THEN
          vcpt<=(vcpt+1) MOD 4096;
        END IF;
       
        ----------------------------------
--        IF (vcpt/8) MOD Lines=0 THEN
--          vin_v:=vin0;
--        ELSE
--          vin_v:=vin1;
--        END IF;

		  case ((vcpt/8) MOD Lines) is 
				when 0 => vin_v:=vin0;
				when 1 => vin_v:=vin1;
				when 2 => vin_v:=vin2;
				when 3 => vin_v:=vin3;
				when 4 => vin_v:=vin4;
				when 5 => vin_v:=vin5;
				when 6 => vin_v:=vin6;
				when 7 => vin_v:=vin7;
				when others => vin_v:=vin0;
		  end case;
       
        IF i_hs='1' THEN
          hcpt<=0;
        ELSIF i_de='1' THEN
          hcpt<=(hcpt+1) MOD 4096;
          de<='1';
        END IF;
        hcpt2<=hcpt;
       
        ----------------------------------
        -- Pick characters
        IF hcpt<COLS * 8 AND vcpt<LINES * 8 THEN
          char_v:="00000" or vin_v((hcpt/8)*LChar TO (hcpt/8)*LChar+(LChar-1));
        ELSE
          char_v:="10000"; -- " " : Blank character
        END IF;
       
        col<=chars(to_integer(char_v)*8+(vcpt MOD 8));
       
        ----------------------------------
        -- Insert Overlay
        IF ena='1' THEN
          IF col(hcpt2 MOD 8)='1' THEN
            o_r<=rgb(23 DOWNTO 16);
            o_g<=rgb(15 DOWNTO  8);
            o_b<=rgb( 7 DOWNTO  0);
          END IF;
        END IF;
      END IF;
    END IF;
  END PROCESS Megamix;
END ARCHITECTURE rtl;
