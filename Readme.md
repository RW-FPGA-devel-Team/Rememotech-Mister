# Rememotech MTX port for MiSTer FPGA Board.

Originbal development from Andy.Z.Key : http://www.nyangau.org/rememotech/rememotech.htm

REMEMOTECH is a modern-day re-implementation of a Memotech MTX/FDX/SDX compatible computer :-

    in VHDL
    re-using existing VHDL definitions of major chips
    writing VHDL definitions of missing chips
    writing the glue logic in VHDL
    synthesizing for a Cyclone II FPGA and targetting an Altera DE1 board
    exploiting the hardware on the board, around the FPGA, such as clock, connectors, 
    Flash, SRAM, VGA DACs, sound CODEC, SD Card, ... 

It implements enough hardware to allow it to run MTX BASIC, various MTX games and CP/M. It supports :-

    Z80 compatible CPU, at 4.166MHz and other speeds upto 25MHz
    384KB RAM, 72KB ROM
    PS/2 keyboard
    VDP, outputting to 640x480 @ 50Hz (or 60Hz) VGA
    Sound chip
    80 column card support, with 80x24 and 80x48 modes, outputting to 640x480 @ 60Hz VGA
    Whether VDP or 80 column output appears on main VGA output switchable
    The other display can appear on another VGA, via a daughter card
    RAM Disc support (upto 320KB)
    SD Card as a large and fast alternative to floppy disk
    Modified SDX ROM using SD Card and RAM Disc instead of floppy disk
    Virtual cassette support
    Numeric accelerator


For the port to MiSTer, video has been re-implemented in VGA and HDMI and access to the storage is done through a VHD file.
Each VHD file can have upto 8 8MB partitions. (64 MB Max) Each of these would contain a CP/M 2.2 filesystem. 

The Flash image is embedded into the core, and contains a raw 512KB image of the Flash (which contains ROM images and the initial RAM Disc image). 

You'll need to use RECONFIG.COM to configure a drive (or drives) to access partitions on the SD Card. Type codes 18..1F correspond to 8MB partitions 0 to 7 on the card. eg: To access partitions 0, 1 and 2 :-

A>RECONFIG B:18,C:19,D:1A

    You can switch to MTX BASIC, and use ROM 5 to gain access to disk via USER commands.
    
    A>MTXL
    ROM 5
    USER DIR
    USER RUN "SOFT.RUN"

For the TAPES, use RETAPE

    You can switch to MTX BASIC, and use ROM 5 to gain access to disk via USER commands.
    
    RETAPE "TAPE.MTX"
    MTXL
    LOAD "TAPE"
    
    

