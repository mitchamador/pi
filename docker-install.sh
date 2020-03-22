#!/bin/bash
sudo apt update && sudo apt -y upgrade

id=$(lsb_release -is | tr '[:upper:]' '[:lower:]')

sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg
curl -fsSL https://download.docker.com/linux/$id/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=armhf] https://download.docker.com/linux/$id \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get -y install docker-ce
