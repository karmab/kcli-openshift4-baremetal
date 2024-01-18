#!/usr/bin/env bash

set -euo pipefail

PRIMARY_NIC=$(ls -1 /sys/class/net | grep -v podman | head -1)
yum -y install clevis tang
semanage port -a -t tangd_port_t -p tcp 7500
# firewall-cmd --add-port=7500/tcp
systemctl enable tangd.socket
mkdir /etc/systemd/system/tangd.socket.d
echo """[Socket]
ListenStream=
ListenStream=7500""" > /etc/systemd/system/tangd.socket.d/overrides.conf
systemctl daemon-reload
jose jwk gen -i '{"alg":"ES512"}' -o /var/db/tang/newsig.jwk
jose jwk gen -i '{"alg":"ECMR"}' -o /var/db/tang/newexc.jwk
systemctl start tangd.socket

export IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d'/' -f1)
export TANG_URL=http://"$IP:7500"
export THP="$(tang-show-keys 7500)"
export ROLE=worker
envsubst < /root/machineconfigs/99-openshift-tang-encryption-clevis.sample.yaml > /root/manifests/99-openshift-worker-tang-encryption-clevis.yaml
envsubst < /root/machineconfigs/99-openshift-tang-encryption-ka.sample.yaml > /root/manifests/99-openshift-worker-tang-encryption-ka.yaml
export ROLE=master
envsubst < /root/machineconfigs/99-openshift-tang-encryption-clevis.sample.yaml > /root/manifests/99-openshift-ctlplane-tang-encryption-clevis.yaml
envsubst < /root/machineonfigs/99-openshift-tang-encryption-ka.sample.yaml > /root/manifests/99-openshift-ctlplane-tang-encryption-ka.yaml
