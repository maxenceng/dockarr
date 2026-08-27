#!/bin/bash

set -e

apt update
apt upgrade -y
apt install -y curl apt-transport-https ca-certificates software-properties-common gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl status docker --no-pager

cp docker/daemon.json /etc/docker/
mkdir -p /etc/systemd/system/docker.service.d/
cp docker/override.conf /etc/systemd/system/docker.service.d/
systemctl daemon-reload
systemctl restart docker.service
