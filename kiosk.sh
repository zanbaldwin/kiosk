#
# KIOSK SETUP
# ===========
#
# Setup a Web Kiosk on a Debian-based system.
# This script has been customised for use on a fresh installation of Raspbian
# Wheezy, so many unnecessary packages may still remain on your system causing
# complications with the current setup if you use another distribution.
#
# @author       Zander Baldwin <mynameiszanders@gmail.com>
# @license      MIT/X11 <http://j.mp/mit-license>
# @copyright    2013 Zander Baldwin
#

TITLE="Kiosk Setup"

install_kiosk() {

    INSTALLCERT="$1"

    CACN=""
    URL_PROTOCOL=""
    if [ $INSTALLCERT -eq 1 ]; then
        # If we are using Client Certificates, then we must specify HTTPS,
        # otherwise they don't get sent.
        URL_PROTOCOL="https"
        # Ask what the Common Name of the Certification Authority that signed
        # the Client Certificates is, that way we can instruct Chromium to
        # automatically select it when visiting the website.
        CACN=$(whiptail --inputbox "Please enter the exact Common Name of the Certification Authority that signs the PKCS#12 certificate for this Kiosk (for example, \"My Company Kiosk CA\"):" 10 78 --title "$TITLE" 3>&1 1>&2 2>&3)
    fi

    # Ask what URL the Web Kiosk should load when it starts.
    URL=$(whiptail --inputbox "Please enter the path of the full URL you wish the Kiosk to point to (for example, \"http://example.com/kiosk/home.php\"):" --title "$TITLE" 10 78 3>&1 1>&2 2>&3)
    # Determine the protocol of the URL.
    if [ $URL_PROTOCOL = "" ]; then
        # Strip out "://" and everything after it.
        URL_PROTOCOL=${URL%%://*}
    fi
    # Strip out "://" and everything before it, then strip out the first "/" and
    # everything after it.
    URL_DOMAIN=${URL#*://}
    URL_DOMAIN=${URL_DOMAIN%%/*}
    # Strip out everything the first "/" and everything after it that occurs
    # after "://".
    URL_PATH=${URL#*://*/}
    # If no path was specified in the URL, $URL_PATH will not have matched and
    # returned the entire URL. Set an empty string if this is the case.
    if [ $URL = $URL_PATH ]; then
        URL_PATH=""
    fi

    whiptail --title "$TITLE" --yesno "Would you like to setup default Chromium settings, to stop autofill and zoom to 150%?" 20 60 2 --yes-button "Yes" --no-button "No"
    CHROMESETTINGS=$?

    # END OF KIOSK CONFIGURATION. START INSTALLATION.

    # PACKAGES
    # ========

    # Update package repository lists.
    apt-get update
    # Remove unused packages.
    whiptail --title "$TITLE" --yesno "Would you like to purge unnecessary packages? It might be best not to do this if you're not sure." 20 60 2 --yes-button "Yes" --no-button "No"
    PURGEPACKAGES=$?
    if [ $PURGEPACKAGES -eq 0 ]; then
        aptitude purge -y lxappearance lxde lxde-common lxde-core lxde-icon-theme lxinput lxmenu-data lxpanel lxpolkit lxrandr lxsession lxsession-edit lxshortcut lxtask lxterminal xinit xserver-xorg lightdm scratch midori desktop-base desktop-file-utils gnome-icon-theme gnome-themes-standard leafpad menu-xdg omxplayer xarchiver zenity tk8.5 pcmanfm blt idle idle3 python-tk python3-tk dillo openbox gvfs gvfs-backends gvfs-common gvfs-daemons gvfs-fuse gvfs-libs pistore obconf
    fi
    # Upgrade existing packages.
    apt-get upgrade -y
    # Install required packages.
    aptitude install --without-recommends -y xorg slim chromium-browser rsync openssh-server libnss3-tools

    # PACKAGE CONFIGURATION

    # Configuration for Chromium
    mkdir -p /etc/chromium/policies/managed
    touch /etc/chromium/policies/managed/kiosk.json
    echo "{
    \"AutoSelectCertificateForUrls\": [
        \"{\\\"pattern\\\":\\\"$URL_PROTOCOL://$URL_DOMAIN\\\",\\\"filter\\\": {\\\"ISSUER\\\":{\\\"CN\\\":\\\"$CACN\\\"}}}\"
    ],
    \"HomepageLocation\": \"$URL_PROTOCOL://$URL_DOMAIN/$URL_PATH\"
}" > /etc/chromium/policies/managed/kiosk.json
    # Configuration for Slim
    echo "default_user kiosk" >> /etc/slim.conf
    echo "auto_login yes" >> /etc/slim.conf

    # USERS

    # Setup a system user to run the Web Kiosk as.
    useradd -m -U kiosk
    chmod -R a+r /home/kiosk
    touch /home/kiosk/.xsession

    # If client certificate authentication was selected, create a
    # database and add the certificate to it.
    if [ $INSTALLCERT -eq 1 ]; then
        # Set the directory that Chromium uses to look for client certificates.
        CERTSTORE="/home/kiosk/.pki/nssdb"
        # Make the directory.
        mkdir -p $CERTSTORE
        # Pass ownership to the Web Kiosk user.
        chown -R kiosk:kiosk $CERTSTORE
        # Add the Web Kiosk user, create the certificate database.
        sudo -u kiosk certutil -d $CERTSTORE -N
        # install the PKCS#12 certificate as the Web Kiosk user
        # to the certificate database.
        sudo -u kiosk pk12util -d "sql:$CERTSTORE" -i "/tmp/kiosk.p12" -W ""
    fi

    # CHANGE CHROMIUM PREFERENCES
    # ---------------------------
    # Please note that this is highly specific for ONE USE CASE. Do not expect
    # this to work on your machine.
    # ========================================================================

    if [ $CHROMESETTINGS -eq 0 ]; then
        echo "openbox &
chromium-browser
exit 1" > /home/kiosk/.xsession
        chmod a+x /home/kiosk/.xsession
        cp /home/kiosk/.xsession /home/kiosk/.xinitrc
        service slim start
    fi

    echo "xset s off
xset -dpms
openbox &
while true; do
    rsync -qr --delete --exclude='.Xauthority' /opt/kiosk/ \$HOME/
    chromium-browser --kiosk $PROTOCOL://$DOMAIN/$URL
done" > /home/kiosk/.xsession
    chmod a+x /home/kiosk/.xsession
    cp /home/kiosk/.xsession /home/kiosk/.xinitrc

    # CREATE CUSTOM SKEL DIRECTORY FOR SYSTEM USER
    # ============================================

    # Create a blueprint of the Web Kiosk's user directory in /opt. Using rsync,
    # the Web Kiosk's user directory is temporary and only lasts the duration of
    # the session.
    cp -r /home/kiosk /opt/

    # You may wish to perform additional actions as the root user before booting
    # into the Web Kiosk.
    whiptail --yesno "Would you like to reboot into the Web Kiosk now?" 20 60 2
    if [ $? -eq 0 ]; then
        sync
        reboot
    else
        exit 0
    fi

}

#
# BEGIN SCRIPT HERE.
#

if [ $(id -u) -ne 0 ]; then
  printf "This script must be run as root. Try prefixing with 'sudo'.\n"
  exit 1
fi

WHIPTAILPATH=$(which whiptail)
if [ ${#WHIPTAILPATH} -eq 0 ]; then
    echo "This script requires Whiptail for its terminal GUI.\n"
    exit 1
fi

# Ask whether to setup automatic login via client certificates.
whiptail --title "$TITLE" --yesno "Would you like to setup automatic login, via certificates, or manual login, via username and password?" 20 60 2 --yes-button "Automatic" --no-button "Manual"
AUTOLOGIN=$?

if [ $AUTOLOGIN -eq 0 ]; then
    # Ask which Loan Station we are setting up a certificate for.
    KIOSKP12=$(whiptail --title "$TITLE" --inputbox "Please enter the URL of the Kiosk PKCS#12 certificate to be installed:" 10 78 3>&1 1>&2 2>&3)
    IDENTERED=$?
    if [ $IDENTERED = 0 ]; then
        wget "$KIOSKP12" --output-document="/tmp/kiosk.p12"
        CERTDOWNLOADED=$?
        if [ $CERTDOWNLOADED = 0 ]; then
            P12SIZE=$(stat -c %s /tmp/kiosk.p12)
            if [ $P12SIZE -ne 0 ]; then
                install_kiosk 1
            else
                whiptail --title "$TITLE" --msgbox "The certificate downloaded for the Kiosk ID you specified is not valid. Setup has been cancelled." 10 78
            fi
        else
            whiptail --title "$TITLE" --msgbox "The certificate for the Kiosk ID you specified could not be downloaded. Setup has been cancelled." 10 78
        fi
    else
        whiptail --title "$TITLE" --msgbox "Setup has been cancelled. This is not yet a Kiosk, please run this setup again to proceed." 10 78
    fi
else
    whiptail --title "$TITLE" --msgbox "You may have to manually login to the Kiosk each time you turn the machine on." 10 78
    install_kiosk 0
fi

# If you get here it means this script did not complete correctly. Exit with an
# error status.
exit 1
