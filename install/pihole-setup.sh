#!/bin/bash
iptables -t nat -A POSTROUTING -s 172.21.0.0/16 -j MASQUERADE
docker network create --driver=bridge \
  --subnet 172.21.0.0/16 \
  --gateway=172.21.0.1 \
  -o "com.docker.network.bridge.name"="docker-apps" \
  -o "com.docker.network.bridge.enable_ip_masquerade"="true" \
  -o "com.docker.network.bridge.enable_icc"="true" \
  -o "com.docker.network.driver.mtu"="1500" \
  apps
tailscale up --accept-routes --advertise-routes=172.21.0.0/16