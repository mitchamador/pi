# bash scripts for ~~arm sbc~~ debian/ubuntu

scripts for install vnc and docker.

install lxde with tightvncserver
```
wget -q https://github.com/mitchamador/pi/raw/master/lxde-install.sh -O - | bash -s -- <your password>
```

install docker
```
wget -q https://github.com/mitchamador/pi/raw/master/docker-install.sh -O - | bash -s
```

~~note, there are some errors for newer systemd when starting vncserver.~~
