//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	
	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);




///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
//assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;

assign AUDIO_S = 0;//status[11];
assign AUDIO_L = {AudioOut,8'b0};
assign AUDIO_R = {AudioOut,8'b0};
assign AUDIO_MIX = 0;//status[10:9];

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

assign VIDEO_ARX = status[1] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[1] ? 8'd9  : 8'd3; 

`include "build_id.v" 
localparam CONF_STR = {
	"Rememotech;;",
	"-;",
	"S,VHD;",
	"OE,Reset after Mount,No,Yes;",
	"-;",
	"OB,SDHC, No, Yes;",
	"O4,Video Out,80Col,VDP;",
	"O1,Aspect ratio,4:3,16:9;",
	"O2,PAL,Normal,Marat;",
	"O3,Hz,60,50;",
	"O57,Cpu Mzh,12.5,12.5,8.333,6.25,5,4.166,3.571,3.125;",
   "O8,OSD DEBUG,Yes,No;",
//	"O9A,AudioMix,No, 25%, 50%, 100%-Mono;",
//	"O7,OSD DEBUG Enable,Yes,No;",
//	"O8,Negate Blanks,No,Yes;",
	"-;",
	"-;",
	"T0,Reset;",
	"R0,Reset and close OSD;",
	"V,v",`BUILD_DATE 
};

      // 000 => 25.000MHz
      // 001 => 12.500MHz
      // 010 =>  8.333MHz
      // 011 =>  6.250MHz
      // 100 =>  5.000MHz
      // 101 =>  4.166MHz
      // 110 =>  3.571MHz
      // 111 =>  3.125MHz

wire forced_scandoubler;
wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;


//Intento vhd
wire [31:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;
wire        sd_ack_conf;





hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),
	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
//	.status_menumask({status[5]}),


//Intento vhd
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_ack_conf(sd_ack_conf),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),
	.ioctl_wait(0),
	

	
	.ps2_key(ps2_key),

	.ps2_kbd_clk_out(Ps2_Clk),
	.ps2_kbd_data_out(Ps2_Dat)
	
	
);


///////////////////////   CLOCKS   ///////////////////////////////

wire clk_25Mhz, clk_200Mhz,clk_100Mhz;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_25Mhz),
	.outclk_1(clk_200Mhz),
	.outclk_2(clk_100Mhz)
);

//Intento VHD
//wire reset = RESET | status[0] | buttons[1];
wire reset = RESET | status[0] | buttons[1] | (status[14] && img_mounted);

//////////////////   SD   ///////////////////

wire sdclk;
wire sdmosi;
wire sdmiso = vsd_sel ? vsdmiso : SD_MISO;
wire sdss;

reg vsd_sel = 0;
always @(posedge clk_sys) if(img_mounted) vsd_sel <= |img_size;

wire vsdmiso;
sd_card sd_card
(
	.*,
	.clk_sys(CLK_50M),
	.clk_spi(clk_100Mhz),//(clk_250Mhz),
	.sdhc(status[11]),
	.sck(sdclk),
	.ss(sdss | ~vsd_sel),
	.mosi(sdmosi),
	.miso(vsdmiso)
);

assign SD_CS   = sdss   |  vsd_sel;
assign SD_SCK  = sdclk  & ~vsd_sel;
assign SD_MOSI = sdmosi & ~vsd_sel;


//Para el Led -> TODO
//reg sd_act;
//
//always @(posedge clk_sys) begin
//	reg old_mosi, old_miso;
//	integer timeout = 0;
//
//	old_mosi <= sdmosi;
//	old_miso <= sdmiso;
//
//	sd_act <= 0;
//	if(timeout < 1000000) begin
//		timeout <= timeout + 1;
//		sd_act <= 1;
//	end
//
//	if((old_mosi ^ sdmosi) || (old_miso ^ sdmiso)) timeout <= 0;
//end






//////////////////////////////////////////////////////////////////

//wire [1:0] col = status[4:3];

wire [3:0] r,g,b;
wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire Ps2_Clk, Ps2_Dat;
wire  [2:0] CpuSpeed;



assign CpuSpeed = (status[7:5]==3'b0) ? 3'b001:status[7:5]; //Si 000(25Mzh) -> 001(12,5 Mz) 25 no arranca.

rememotech rememotech
    (
    .CLOCK_50              (CLK_50M),//(clk),//(status[9]),//(CLK_50M),
    //Mister Drived by Bram Memory // 256Kx16bit 10ns SRAM
    //.SRAM_CE_N           (SRAM_CE_N),
    //.SRAM_ADDR           (SRAM_ADDR),
    //.SRAM_LB_N           (SRAM_LB_N),
    //.SRAM_UB_N           (SRAM_UB_N),
    //.SRAM_OE_N           (SRAM_OE_N),
    //.SRAM_WE_N           (SRAM_WE_N),
    //.SRAM_DQ             (SRAM_DQ),
    // SD card

//Intento VHD
//    .SD_CLK              (SD_SCK),
//    .SD_CMD              (SD_MOSI),
//    .SD_DAT              (SD_MISO),
//    .SD_DAT3             (SD_CS),
    .SD_CLK              (sdclk),
    .SD_CMD              (sdmosi),
    .SD_DAT              (sdmiso),
    .SD_DAT3             (sdss),


    // PS/2 keyboard
    .PS2_CLK             (Ps2_Clk),
    .PS2_DAT             (Ps2_Dat),
    // switches
    //.SW                  (10'b0001010000), //Forzamos monitor(6), Pal normal-60Hz(5:4), y sin externalrom(1:0)
	 .SW                  ({CpuSpeed,status[4],status[2],~status[3],2'b0,2'b0}), //Forzamos monitor(6), Pal normal-60Hz(5:4), y sin externalrom(1:0)
    // key switches
    .KEY                 ({reset,3'b111}),
    // LEDs
    //.LEDR                (),
    //.LEDG                (),
    // VGA output
    .VGA_R               (r),
    .VGA_G               (g),
    .VGA_B               (b),
    .VGA_HS              (HSync),
    .VGA_VS              (VSync),
	 .VGA_HB					 (HBlank),
	 .VGA_VB					 (VBlank),
    // I2C
    //.I2C_SCLK            (),
    //.I2C_SDAT            (),
    // UART
    //.UART_RXD            (),
    //.UART_TXD            (),

	 .Clk_Video           	(clk_25Mhz),
	 .Bram_Data 				(BramData),		//: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
	 .Z80_Addr 					(Z80Addr),
	 .Z80_Data 					(Z80Data),
	 .Z80F_BData		 		(Z80F_BData),
	 .Hex							(Hex),
	 .EKey						(status[9]),
    .key_ready  				(key_strobe),//key_ready), //: in  std_logic;
    .key_stroke 				(~ps2_key[9]), //: in  std_logic;
    .key_code   				({1'b0,ps2_key[8:0]}), //: in  std_logic_vector(9 downto 0)
	 .clk_sys					(clk_sys),
	 .sound_out					(AudioOut)

    );

wire clk_sys;
wire [7:0] AudioOut;
	 
//wire key_ready;
//
//always @(ps2_key) 
//begin 
//	key_ready <= 1;
//end	 

wire key_strobe = old_keystb ^ ps2_key[10];
reg old_keystb = 0;
always @(posedge clk_sys) old_keystb <= ps2_key[10];

assign CLK_VIDEO = clk_25Mhz;
assign CE_PIXEL = 1;//ce_pix;



`define Debug           //Comentar si no se quiere pasar por el modulo
//Parte Comun no Modificable 200525
ovo DebugOverlay(
    // VGA IN
    .i_r   ( VGA_R_tmp),//: IN  unsigned(7 DOWNTO 0);
    .i_g   ( VGA_G_tmp),//: IN  unsigned(7 DOWNTO 0);
    .i_b   ( VGA_B_tmp),//: IN  unsigned(7 DOWNTO 0);
    .i_hs  (VGA_HS_tmp),//: IN  std_logic;
    .i_vs  (VGA_VS_tmp),//: IN  std_logic;
	 .i_de  (VGA_DE_tmp),//: IN  std_logic;
    .i_en  (1'b1),//: IN  std_logic;
    .i_clk (VGA_CLK_tmp),//: IN  std_logic;

    // VGA_OUT
    .o_r   ( VGA_R_o),//: OUT unsigned(7 DOWNTO 0);
    .o_g   ( VGA_G_o),//: OUT unsigned(7 DOWNTO 0);
    .o_b   ( VGA_B_o),//: OUT unsigned(7 DOWNTO 0);
    .o_hs  (VGA_HS_o),//: OUT std_logic;
    .o_vs  (VGA_VS_o),//: OUT std_logic;
    .o_de  (VGA_DE_o),//: OUT std_logic;

    // Control
    .ena   (Show),//: IN std_logic; -- Overlay ON/OFF

    // Probes
    .in0   (DebugL0),//({5'b00000,5'b00001}),//IN unsigned(0 TO COLS*5-1);
    .in1   (DebugL1),//({5'b00010,5'b00011})//IN unsigned(0 TO COLS*5-1):=(OTHERS =>'0')
    .in2   (DebugL2),//({5'b00000,5'b00001}),//IN unsigned(0 TO COLS*5-1);
    .in3   (DebugL3),//({5'b00010,5'b00011})//IN unsigned(0 TO COLS*5-1):=(OTHERS =>'0')
    .in4   (DebugL4),//({5'b00000,5'b00001}),//IN unsigned(0 TO COLS*5-1);
    .in5   (DebugL5),//({5'b00010,5'b00011})//IN unsigned(0 TO COLS*5-1):=(OTHERS =>'0')
    .in6   (DebugL6),//({5'b00000,5'b00001}),//IN unsigned(0 TO COLS*5-1);
    .in7   (DebugL7)//({5'b00010,5'b00011})//IN unsigned(0 TO COLS*5-1):=(OTHERS =>'0')
);

wire [7:0] VGA_R_o; 
wire [7:0] VGA_G_o; 
wire [7:0] VGA_B_o;
wire VGA_HS_o, VGA_VS_o, VGA_DE_o;
`ifdef Debug
	assign VGA_R  = VGA_R_o;
	assign VGA_G  = VGA_G_o;
	assign VGA_B  = VGA_B_o;
	assign VGA_HS = VGA_HS_o;
	assign VGA_VS = VGA_VS_o;
	assign VGA_DE = VGA_DE_o;
`else
	assign VGA_R  = VGA_R_tmp;
	assign VGA_G  = VGA_G_tmp;
	assign VGA_B  = VGA_B_tmp;
	assign VGA_HS = VGA_HS_tmp;
	assign VGA_VS = VGA_VS_tmp;
	assign VGA_DE = VGA_DE_tmp;
`endif


//Parte Particular Modificable 200525


//Datos tal cual se entregarian a EMU
wire [7:0] VGA_R_tmp;
wire [7:0] VGA_G_tmp;
wire [7:0] VGA_B_tmp;
assign VGA_R_tmp = {r, r}; //4'b0};
assign VGA_G_tmp = {g, g}; //4'b0};
assign VGA_B_tmp = {b, b}; //4'b0};

wire VGA_HS_tmp, VGA_VS_tmp, VGA_DE_tmp, VGA_CLK_tmp, Show; // si visible o si no visible

assign VGA_HS_tmp = ~HSync;
assign VGA_VS_tmp = ~VSync;
assign VGA_DE_tmp = ~(HBlank | VBlank);
assign VGA_CLK_tmp = clk_25Mhz;
assign Show = ~status[8]; // si visible o si no visible

//Datos a mostrar

wire [15:0] BramData;
wire [15:0] Z80Addr;
wire [15:0] Z80Data;
wire [15:0] Z80F_BData;
wire [15:0] Hex;
wire [15:0] DebugL0, DebugL1,DebugL2, DebugL3,DebugL4, DebugL5, DebugL6, DebugL7;

//assign DebugL0 = ({5'b00000,5'b00001,5'b00001});
//assign DebugL1 = ({5'b00010,5'b00011,5'b00011})


assign DebugL0 = {{1'b0,vsd_sel,img_mounted,SD_CD},{3'b000,clk},{3'b000,status[9]},{3'b000,clk_25Mhz}};//BramData;//rememotech.U_RamRom.q[14:0];
//assign DebugL1 = {5'b00000,5'b00001,{4'b0000,clk_25Mhz}}; //assign DebugL1 = Z80Addr[14:0];
assign DebugL1 = Z80Addr;
assign DebugL2 = Z80Data;
assign DebugL3 = Z80F_BData; //"00" & not ctc_interrupt & M1_n & MREQ_n & IORQ_n & RD_n & WR_n & rom_q;
assign DebugL4 = Hex;
assign DebugL5 = img_size[3:0];//BramData;




//Intento de Frenarlo todo... le ponemos su clock de entrada uno ralentizado X veces por segundo
reg [25:0] accum = 0;
wire pps = (accum == 0);
wire clk;


always @(posedge CLK_50M) begin
    accum <= (pps ? 50_000_000/10 : accum) - 1;

    if (pps) begin
        clk <= ~clk;
    end
end


endmodule
