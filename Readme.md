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
    
    
## General description
This core contains the latest version of framework and will be updated when framework is updated. There will be no releases. This core is only for developers. Besides the framework, core demonstrates the basic usage. New or ported cores should use it as a template.

It's highly recommended to follow the notes to keep it standartized for easier maintanance and collaboration with other developers.

## Source structure

### Legend:
* `<core_name>` - you have to use the same name where you see this in this manual. Basically it's your core name.

### Standard MiSTer core should have following folders:
* `sys` - the framework. Basically it's prohibited to change any files in this folder. Framework updates may erase any customization in this folder. All MiSTer cores have to include sys folder as is from this core.
* `rtl` - the actual source of core. It's up to developer how to organize the inner structure of this folder. Exception is pll folder/files (see below).
* `releases` - the folder where rbf files should be placed. format of each rbf is: <core_name>_YYMMDD.rbf YYMMDD is date code of release.

### Other standard files:
* `<core_name>.qpf`- quartus project file. Copy it as is and then modify the line `PROJECT_REVISION = "<core_name>"` according to your core name.
* `<core_name>.qsf` - quartus settings file. In most cases you don't need to modify anything inside (although you may wont to adjust some settings in quartus - this is fine, but keep changes minimal). You also need to watch this file before you make a commit. Quartus in some conditions may "spit" all settings from different files into this file so it will become large. If you see this, then simply revert it to original file.
* `<core_name>.srf` - optional file to disable some warnings which are safe to disable and make message list more clean, so you will have less chance to miss some improtant warnings. You are free to modify it.
* `<core_name>.sdc` - optional file for constraints in case if core require some special constraints. You are free to modify it.
* `<core_name>.sv` - glue logic between framework and core. This is where you adapt core specific signals to framework.
* `files.qip` - list of all core files. You need to edit it manually to add/remove files. Quartus will use this file but can't edit it. If you add files in Quartus IDE, then they will be added to `<core_name>.qsf` which is recommended manually move them to `files.qip`.
* `clean.bat` - windows batch file to clean the whole project from temporary files. In most cases you don't need to modify it.
* `.gitignore` - list of files should be ignored by git, so temprorary files wont be included in commits.
* `jtag.cdf` - it will be produced when you compile the core. By clicking it in Quartus IDE, you will launch programmer where you can send the core to MiSTer over USB blaster cable (see manual for DE10-nano how to connect it). This file normally is not presend on cleaned project and not includede in commits.

### PLL:
Framework implies use of at least one PLL in the core. Framework doesn't comtain this PLL but requires it to be placed in `rtl` folder, so `pll` folder and `pll.v`, `pll.qip` files must be present, however PLL settings are up to the core.

# Quartus version
Cores must be developed in **Quartus v17.0.x**. It's recommended to have updates, so it will be **v17.0.2**. Newer versions won't give any benefits to FPGA used in MiSTer, howver they will introduce incompatibilities in project settings and it will make harder to maintain the core and collaborate with others. **So please stick to good old 17.0.x version.** You may use either Lite or Standard license.

