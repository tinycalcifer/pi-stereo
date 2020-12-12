#!/usr/bin/env bash

ledbase="/sys/class/leds"

usage() {
	>&2 cat << USAGE
Usage: $0 <led_number> on|off
       $0 <led_number> <trigger_list>
USAGE
}

if [[ -z "$1" ]] | [[ -z "$2" ]]
then
	usage
	exit 127
fi

led="$1"
shift

case "$led" in
	pwr)
		led="1"
		;;
	act)
		led="0"
		;;
esac


ledpath="$ledbase/led$led"
if ! [[ -d "$ledpath" ]]
then
	>&2 echo "Can't find LED $led in $ledbase"
	exit 1
fi

case "$1" in
	on)
		echo 255 | sudo tee "$ledpath/brightness"
		;;
	off)
		echo 0 | sudo tee "$ledpath/brightness"
		;;
	*)
		echo "Setting LED $led to trigger on '$@'"
		echo "$@" | sudo tee "$ledpath/trigger"
		;;
esac	


