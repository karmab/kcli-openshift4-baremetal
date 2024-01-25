#!/usr/bin/env bash

set -euo pipefail

export HOME=/root
export USER=root
PRIMARY_NIC=$(ls -1 /sys/class/net | grep -v podman | head -1)
export PATH=/root/bin:$PATH
export PULL_SECRET="/root/openshift_pull.json"
dnf -y install podman httpd jq libseccomp-devel
export IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d'/' -f1)
REGISTRY_NAME=$(echo $IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io
REGISTRY_USER=init
REGISTRY_PASSWORD={{ "super" + disconnected_password if disconnected_password|length < 8 else disconnected_password }}
KEY=$(echo -n $REGISTRY_USER:$REGISTRY_PASSWORD | base64)
echo "{\"auths\": {\"$REGISTRY_NAME:8443\": {\"auth\": \"$KEY\", \"email\": \"jhendrix@karmalabs.corp\"}}}" > /root/disconnected_pull.json
mv /root/openshift_pull.json /root/openshift_pull.json.old
jq ".auths += {\"$REGISTRY_NAME:8443\": {\"auth\": \"$KEY\",\"email\": \"jhendrix@karmalabs.corp\"}}" < /root/openshift_pull.json.old > $PULL_SECRET
mkdir -p /opt/registry/{auth,certs,data,conf}
openssl req -newkey rsa:4096 -nodes -sha256 -keyout /opt/registry/certs/domain.key -x509 -days 365 -out /opt/registry/certs/domain.crt -subj "/C=US/ST=Madrid/L=San Bernardo/O=Karmalabs/OU=Guitar/CN=$REGISTRY_NAME" -addext "subjectAltName=DNS:$REGISTRY_NAME"
cp /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust extract

curl -s -L https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/mirror-registry/1.0/mirror-registry.tar.gz | tar xvz -C /usr/bin
/usr/bin/mirror-registry install --quayHostname $REGISTRY_NAME --sslCert /opt/registry/certs/domain.crt --sslKey /opt/registry/certs/domain.key --initPassword $REGISTRY_PASSWORD --ssh-key /root/.ssh/id_rsa

{% if ':' in baremetal_cidr %}
mv /root/mirror-registry/quay_haproxy.cfg /etc/quay-install/haproxy.cfg
systemctl enable --now quay-haproxy
{% endif %}
