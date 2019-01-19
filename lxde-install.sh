#!/bin/bash

packages="tightvncserver xfonts-base autocutsel lxde qt4-qtconfig dbus-x11 policykit-1 lxpolkit lxsession-logout lxtask"

dist=$(grep ^ID= /etc/*-release | awk -F '=' '{print $2}')
if [ "$dist" == "ubuntu" ]; then
  packages+=" gnome-themes-ubuntu adwaita-icon-theme-full ttf-ubuntu-font-family"
elif [ "$dist" == "debian" ]; then
  packages+=" gtk2-engines"
else
  echo "no ubuntu, no debian, so exit..."
  exit
fi

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
   /usr/bin/tightvncserver :0 -desktop X -geometry 1366x768 -depth 16 -dpi 96
   sleep 5
   /usr/bin/tightvncserver -kill :0
fi

grep "autocutsel -fork" ~/.vnc/xstartup >/dev/null || sed -i '\/etc\/X11\/Xsession/iautocutsel -fork' ~/.vnc/xstartup

sed -i -e 's/^sNet\/ThemeName.*/sNet\/ThemeName=Clearlooks/g' -e 's/^sNet\/IconThemeName.*/sNet\/IconThemeName=nuoveXT2/g' -e 's/^sGtk\/FontName.*/sGtk\/FontName=Segoe UI 8/g' -e 's/^sGtk\/CursorThemeName.*/sGtk\/CursorThemeName=Adwaita/g' ~/.config/lxsession/LXDE/desktop.conf

sed -i -e 's/<weight>.*<\/weight>/<weight>normal<\/weight>/g' -e 's/<weight\/>/<weight>normal<\/weight>/g' -e 's/<size>.*<\/size>/<size>8<\/size>/g' -e 's/<name>sans<\/name>/<name>Segoe UI<\/name>/gI' -e 's/<name>onyx<\/name>/<name>Bear2<\/name>/gI' ~/.config/openbox/lxde-rc.xml


cat <<EOF | sudo tee /etc/systemd/system/vncserver@.service >/dev/null
[Unit]
Description=Start TightVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=${USER}
PAMName=login
PIDFile=/home/${USER}/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/tightvncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/tightvncserver :%i -desktop X -geometry 1366x768 -depth 16 -dpi 96
ExecStop=/usr/bin/tightvncserver -kill :%i
#Restart=on-failure
#RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable vncserver@0.service
sudo systemctl start vncserver@0.service

echo "done"
