#!/bin/ksh
#
# mtx2MTX.sh - Convert .mtx file to a CP/M 8.3 .MTX file
#
# This is so that they can be loaded into the virtual cassette
# slots on REMEMOTECH, using the RETAPE.COM program.
#
# So the aim is to pick 56 popular games, not available in .COM format.
#

n_slots=56

n=1
> cpmfiles2/TAPES.SUB

for f in \
"AGROVATA.mtx" \
"Arcazion (1985) (Chris Sawyer) [a1].mtx" \
"Astromilon (1984) (Continental Software) [a1].mtx" \
"Backgammon (1983) (Continental Software) [a1].mtx" \
"Blitz (19xx) (Tri-Com Software).mtx" \
"Boris and the Bats (1984) (TRi-Com Software).mtx" \
"Bouncing Bill (1984) Brian Rogers.mtx" \
"Chamberoids (1984) (Megastar Games) [a1].mtx" \
"Cobra (19xx) (Xaviersine Audio Products).mtx" \
"Cosmic Raiders (1984) (Continental Software).mtx" \
"Doodlebug Destroyer GAME (19xx) (Syntaxsoft).mtx" \
"Downstream Danger (1985) (Megastar Games).mtx" \
"DRAGONS RING.mtx" \
"Drive the Cee-5 (1985) (Stephen Trinder) (Megastar Games).mtx" \
"Duckybod.mtx" \
"Firehouse Freddy (1984) (DGC).mtx" \
"Flummox (19xx) (Syntaxsoft).mtx" \
"Goldmine (1984) (Continental Software).mtx" \
"Highway Encounter (19xx) (Syntaxsoft (Vortex)).mtx" \
"Hunchy (P Wood) (19xx).mtx" \
"Iceberg (1985) (Syntaxsoft).mtx" \
"Jack Flash (NJ & MI) (1985).mtx" \
"Jet Set Willy (1985) (Software Projects) Quick Load.mtx" \
"Johnny Rebel (19xx) [a1].mtx" \
"Karate King 64 (Mike and Chris Bayne) (1985) (Megastar Games).mtx" \
"Kommand (Chris Sawyer) (19xx).mtx" \
"Land Mines (Jim Wills) (19xx).mtx" \
"LESFLICS.mtx" \
"Lydrolla (19xx).mtx" \
"Manic Miner (Mathrew Smith) (19xx).mtx" \
"Maxima (1984) (Continental Software).mtx" \
"Miner Dick (1984) (Xaviersine Audio Products).mtx" \
"Ms Snapman (1984) (Johan Meiring).mtx" \
"Munch Mania (1984) (B.C.C).mtx" \
"Obliteration Zone (1985) (A Southgate).mtx" \
"Phaid (1994) (Continental Software) [a1].mtx" \
"Pontoon Blackjack (19xx) (Continental Software).mtx" \
"Pothole Pete (1984) (Continental Software).mtx" \
"Qogo (1984) (Continental Software) [a1].mtx" \
"Qogo 2 (19xx) (Megastar Games).mtx" \
"Quazzia (1984) (Megastar Games) [a1].mtx" \
"S2.mtx" \
"Salty Sam (1984) (Syntaxsoft).mtx" \
"Sepulcri (SEPULCRI2) (19xx).mtx" \
"SLITHER.mtx" \
"SNAPPO.mtx" \
"SNOOKER.mtx" \
"Snowball (1983) (Level 9).mtx" \
"SON OF PETE.mtx" \
"Space Invasion (1998) (PD).mtx" \
"Super Minefield (1984) (Continental Software) [a1].mtx" \
"Tapeworm (1984)(Continental Software)[a].mtx" \
"TIMEBAND.mtx" \
"Vernon and the Vampires (1985) (Syntaxsoft).mtx" \
"Vortex by Paul Daniels (19xx) (PD).mtx" \
"Zarcos (1984) (Megastar Games) [a1].mtx" \
"Crystal (198x) (Megastar Games).mtx" \
"Dennis and the Chickens (1984) (Continental Software).mtx" \
"Dennis at the circus (198x) (Continental Software).mtx" \
"Dennis Goes Bananas (198x) (Continental Software).mtx" \
"Dungeon Adventure (1984) (Level 9).mtx" \
"Felix In the Factory (1984) (Micropower).mtx" \
"Formula 1 Simulator (1985) (Mastertronic).mtx" \
"frankie.mtx" \
"Lords Of Time (1987)(Level 9).mtx" \
"MTX Chess (1983) (Continental Software).mtx" \
"Return to Eden (1984) (Level 9).mtx" \
"Soul of a Robot (1985) (Mastertronic).mtx" \
"Colossal Adventure (1983) (Level 9).mtx" \
"Spectron - 1983 Spectravideo Int'l Ltd.mtx" \
"Telebunny - 1983 Mass Tael Ltd.mtx" \
"journeyintodanger.mtx" \
"Emerald Isle (1985) (Level 9).mtx" \
"Ghostly Castle (1985) (Pansoft).mtx" \
"reveal.mtx" \
"Electronics (1988) (Unknown).mtx" \
"Fathoms Deep (1984).mtx" \
"Memotech ROM Demo (198x) (Continental Software).mtx" \
"Pac Manor Rescue (1985) (Unknown).mtx" \
"Quasimodos Bells (198x) (Starlite Software).mtx" \
"Soldier Sam (1985) (Liam Redmond Software).mtx" \
"TNTTim.mtx" \
"Words & Pictures (1984) (Continental Software).mtx" \
"Football Manager (1987) (Addictive Games).mtx" \
; do
	f2=`dd "if=../../memu/tapes/$f" bs=1 skip=1 count=8 2> /dev/null`
	f2=`print ${f2%% *} | tr a-z A-Z | sed 's/[:._\/]/-/g'`
	cp "../../memu/tapes/$f" cpmfiles2/$f2.MTX
	printf "%-65s %s.MTX\n" "$f" "$f2"
	if [[ $n -le $n_slots ]] ; then
		print "RETAPE $f2.MTX $n" >> cpmfiles2/TAPES.SUB
		n=$(( n+1 ))
	fi
done 
unix2dos -q cpmfiles2/TAPES.SUB
print "\032" >> cpmfiles2/TAPES.SUB
