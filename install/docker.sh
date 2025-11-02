#!/bin/bash

apt update
apt upgrade
apt install curl apt-transport-https ca-certificates software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt install docker-ce
systemctl status docker
cp docker/daemon.json /etc/docker/
mkdir /etc/systemd/system/docker.service.d/
cp docker/override.conf /etc/systemd/system/docker.service.d/
systemctl daemon-reload
systemctl restart docker.service
