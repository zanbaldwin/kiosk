setup_kiosk() {
    INSTALLCERT="$1"

    DOMAIN=""
    URL=""
    CACN=""

    # PACKAGES
    # ========

    # Update package repository lists.
    apt-get update
    # Remove unused packages.
    aptitude purge -y lxappearance lxde lxde-common lxde-core lxde-icon-theme lxinput lxmenu-data lxpanel lxpolkit lxrandr lxsession lxsession-edit lxshortcut lxtask lxterminal xinit xserver-xorg lightdm scratch midori desktop-base desktop-file-utils gnome-icon-theme gnome-themes-standard leafpad menu-xdg omxplayer xarchiver zenity tk8.5 pcmanfm blt idle idle3 python-tk python3-tk dillo openbox gvfs gvfs-backends gvfs-common gvfs-daemons gvfs-fuse gvfs-libs pistore obconf
    # Install required packages.
    aptitude install --without-recommends -y xorg slim matchbox-window-manager chromium-browser rsync openssh-server libnss3-tools
    # Upgrade existing packages.
    apt-get upgrade -y

    # PACKAGE CONFIGURATION
    # =====================

    # Configuration for Chromium
    mkdir -p /etc/chromium/policies/managed
    touch /etc/chromium/policies/managed/kiosk.json
    echo "{
    \"AutoSelectCertificateForUrls\": [
        \"{\\\"pattern\\\":\\\"$DOMAIN\\\",\\\"filter\\\": {\\\"ISSUER\\\":{\\\"CN\\\":\\\"$CACN\\\"}}}\"
    ],
    \"HomepageLocation\": \"$DOMAIN/$URL\"
}" > /etc/chromium/policies/managed/kiosk.json

    # Configuration for Slim
    echo "default_user kiosk" >> /etc/slim.conf
    echo "auto_login yes" >> /etc/slim.conf

    # SYSTEM USER SETUP
    # =================

    useradd -m -U kiosk
    chmod -R a+r /home/kiosk
    touch /home/kiosk/.xsession
    echo "xset s off
xset -dpms
matchbox-window-manager &
while true; do
    rsync -qr --delete --exclude='.Xauthority' /opt/kiosk/ \$HOME/
    chromium-browser --kiosk $DOMAIN/$URL
done" > /home/kiosk/.xsession
    chmod a+x /home/kiosk/.xsession
    cp /home/kiosk/.xsession /home/kiosk/.xinitrc

    # ADD CLIENT CERTIFICATES
    # =======================

    CERTSTORE="/home/kiosk/.pki/nssdb"
    mkdir -p $CERTSTORE
    chown -R kiosk:kiosk $CERTSTORE
    sudo -u kiosk certutil -d $CERTSTORE -N
    if [ $INSTALLCERT -eq 1 ]; then
        sudo -u kiosk pk12util -d "sql:$CERTSTORE" -i "/tmp/kiosk.p12" -W ""
    fi

    # CREATE CUSTOM SKEL DIRECTORY FOR SYSTEM USER
    # ============================================

    cp -r /home/kiosk /opt/

}

if [ $(id -u) -ne 0 ]; then
  printf "This script must be run as root. Try prefixing with 'sudo'.\n"
  exit 1
fi

WHIPTAILPATH=$(which whiptail)
if [ ${#WHIPTAILPATH} -eq 0 ]; then
    echo "This script requires Whiptail for its terminal GUI.\n"
    exit 1
fi

TITLE="Kiosk Setup"

# Ask whether to setup automatic login via client certificates.
whiptail --title $TITLE --yesno "Would you like to setup automatic login, via certificates, or manual login, via username and password?" 20 60 2 --yes-button "Automatic" --no-button "Manual"
AUTOLOGIN=$?

if [ $AUTOLOGIN -eq 0 ]; then
    # Ask which Loan Station we are setting up a certificate for.
    KIOSKP12=$(whiptail --inputbox "Please enter the URL of the Kiosk PKCS#12 certificate to be installed:" 8 78 --title "$TITLE" 3>&1 1>&2 2>&3)
    IDENTERED=$?
    if [ $IDENTERED = 0 ]; then
        wget "$KIOSKP12" --output-document="/tmp/kiosk.p12"
        CERTDOWNLOADED=$?
        if [ $CERTDOWNLOADED = 0 ]; then
            P12SIZE=$(stat -c %s /tmp/kiosk.p12)
            if [ $P12SIZE -ne 0 ]; then
                setup_kiosk 1
            else
                whiptail --title "$TITLE" --msgbox "The certificate downloaded for the Kiosk ID you specified is not valid. Setup has been cancelled." 8 78
            fi
        else
            whiptail --title "$TITLE" --msgbox "The certificate for the Kiosk ID you specified could not be downloaded. Setup has been cancelled." 8 78
        fi
    else
        whiptail --title "$TITLE" --msgbox "Setup has been cancelled. This is not yet a Kiosk, please run this setup again to proceed." 8 78
    fi
else
    whiptail --title "$TITLE" --msgbox "You may have to manually login to the Kiosk each time you turn the machine on." 8 78
    setup_kiosk 0
fi