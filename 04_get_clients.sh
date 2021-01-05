#!/usr/bin/env bash

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
#echo 35.196.103.194 registry.svc.ci.openshift.org >> /etc/hosts
export OPENSHIFT_RELEASE_IMAGE={{ openshift_image }}

oc adm release extract --registry-config $PULL_SECRET --command=oc --to /tmp $OPENSHIFT_RELEASE_IMAGE
mv /tmp/oc /root/bin
oc adm release extract --registry-config $PULL_SECRET --command=openshift-baremetal-install --to /root/bin $OPENSHIFT_RELEASE_IMAGE
{% endif %}

oc completion bash >>/etc/bash_completion.d/oc_completion
