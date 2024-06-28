#!/bin/bash

[ -z $VNC_RESOLUTION ] && VNC_RESOLUTION="1920x1080"
[ -z $VNC_DEPTH ] && VNC_DEPTH="16"
[ -z $VNC_DPI ] && VNC_DPI="120"

packages="autocutsel xfonts-base dbus-x11 policykit-1 gtk2-engines x11-xserver-utils "
packages+="libxfce4ui-utils thunar xfce4-appfinder xfce4-panel xfce4-pulseaudio-plugin xfce4-whiskermenu-plugin xfce4-session xfce4-settings xfce4-terminal xfconf xfdesktop4 xfwm4 "

dist=$(grep ^ID= /etc/*-release | awk -F '=' '{print $2}')
version=$(grep ^VERSION_ID= /etc/*-release | awk -F '=' '{print $2}' | tr -d '"')

#packages_ubuntu_1604="gnome-themes-ubuntu adwaita-icon-theme-full ttf-ubuntu-font-family qt4-qtconfig tightvncserver"
packages_ubuntu_1804="gnome-themes-ubuntu adwaita-icon-theme-full ttf-ubuntu-font-family qt4-qtconfig"
packages_ubuntu_2004="gnome-themes-ubuntu adwaita-icon-theme-full ttf-ubuntu-font-family adwaita-qt qt5ct"
packages_ubuntu_2204="gnome-themes-ubuntu adwaita-icon-theme-full tigervnc-tools adwaita-qt qt5ct"
packages_debian_9="gnome-themes-extra adwaita-icon-theme qt4-qtconfig"
packages_debian_10="gnome-themes-extra adwaita-icon-theme qt4-qtconfig"
packages_debian_11="gnome-themes-extra adwaita-icon-theme adwaita-qt qt5ct"
packages_debian_12="gnome-themes-extra adwaita-icon-theme tigervnc-tools adwaita-qt qt5ct"

var=packages_${dist}_${version//[-._]/}

if [ ! -z "${!var}" ]; then
  packages+="${!var}"
else
  echo $dist $version is not supported
  exit 1
fi

echo $packages | grep tightvncserver >/dev/null || packages+=" tigervnc-common tigervnc-standalone-server tigervnc-xorg-extension"

sudo apt update
sudo apt -y upgrade
sudo apt -y --no-install-recommends install $packages

wget -q -O - https://github.com/mitchamador/pi/raw/master/segoeui.tar.gz | sudo tar -zxv -C /usr/share/fonts/truetype/ >/dev/null
sudo fc-cache -f -v >/dev/null

[ -d ~/.vnc ] || mkdir ~/.vnc

if [ "$1" == "" ]; then
  INSECURE_COMMENT=""
  INSECURE_COMMENT_TIGERVNC=""
  touch ~/.vnc/passwd
else
  INSECURE_COMMENT="#"
  INSECURE_COMMENT_TIGERVNC="#"
  printf "$1\n" | vncpasswd -f >~/.vnc/passwd
fi

echo $packages | grep tightvncserver >/dev/null && INSECURE_COMMENT_TIGERVNC="#"

printf "${INSECURE_COMMENT}\$authType = \"\";\n" >~/.vnc/tightvncserver.conf
printf "${INSECURE_COMMENT}\$SecurityTypes = \"None,TLSNone\";\n" >~/.vnc/tigervnc.conf
printf "${INSECURE_COMMENT_TIGERVNC}VNC_EXTRA_ARGS=\"--I-KNOW-THIS-IS-INSECURE\"\n" >~/.vnc/extraargs

chmod 600 ~/.vnc/passwd

[ -e ~/.Xresources ] || touch ~/.Xresources
[ -e ~/.Xauthority ] || touch ~/.Xauthority

printf "\$localhost = \"no\";\n" >>~/.vnc/tigervnc.conf


cat <<EOF >~/.vnc/xstartup
#!/bin/sh

xrdb $HOME/.Xresources
xsetroot -solid grey
#x-terminal-emulator -geometry 80x24+10+10 -ls -title "$VNCDESKTOP Desktop" &
#x-window-manager &
# Fix to make GNOME work
export XKL_XMODMAP_DISABLE=1
autocutsel -fork
/etc/X11/Xsession
EOF

chmod +x ~/.vnc/xstartup

mkdir -p ~/.config/xfce4/terminal
cat <<EOF >~/.config/xfce4/terminal/terminalrc
[Configuration]
FontName=Monospace 10
EOF

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
style=GTK+
EOF
)

echo $packages | grep qt5ct >/dev/null && echo "QT_QPA_PLATFORMTHEME=qt5ct" | sudo tee -a /etc/environment >/dev/null

cat <<EOF | sudo tee /etc/systemd/system/vncserver@.service >/dev/null
[Unit]
Description=Start VNC server at startup
After=syslog.target network.target

[Service]
Type=oneshot
RemainAfterExit=yes

EnvironmentFile=/home/${USER}/.vnc/extraargs
ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill :%i > /dev/null 2>&1 || :'
ExecStart=/sbin/runuser -l ${USER} -c "/usr/bin/vncserver :%i -geometry $VNC_RESOLUTION -depth $VNC_DEPTH -dpi $VNC_DPI \${VNC_EXTRA_ARGS}"
ExecStop=/sbin/runuser -l ${USER} -c '/usr/bin/vncserver -kill :%i'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable vncserver@0.service
sudo systemctl restart vncserver@0.service

DISPLAY=:0 xfconf-query -c xfwm4 -np /general/title_font -t "string" -s "Segoe UI Bold 10"
DISPLAY=:0 xfconf-query -c xfwm4 -np /general/workspace_count -t "int" -s "2"
DISPLAY=:0 xfconf-query -c xsettings -np /Gtk/FontName -t "string" -s "Segoe UI 10"
DISPLAY=:0 xfconf-query -c xsettings -np /Gtk/MonospaceFontName -t "string" -s "Monospace 10"
DISPLAY=:0 xfconf-query -c xsettings -np /Xft/DPI -t "int" -s "$VNC_DPI"
DISPLAY=:0 xfconf-query -c xsettings -np /Net/ThemeName -t "string" -s "Adwaita"
DISPLAY=:0 xfconf-query -c xsettings -np /Net/IconThemeName -t "string" -s "Adwaita"
DISPLAY=:0 xfconf-query -c xfce4-panel -np /panels/panel-1/size -t "int" -s "33"

echo "done"
