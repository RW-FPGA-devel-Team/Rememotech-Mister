#!/bin/ksh
#
# itead.sh - How to prepare for submission to iteadstudio
#
# Now renames from new filename convention seen in latest KiCad
#
# eg: itead.sh 1234567
#

if [[ "$1" = "" ]] ; then
	print "usage: $0 ordernumber"
	exit 1
fi

cp daughter-F.Cu.gbr      board-$1.GTL
cp daughter-B.Cu.gbr      board-$1.GBL
cp daughter-F.Mask.gbr    board-$1.GTS
cp daughter-B.Mask.gbr    board-$1.GBS
cp daughter-F.SilkS.gbr   board-$1.GTO
cp daughter-B.SilkS.gbr   board-$1.GBO
cp daughter-Edge.Cuts.gbr board-$1.GKO
cp daughter-PTH.drl       board-$1.TXT

zip -q "O$1 10by10 Green 1.6mm HASL 10pcs.zip" board-$1.*
rm board-$1.*
