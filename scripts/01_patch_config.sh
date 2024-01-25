#!/usr/bin/env bash

set -euo pipefail

[ -d /root/manifests ] || mkdir -p /root/manifests
ssh-keyscan -H {{ config_host if config_host not in ['127.0.0.1', 'localhost'] else baremetal_net|local_ip }} >> ~/.ssh/known_hosts
echo -e "Host=*\nStrictHostKeyChecking=no\n" > ~/.ssh/config
