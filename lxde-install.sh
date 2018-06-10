#!/bin/bash
sudo apt update
packages="tightvncserver xfonts-base autocutsel lxde-core lxde-common obconf lxterminal lxappearance lxappearance-obconf qt4-qtconfig lxpolkit dbus-x11"

dist=$(grep ^ID= /etc/*-release | awk -F '=' '{print $2}')
if [ "$dist" == "ubuntu" ]; then
  packages+=" gnome-themes-ubuntu adwaita-icon-theme-full ttf-ubuntu-font-family"
elif [ "$dist" == "debian" ]; then
  packages+=" gtk2-engines"
else
  echo "no ubuntu, no debian, so exit..."
  exit
fi

sudo apt -y install $packages

vncpass=$1

if [ -z $1 ]; then
  read -p "enter vnc password:" -s vncpass
  echo
fi

[ -d ~/.vnc ] || mkdir ~/.vnc
printf "$vncpass\n" | vncpasswd -f >~/.vnc/passwd
chmod 600 ~/.vnc/passwd

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
ExecStart=/usr/bin/tightvncserver :%i -desktop X -auth /home/${USER}/.Xauthority -geometry 1366x768 -depth 16 -rfbwait 120000 -rfbauth /home/${USER}/.vnc/passwd -fp /usr/share/fonts/X11/misc/,/usr/share/fonts/X11/Type1/,/usr/share/fonts/X11/75dpi/,/usr/share/fonts/X11/100dpi/ -co /etc/X11/rgb -dpi 100
ExecStop=/usr/bin/tightvncserver -kill :%i
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable vncserver@0.service

sudo systemctl start vncserver@0.service

grep "autocutsel -fork" ~/.vnc/xstartup >/dev/null || sed -i '\/etc\/X11\/Xsession/iautocutsel -fork' ~/.vnc/xstartup

wget -q -O - https://github.com/mitchamador/pi/raw/master/segoeui.tar.gz | sudo tar -zxv -C /usr/share/fonts/truetype/

sudo fc-cache -f -v >/dev/null

echo "reboot needed..."
