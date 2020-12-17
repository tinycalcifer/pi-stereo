# Raspberry Pi 3 B+ audio streamer client

Create an RPi-based audio streaming client that, when connected to a receiver
or powered speaker, streams Spotify Connect and AirPlay audio over WiFi.

<!--TOC-->

- [Raspberry Pi 3 B+ audio streamer client](#raspberry-pi-3-b-audio-streamer-client)
- [6. Dec. 2020](#6-dec-2020)
  - [Steps](#steps)
    - [Image the Pi](#image-the-pi)
    - [Prep for boot](#prep-for-boot)
    - [First boot and initial config](#first-boot-and-initial-config)
    - [install updates](#install-updates)
    - [install a few support packages](#install-a-few-support-packages)
    - [(optional) install cockpit (web-based admin tool)](#optional-install-cockpit-web-based-admin-tool)
  - [Setting up `spotifyd` for Spotify Connect](#setting-up-spotifyd-for-spotify-connect)
    - [Configuring `spotifyd`](#configuring-spotifyd)
    - [Set spotifyd to start automatically with systemctl](#set-spotifyd-to-start-automatically-with-systemctl)
  - [Setup AirPlay target](#setup-airplay-target)
  - [(optional) Disable the Power and Activity LEDs](#optional-disable-the-power-and-activity-leds)
- [16. Dec. 2020](#16-dec-2020)
  - [Setting output to the USB audio device](#setting-output-to-the-usb-audio-device)

<!--TOC-->

# 6. Dec. 2020

Trying out using Ubuntu Server instead of Raspbian. We'll see how this goes.

RPi materials:

* RPi 3 model B+, with case and heatsinks, powersupply, 16GB microSDHC card
* [Ubuntu Server 20.04.1 LTS, 32-bit (begins download)][ubuntu_image] from the [Ubuntu Pi Download page][ubuntu_download_page]
* [spotifyd][spotifyd] -- enables Pi as a Spotify Connect client
* [shairport-sync][shairport-sync] -- enables Pi as an AirPlay audio target
* [cockpit][cockpit] (optional) -- web-based admin panel for easy maintenance

[ubuntu_image]: https://ubuntu.com/download/raspberry-pi/thank-you?version=20.04.1&architecture=server-armhf+raspi
[ubuntu_download_page]: https://ubuntu.com/download/raspberry-pi
[spotifyd]: https://github.com/Spotifyd/spotifyd
[shairport-sync]: https://github.com/mikebrady/shairport-sync

Other tools:

* [Balena Etcher for Windows][etcher_download] (makes imaging the Pi easier)


[etcher_download]: https://www.balena.io/etcher/


## Steps

### Image the Pi

Get the image, burn it with etcher. Easy. If you don't know how, Ubuntu provides an [Ubuntu Server on RPi installation guide][ubuntu-guide].

Slide the card into the Pi while it's powered off.

### Prep for boot

I'm using Ethernet for initial setup, so no further prep. You can also modify the `network-config` file in the `system-boot` section of the SD card before installing it in the Pi to set up WiFi. See the "Wi-Fi or Ethernet" sectio of the [Ubuntu Server isntall guide][ubuntu-guide] for details.

[ubuntu-guide]: https://ubuntu.com/tutorials/how-to-install-ubuntu-on-your-raspberry-pi

### First boot and initial config

This will be configured remotely using SSH.

First, find the Pi's IP address.

Windows: `arp -a | findstr b8-27-eb` will find all RPis on your network (except for some RPi 4's -- you'll need `dc-a6-32` instead for those) that Windows can see via ARP (this might not work for some odd network configurations; I just checked by DHCP leases file on my DHCP server)

Then use PuTTY or WSL to ssh to that IP using the username `ubuntu` with the password `ubuntu`; you'll be asked to change the password on first connection, and you'll have to reconnect with the new password afterwards.

#### Configure Wi-Fi (if you're using it)

Ubuntu Server uses netplan.  I use vim; you can use `nano` if you prefer

```bash
sudo vim /etc/netplan/50-cloud-init.yaml
```

Add a wifi configuration to the end of the file, make sure `wifis:` is indented in line with the `ethernets:` section (i.e. it's under the `networks:` section):

```yaml
    wifis:
        wlan0:
            dhcp4: true
            optional: true
            access-points:
                "Your_SSID_HERE":
                    password: "your_WPA2_password_HERE"
```

Then activate this configuration with

```bash
sudo netplan generate && sudo netplan apply
```

Use `ip a show dev wlan0` to see the IPv4 and IPv6 addresses assigned; if you don't see an address, you need to check your configuration and re-run generate/apply


#### Set the hostname

I picked `pi-stereo`; pick whatever you like

```bash
sudo hostnamectl set-hostname pi-stereo
```

### install updates

We want to have our system up to date and working!

```bash
sudo apt update && sudo apt upgrade
```

### install a few support packages

```bash
sudo apt install alsa-utils alsa-base
```

### (optional) install cockpit (web-based admin tool)

```bash
sudo apt install cockpit
```

And then visit `https://pi-stereo.local:9090` (replacing `pi-stereo.local` with your hostname or IP as needed), logging on with `ubuntu` and the password you use for that account

## Setting up `spotifyd` for Spotify Connect

Get the `linux-armv6-full` variants by downloading the `.tar.gz` and the `.sha512` files.

As of this writing, that's done with two `curl` commands:

```bash
curl -LO https://github.com/Spotifyd/spotifyd/releases/download/v0.2.24/spotifyd-linux-armv6-full.tar.gz
curl -LO https://github.com/Spotifyd/spotifyd/releases/download/v0.2.24/spotifyd-linux-armv6-full.sha512
```

Then check the integrity of the download

```bash
shasum -c spotifyd-linux-armv6-full.sha512
```

Now unpack and move the binary:

```bash
tar xzf spotifyd-linux-armv6-full.tar.gz
sudo mv -i spotifyd /usr/local/bin/
```

And now the fun part:

### Configuring `spotifyd`

Create a non-root user to run spotifyd as:

```bash
sudo addgroup spotify
sudo adduser --ingroup spotify spotify
sudo usermod -a -G audio spotify
```

Create a directory to hold cached songs

```bash
sudo mkdir /var/cache/spotifyd
sudo chown spotify:spotify !$
```

Create a file `/etc/spotifyd.conf` and change its owner to be `spotify` and set it so no other user (other than root or people who can become root) can read your password:

```bash
sudo touch /etc/spotifyd.conf
sudo chown spotify:spotify !$
sudo chmod a=,u=rw,g=r !$
```

Now edit the config *as the spotify user*:

```bash
 sudo -u spotify vim /etc/spotifyd.conf
```

Using these contents (make changes as needed for your account and preferences):

```toml
[global]
# Your Spotify account name and password
username = spotify_username
password = spotify_password

# How spotifyd will play; you'll need to change this if you use some unusual
# audio system on Server, like PulseAudio
backend = alsa

# alsa device: usually 'sysdefault'
device = sysdefault

# The alsa mixer channel to use
mixer = Headphone

# The volume controller. [softvol, alsa, alsa_linear]
volume_controller = alsa

# Name to advertise in Spotify clients. NO SPACES
device_name = Pi_Stereo

# The audio bitrate to stream. 96, 160 or 320 kbit/s
bitrate = 320

# Absolute path to use for song cache
cache_path = /var/cache/spotifyd

# If you don't want to cache at all, set this TRUE
no_audio_cache = false

# Volume on startup between 0 and 100
initial_volume = 95

# If set to true, enables volume normalisation between songs.
volume_normalisation = true

# The normalisation pregain that is applied for each song.
normalisation_pregain = -10

# The port `spotifyd` uses to announce its service over the network.
zeroconf_port = 1234

# if you need an HTTP proxy on your network to connect to Spotify,
# set it here
# proxy = "http://proxy.example.org:8080"

# The displayed device type in Spotify clients.
# Can be unknown, computer, tablet, smartphone, speaker, tv,
# avr (Audio/Video Receiver), stb (Set-Top Box), and audiodongle.
device_type = avr
```

Now you can test by running 

```bash
sudo -u spotify /usr/local/bin/spotifyd --no-daemon
```

Open Spotify on some other device (or browser) and you should be able to select `Pi_Stereo` as a play target.

Press Ctrl-C to stop spotifyd

### Set spotifyd to start automatically with systemctl

Get the [spotifyd.service file][service-file] from the `contrib/` directory in Spotifyd's GitHub (**note this is v0.2.24; you may need to update version num in URL for future relases**), and put it in the systemd repository.

```bash
curl -LO https://raw.githubusercontent.com/Spotifyd/spotifyd/v0.2.24/contrib/spotifyd.service
```

Now edit the `spotifyd.service` file and *replace* the entire `[Service]` section with:

```conf
[Service]
ExecStart=/usr/local/bin/spotifyd --no-daemon --config-path /etc/spotifyd.conf
User=spotify
Group=spotify
Restart=always
RestartSec=12
```

(These edits point to the right binary path, specify the config file, and make the daemon run as the `spotify` user for security).

Now install the service:

```bash
sudo mv spotifyd.service /etc/systemd/system/
sudo systemctl daemon-reload
```

Make sure spotifyd is not running, then start the service with:

```bash
sudo systemctl start spotifyd.service
sudo systemctl status !$
```

Look at the log printed by the `status` subcommand above and make sure the service is running.

Now enable the service to start at boot time:

```bash
sudo systemctl enable spotifyd.service
```

[service-file]: https://github.com/Spotifyd/spotifyd/blob/v0.2.24/contrib/spotifyd.service

## Setup AirPlay target

```bash
sudo apt install shairport-sync
```

That should be it; it'll use your hostname as the airport target name (e.g. `Pi-stereo`)

## (optional) Disable the Power and Activity LEDs

I use a transparent Pi case, so the red power and flashing green activity lights were very distracting in a dark room.

See: `ledctl.sh` and `rc.local`

To disable the lights, we have to

1. Change their "trigger" so that they only care about gpio inputs
2. Tell their GPIO inputs to set brightness to zero

The controls for both these are adjusted by changing the contents of special files in the `/sys/class/leds/` directory. The directory `led0` there contains the controls for the activity light, and `led1` for the power light.

I wrote a script, `ledctl.sh` that can do these things conveniently; see it and the provided `rc.local` script which uses ledctl to disable the LEDs on each boot (since the changes are not persistent). If you use the provided `rc.local`, you need to copy it to `/etc/rc.local` and copy `ledctl.sh` to `/usr/local/bin/ledctl`. You'll also need to:

```bash
sudo systemctl enable rc-local.service
```

And ignore the warning block of text it spits out.

# 16. Dec. 2020

Groundloops are a concern; when connecting to an AV system, there is significant "buzz" from the headphone connection on the Pi. After looking at several options for fixing this, it seems the most straightforward is to use a USB sound device with a digital output.

I purchased this [Signstek USB to S/PDIF Converter](https://www.amazon.com/gp/product/B00FEDHHKE) (Amazon link, sorry). This is by far not the only option, it just happened to be the cheapest I could find that:

- Had both coaxial S/PDIF and optical (toslink) out
- Was driverless under Linux
- Did not require external power (powered by its USB connection)

It also has analog outputs, which is nice for future reusability.

## Setting output to the USB audio device

If your spotifyd or shairport-sync configurations don't use the system default ALSA output, you may have to adjust those configurations. Otheriwse, you can just set the USB device as your default for ALSA

First, find the device using `aplay -l` and note the device number. Mine was device 1 (the built-in Pi audio is 0). So I created `/etc/asound.conf` with the following contents:

```conf
defaults.pcm.card 1
defaults.ctl.card 1
```

And edited the `/etc/spotifyd.conf` by editing the `mixer =` line to read `mixer = PCM`

Then just

```bash
sudo systemctl restart alsa-state.service
sudo systemctl restart spotifyd.service
sudo systemctl restart shairport-sync.service
```

Now your audio should route to the USB audio device.

**NOTE** some of these USB audio devices will have separate devices or mixers for the different outputs. If yours does, you might have some additional testing and research to do. The one I bought only has one mixer for everything. 
