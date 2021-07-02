#!/usr/bin/env bash

set -euo pipefail

curl -Ls https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 > /usr/bin/jq	
chmod u+x /usr/bin/jq

cd /root/bin
curl -k -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz > oc.tar.gz
tar zxf oc.tar.gz
rm -rf oc.tar.gz
mv oc /usr/bin
chmod +x /usr/bin/oc

curl -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl > /usr/bin/kubectl
chmod u+x /usr/bin/kubectl

{% if not build %}
export PULL_SECRET="/root/openshift_pull.json"
{% if version == 'nightly' %}
{% set tag = tag|string %}
TAG={{ tag if tag.split('.')|length > 2 else "latest-" + tag }}
export OPENSHIFT_RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/$TAG/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}')
{% elif version in ['latest', 'stable'] %}
export OPENSHIFT_RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/{{ version }}-{{ tag }}/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}')
{% elif version == 'ci' %}
export OPENSHIFT_RELEASE_IMAGE={{ openshift_image }}
{% endif %}
oc adm release extract --registry-config $PULL_SECRET --command=oc --to /tmp $OPENSHIFT_RELEASE_IMAGE
mv /tmp/oc /root/bin
oc adm release extract --registry-config $PULL_SECRET --command=openshift-baremetal-install --to /root/bin $OPENSHIFT_RELEASE_IMAGE
{% endif %}
echo $OPENSHIFT_RELEASE_IMAGE > /root/version.txt

# install neat plugin
curl -s -L https://github.com/itaysk/kubectl-neat/releases/download/v2.0.3/kubectl-neat_linux_amd64.tar.gz | tar xvz -C /usr/bin/

oc completion bash >>/etc/bash_completion.d/oc_completion
