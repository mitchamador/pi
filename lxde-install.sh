#!/bin/bash
sudo apt -y install tightvncserver lxde-core lxde-common gnome-themes-ubuntu gtk2-engines-murrine xfonts-base ttf-ubuntu-font-family lxappearance lxappearance-obconf qt4-qtconfig lxpolkit dbus-x11

vncpasswd

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

wget -q -O - https://github.com/mitchamador/pi/raw/master/segoeui.tar.gz | sudo tar -zxv -C /usr/share/fonts/truetype/

sudo fc-cache -f -v >/dev/null
