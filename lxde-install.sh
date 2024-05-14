#!/bin/bash

[ -z $VNC_RESOLUTION ] && VNC_RESOLUTION="1920x1080"
[ -z $VNC_DEPTH ] && VNC_DEPTH="16"
[ -z $VNC_DPI ] && VNC_DPI="120"

packages="tightvncserver xfonts-base autocutsel lxde dbus-x11 policykit-1 lxpolkit lxsession-logout lxtask"

dist=$(grep ^ID= /etc/*-release | awk -F '=' '{print $2}')
version=$(grep ^VERSION_ID= /etc/*-release | awk -F '=' '{print $2}' | tr -d '"')

packages_ubuntu_1604="gnome-themes-ubuntu adwaita-icon-theme-full ttf-ubuntu-font-family qt4-qtconfig"
packages_ubuntu_1804="gnome-themes-ubuntu adwaita-icon-theme-full ttf-ubuntu-font-family qt4-qtconfig"
packages_ubuntu_2004="gnome-themes-ubuntu adwaita-icon-theme-full ttf-ubuntu-font-family adwaita-qt qt5ct"
packages_ubuntu_2204="gnome-themes-ubuntu adwaita-icon-theme-full adwaita-qt qt5ct"
packages_debian_9="gtk2-engines qt4-qtconfig"
packages_debian_10="gtk2-engines qt4-qtconfig"
packages_debian_11="gtk2-engines adwaita-qt qt5ct"
packages_debian_12="gtk2-engines adwaita-qt qt5ct"

var=packages_${dist}_${version//[-._]/}

if [ ! -z "${!var}" ]; then
  packages+=" ${!var}"
else
  echo $dist $version is not supported
  exit 1
fi

echo $packages | grep qt5ct >/dev/null && echo "QT_QPA_PLATFORMTHEME=qt5ct" | sudo tee -a /etc/environment >/dev/null
 
sudo apt update
sudo apt -y upgrade
sudo apt -y --no-install-recommends install $packages

wget -q -O - https://github.com/mitchamador/pi/raw/master/segoeui.tar.gz | sudo tar -zxv -C /usr/share/fonts/truetype/ >/dev/null
sudo fc-cache -f -v >/dev/null

vncpass=$1

if [ ! -e ~/.vnc/passwd ]; then
  if [ "$vncpass" == "" ]; then
    read -p "enter vnc password:" -s vncpass
    echo
  fi

  [ -d ~/.vnc ] || mkdir ~/.vnc
  printf "$vncpass\n" | vncpasswd -f >~/.vnc/passwd
  chmod 600 ~/.vnc/passwd
fi

[ -e ~/.Xresources ] || touch ~/.Xresources
[ -e ~/.Xauthority ] || touch ~/.Xauthority

if [ ! -e ~/.vnc/xstartup ]; then
   /usr/bin/tightvncserver :0 -desktop X -geometry $VNC_RESOLUTION -depth $VNC_DEPTH -dpi $VNC_DPI
   sleep 5
   /usr/bin/tightvncserver -kill :0
fi

grep "autocutsel -fork" ~/.vnc/xstartup >/dev/null || sed -i '\/etc\/X11\/Xsession/iautocutsel -fork' ~/.vnc/xstartup

sed -i -e 's/^sNet\/ThemeName.*/sNet\/ThemeName=Clearlooks/g' -e 's/^sNet\/IconThemeName.*/sNet\/IconThemeName=nuoveXT2/g' -e 's/^sGtk\/FontName.*/sGtk\/FontName=Segoe UI 10/g' -e 's/^sGtk\/CursorThemeName.*/sGtk\/CursorThemeName=Adwaita/g' ~/.config/lxsession/LXDE/desktop.conf

sed -i -e 's/<weight>.*<\/weight>/<weight>normal<\/weight>/g' -e 's/<weight\/>/<weight>normal<\/weight>/g' -e 's/<size>.*<\/size>/<size>10<\/size>/g' -e 's/<name>sans<\/name>/<name>Segoe UI<\/name>/gI' -e 's/<name>onyx<\/name>/<name>Bear2<\/name>/gI' ~/.config/openbox/lxde-rc.xml

sudo wget -q -O /usr/share/lxpanel/images/black-33.png https://github.com/mitchamador/pi/raw/master/lxpanel/black-33.png
sed 's:height=.*:height=33:g;s:backgroundfile=.*:backgroundfile=/usr/share/lxpanel/images/black-33.png:g' /etc/xdg/lxpanel/default/panels/panel >~/.config/lxpanel/LXDE/panels/panel

echo $packages | grep qt5ct >/dev/null && (
  mkdir -p ~/.config/qt5ct
  cat <<EOF >~/.config/qt5ct/qt5ct.conf
[Fonts]
fixed=@Variant(\0\0\0@\0\0\0\x12\0M\0o\0n\0o\0s\0p\0\x61\0\x63\0\x65@$\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
general=@Variant(\0\0\0@\0\0\0\x10\0S\0\x65\0g\0o\0\x65\0 \0U\0I@$\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
EOF
) || (
  cat <<EOF >.config/Trolltech.conf
[Qt]
font="Segoe UI,10,-1,5,50,0,0,0,0,0"
EOF
)

sudo systemctl disable lightdm.service

systemd_system_ubuntu_1604="yes"
systemd_system_debian_9="yes"

var=systemd_system_${dist}_${version//[-._]/}

if [ -z "${!var}" ]; then

  mkdir -p ~/.local/share/systemd/user

  cat <<EOF | tee ~/.local/share/systemd/user/vncserver@.service >/dev/null
[Unit]
Description=Start TightVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
ExecStartPre=-/usr/bin/tightvncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/tightvncserver :%i -desktop X -geometry $VNC_RESOLUTION -depth $VNC_DEPTH -dpi $VNC_DPI
ExecStop=/usr/bin/tightvncserver -kill :%i

[Install]
WantedBy=default.target
EOF

  systemctl daemon-reload --user
  systemctl enable vncserver@0.service --user
  systemctl start vncserver@0.service --user

else

  cat <<EOF | sudo tee /etc/systemd/system/vncserver@.service >/dev/null
[Unit]
Description=Start TightVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=${USER}
Group=${USER}
WorkingDirectory=/home/${USER}
PAMName=login
PIDFile=/home/${USER}/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/tightvncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/tightvncserver :%i -desktop X -geometry $VNC_RESOLUTION -depth $VNC_DEPTH -dpi $VNC_DPI
ExecStop=/usr/bin/tightvncserver -kill :%i
#Restart=on-failure
#RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable vncserver@0.service
  sudo systemctl start vncserver@0.service

fi

echo "done"
