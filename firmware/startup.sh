#!/bin/ksh
#
# startup.sh - Set up the initial command(s)
#
# Somewhat like the Memotech CP/M STARTUP.COM program.
#
# eg: $ ./startup.sh mydisk "SIDISC" "CONFIG B:7,F:51"
#

d=`dirname $0`

usage()
	{
	print "usage: $0 file.mfloppy {cmd}"
	exit 1
	}

if [[ "$1" = "" ]] ; then
	usage
fi

f="$1"
if [[ ! -w "$f" ]] ; then
	print "$0: can't modify the startup command of $f"
	exit 2
fi

tf=/tmp/enter.$$

> $tf

shift
while [[ "$1" != "" ]] ; do
	print -n "$1\r" >> $tf
	shift
done

print -n "\000" >> $tf

size=`ls -l $tf | awk ' { print $5; } '`

if [[ $size -gt 48 ]] ; then
	rm $tf
	print "$0: commands too long"
	exit 3
fi

dd if=$tf of=$f bs=1 seek=16 conv=notrunc 2> /dev/null

rm $tf
