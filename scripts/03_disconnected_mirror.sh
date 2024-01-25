#!/usr/bin/env bash

set -euo pipefail

PRIMARY_NIC=$(ls -1 /sys/class/net | grep 'eth\|en' | head -1)
export IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d'/' -f1)
export PATH=/root/bin:$PATH
export PULL_SECRET="/root/openshift_pull.json"
{% if disconnected_url != None %}
{% set registry_port = disconnected_url.split(':')[-1] %}
{% set registry_name = disconnected_url|replace(":" + registry_port, '') %}
REGISTRY_NAME={{ registry_name }}
REGISTRY_PORT={{ registry_port }}
REGISTRY_USER={{ disconnected_user }}
REGISTRY_PASSWORD={{ disconnected_password }}
KEY=$(echo -n $REGISTRY_USER:$REGISTRY_PASSWORD | base64)
echo "{\"auths\": {\"$REGISTRY_NAME:$REGISTRY_PORT\": {\"auth\": \"$KEY\", \"email\": \"jhendrix@karmalabs.corp\"}}}" > /root/disconnected_pull.json
mv /root/openshift_pull.json /root/openshift_pull.json.old
jq ".auths += {\"$REGISTRY_NAME:$REGISTRY_PORT\": {\"auth\": \"$KEY\",\"email\": \"jhendrix@karmalabs.corp\"}}" < /root/openshift_pull.json.old > $PULL_SECRET
mkdir -p /opt/registry/certs
openssl s_client -showcerts -connect $REGISTRY_NAME:$REGISTRY_PORT </dev/null 2>/dev/null|openssl x509 -outform PEM > /opt/registry/certs/domain.crt
cp /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors
update-ca-trust extract
{% else %}
REGISTRY_NAME=$(echo $IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io
REGISTRY_PORT={{ 8443 if disconnected_quay else 5000 }}
{% endif %}

export OPENSHIFT_RELEASE_IMAGE=$(openshift-install version | grep 'release image' | awk -F ' ' '{print $3}')
export LOCAL_REG="$REGISTRY_NAME:$REGISTRY_PORT"
export OCP_RELEASE=$(openshift-install version | head -1 | cut -d' ' -f2)-x86_64
oc adm release mirror -a $PULL_SECRET --from=$OPENSHIFT_RELEASE_IMAGE --to-release-image=${LOCAL_REG}/openshift/release-images:${OCP_RELEASE} --to=${LOCAL_REG}/openshift/release

{% for release in disconnected_extra_releases %}
EXTRA_OCP_RELEASE={{ release.split(':')[1] }}
oc adm release mirror -a $PULL_SECRET --from={{ release }} --to-release-image=${LOCAL_REG}/openshift/release-images:${EXTRA_OCP_RELEASE} --to=${LOCAL_REG}/openshift/release
{% endfor %}

echo $REGISTRY_NAME:$REGISTRY_PORT/openshift/release-images:$OCP_RELEASE > /root/version.txt
echo -e "onprem_ip: $IP" >> /root/aicli_parameters.yml
echo -e "ocp_release_image: $REGISTRY_NAME:$REGISTRY_PORT/openshift/release-images:$OCP_RELEASE" >> /root/aicli_parameters.yml

# if [ "$(grep pull_secret /root/aicli_parameters.yml)" == "" ] ; then
# echo -e "pull_secret: /root/disconnected_pull.json" >> /root/aicli_parameters.yml
# fi

mkdir /root/containers
export REGISTRY=$REGISTRY_NAME:$REGISTRY_PORT
envsubst < /root/registries.conf.sample > /root/containers/registries.conf

cp /root/machineconfigs/99-operatorhub.yaml /root/manifests

{% for image in disconnected_extra_images + ['quay.io/edge-infrastructure/assisted-installer-agent:latest', 'quay.io/edge-infrastructure/assisted-installer:latest', 'quay.io/edge-infrastructure/assisted-installer-controller:latest'] %}
echo "Syncing image {{ image }}"
/root/bin/sync_image.sh {{ image }}
{% endfor %}
