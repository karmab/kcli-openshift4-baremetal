#!/usr/bin/env bash

set -euo pipefail

dnf -y copr enable karmab/kcli
dnf -y install libvirt-libs libvirt-client mkisofs tmux make git bash-completion vim-enhanced kcli nmstate
dnf -y install python3 podman skopeo httpd

dnf -y copr enable karmab/aicli
dnf -y install aicli

systemctl enable --now httpd

update-ca-trust extract

curl -Ls https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 > /usr/bin/jq	
chmod u+x /usr/bin/jq

cd /root/bin
kcli download oc
mv oc /usr/bin
chmod +x /usr/bin/oc

kcli download kubectl
mv kubectl /usr/bin
chmod u+x /usr/bin/kubectl

kcli download openshift-install -P version={{ version }} -P tag={{ tag }} -P pull_secret=/root/openshift_pull.json -P upstream={{ okd }}
mv openshift-install /usr/bin
chmod u+x /usr/bin/openshift-install
openshift-install version | grep 'release image' | cut -d' ' -f3 > /root/version.txt

dnf install podman skopeo -y

oc completion bash >>/etc/bash_completion.d/oc_completion
