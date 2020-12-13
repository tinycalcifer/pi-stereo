#!/usr/bin/env bash

cat << SPLAIN
This script, when run by a user with sudo administrative privileges, will
set up a Raspberry Pi running Ubuntu Server 20.04 LTS as a "network stereo
streaming reciever". That is, it will install and configure software that
will let this device act as a reciever for Spotify Connect and AirPlay, which
in turn lets you stream audio from Spotify or any recent iOS device to the
Pi's Headphone Out jack.

At the following confirmation prompt:
- 'y' : "Yes", continue and prompt for confirmation at each major step
- 'q' : "Quietly", continue and prompt only for required values
- 'n' : "No", quit the script

SPLAIN

confirm="true"
while true; do read -n 1 -p "Shall we continue? [nyq]" yn
	case $yn in
		[Yy]* ) break;;
		[Nn]* ) exit 1;;
		[Qq]* ) confirm="";;
		* ) echo "Requires an answer." ;;
	esac
done

## continue with main work

sudo="echo /usr/bin/sudo -p \"Requesting sudo rights, your password required: \""

confirmation() {
	if ! [ "$confirm" ]; then return 0; fi  ## if the confirm flag is not set, exit true
	while true; do read -n 1 -p "$prompt [yn]" yn
		case $yn in
			[Yy]* ) return 0;;
			[Nn]* ) return 1;;
			* ) echo "Requires an answer." ;;
		esac
	done
	return 1  # just in case we get here somehow, return false by default
}

sudo 

## alsa and related tools
if confirmation "Install pre-requisites (alsa and tools)?"
then
	$sudo apt update
	$sudo apt install alsa-utils alsa-base
else
	echo "Can't continue without alsa installation. Exiting."
	exit 2
fi

## shairport-sync, an airplay target daemon
if confirmation "Set this device ($(hostname -s)) as an AirPlay target?"
then
	$sudo apt install shairport-sync
	targetname=$(hostname -s)
	if [ "$confirm" ]; then
		read \
			-p "Choose name to show on AirPlay clients [$targetname]: " \
			-i "$targetname" targetname
	fi
	echo "Setting AirPlay name to '$targetname'"
	# edit config to set name
	$sudo perl -p -i -e "s/^(\\s*name =).*\$/\$1 \"$targetname\"/;" /etc/shairport-sync.conf

	echo "Restarting AirPlay service shairport-sync"
	$sudo systemctl restart shairport-sync.service
	$sudo systemctl status shairport-sync.service
fi
