#!/usr/bin/env bash

set -euo pipefail

PRIMARY_NIC=$(ls -1 /sys/class/net | grep -v podman | head -1)
{% if not 'rhel' in image %}
dnf clean all
sleep 30
{% endif %}
echo "fastestmirror=1" >> /etc/dnf/dnf.conf
dnf -y install pkgconf-pkg-config libvirt-devel gcc python3-libvirt python3 git python3-netifaces

dnf -y copr enable karmab/kcli
dnf -y install kcli

SUSHYFLAGS={{ "--ipv6" if ':' in baremetal_cidr else "" }}
kcli create sushy-service $SUSHYFLAGS

ssh-keyscan -H {{ config_host if config_host not in ['127.0.0.1', 'localhost'] else baremetal_net|local_ip }} >> /root/.ssh/known_hosts
echo -e "Host=*\nStrictHostKeyChecking=no\n" > /root/.ssh/config
IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d "/" -f 1 | head -1)
echo $IP | grep -q ':' && IP=[$IP]
sed -i "s/CHANGEME/$IP/" /root/aicli_parameters.yml

echo {{ api_ip }} api.{{ cluster }}.{{ domain }} >> /etc/hosts
