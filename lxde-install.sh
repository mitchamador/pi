#!/bin/bash

packages="tightvncserver xfonts-base autocutsel lxde dbus-x11 policykit-1 lxpolkit lxsession-logout lxtask"

dist=$(grep ^ID= /etc/*-release | awk -F '=' '{print $2}')
version=$(grep ^VERSION_ID= /etc/*-release | awk -F '=' '{print $2}' | tr -d '"')
if [ "$dist" == "ubuntu" ]; then
  if [ "$version" == "16.04" -o "$version" == "18.04" -o "$version" == "20.04" ]; then
    packages+=" gnome-themes-ubuntu adwaita-icon-theme-full ttf-ubuntu-font-family"
    if [ "$version" == "16.04" -o "$version" == "18.04" ]; then
      packages+=" qt4-qtconfig"
    fi
  elif [ "$version" == "22.04" ]; then
    packages+=" gnome-themes-ubuntu adwaita-icon-theme-full"
  else
    echo "ubuntu 16.04, 18.04, 20.04 and 22.04 is supported"
  fi
elif [ "$dist" == "debian" ]; then
  if [ "$version" == "9" -o "$version" == "10" -o "$version" == "11" -o "$version" == "12" ]; then
    packages+=" gtk2-engines"
    if [ "$version" == "9" -o "$version" == "10" ]; then
      packages+=" qt4-qtconfig"
  fi
  else
    echo "debian 9, 10, 11 and 12 is supported"
  fi
else
  echo "no ubuntu, no debian, so exit..."
  exit
fi

echo $packages | grep qt4-qtconfig >/dev/null || packages+=" qt5ct"
echo $packages | grep qt5ct >/dev/null && echo "QT_QPA_PLATFORMTHEME=qt5ct" | sudo tee -a /etc/environment
 
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
   /usr/bin/tightvncserver :0 -desktop X -geometry 1600x900 -depth 16 -dpi 120
   sleep 5
   /usr/bin/tightvncserver -kill :0
fi

grep "autocutsel -fork" ~/.vnc/xstartup >/dev/null || sed -i '\/etc\/X11\/Xsession/iautocutsel -fork' ~/.vnc/xstartup

sed -i -e 's/^sNet\/ThemeName.*/sNet\/ThemeName=Clearlooks/g' -e 's/^sNet\/IconThemeName.*/sNet\/IconThemeName=nuoveXT2/g' -e 's/^sGtk\/FontName.*/sGtk\/FontName=Segoe UI 8/g' -e 's/^sGtk\/CursorThemeName.*/sGtk\/CursorThemeName=Adwaita/g' ~/.config/lxsession/LXDE/desktop.conf

sed -i -e 's/<weight>.*<\/weight>/<weight>normal<\/weight>/g' -e 's/<weight\/>/<weight>normal<\/weight>/g' -e 's/<size>.*<\/size>/<size>8<\/size>/g' -e 's/<name>sans<\/name>/<name>Segoe UI<\/name>/gI' -e 's/<name>onyx<\/name>/<name>Bear2<\/name>/gI' ~/.config/openbox/lxde-rc.xml

sudo systemctl disable lightdm.service

if [ "$dist" == "ubuntu" -a "$version" == "16.04" ]; then
  systemd_user=no
elif [ "$dist" == "debian" -a "$version" == "9" ]; then
  systemd_user=no
fi

if [ "$systemd_user" != "no" ]; then

mkdir -p ~/.local/share/systemd/user

cat <<EOF | tee ~/.local/share/systemd/user/vncserver@.service >/dev/null
[Unit]
Description=Start TightVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
ExecStartPre=-/usr/bin/tightvncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/tightvncserver :%i -desktop X -geometry 1366x768 -depth 16 -dpi 96
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

fi

echo "done" 
