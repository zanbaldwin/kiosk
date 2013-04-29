Debian-based Web Kiosk
======================

Setup a web kiosk on a fresh installation Raspbian Wheezy, though can be adapted for any Debian-based installation.

Prerequisites
-------------

- A [Raspberry Pi][rpi], and a copy of [Raspbian Wheezy][raspbian].
- An SD card in which have copied the Raspbian Wheezy image over; try using [Win32 Imager][win32imager] (Windows) or [ImageWriter][imagewriter] (Linux).
- [Whiptail][whiptail], though a check for this is performed and an error message will be shown if this is not installed.

Installation
------------
```bash
# Download the Kiosk Setup script.
wget https://raw.github.com/mynameiszanders/kiosk/master/kiosk.sh --output-document=/tmp/kiosk.sh
# Enable the script to be executed.
sudo chmod +x /tmp/kiosk.sh
# Execute the script.
sudo /tmp/kiosk.sh
```

[rpi]: http://www.raspberrypi.org/ "Raspberry Pi; an ARM GNU/Linux box for $25"
[raspbian]: http://www.raspberrypi.org/downloads "Raspberry Pi Downloads"
[win32imager]: http://win32diskimager.sourceforge.net/ "Win32 Disk Imager"
[imagewriter]: https://help.ubuntu.com/community/Installation/FromImgFiles "Installation from IMG files (Ubuntu Community Documentation)"
[whiptail]: http://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail "Bash Shell Scripting / Whiptail"
