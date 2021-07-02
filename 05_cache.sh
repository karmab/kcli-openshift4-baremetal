#!/usr/bin/env bash

set -euo pipefail

export PATH=/root/bin:$PATH
dnf -y install httpd
dnf -y update libgcrypt
systemctl enable --now httpd
cd /var/www/html
if openshift-baremetal-install coreos print-stream-json >/dev/null 2>&1; then
    RHCOS_OPENSTACK_URI_FULL=$(openshift-baremetal-install coreos print-stream-json | jq -r '.architectures.x86_64.artifacts.openstack.formats["qcow2.gz"].disk.location')
    RHCOS_QEMU_URI_FULL=$(openshift-baremetal-install coreos print-stream-json | jq -r '.architectures.x86_64.artifacts.qemu.formats["qcow2.gz"].disk.location')
    RHCOS_QEMU_SHA_UNCOMPRESSED=$(openshift-baremetal-install coreos print-stream-json | jq -r '.architectures.x86_64.artifacts.qemu.formats["qcow2.gz"].disk["uncompressed-sha256"]')
    RHCOS_OPENSTACK_SHA_COMPRESSED=$(openshift-baremetal-install coreos print-stream-json | jq -r '.architectures.x86_64.artifacts.openstack.formats["qcow2.gz"].disk["sha256"]')
    RHCOS_QEMU_URI=$(basename $RHCOS_QEMU_URI_FULL)
    RHCOS_OPENSTACK_URI=$(basename $RHCOS_OPENSTACK_URI_FULL)
    curl -L $RHCOS_QEMU_URI_FULL > $RHCOS_QEMU_URI
    curl -L $RHCOS_OPENSTACK_URI_FULL > $RHCOS_OPENSTACK_URI
else
    if [ -z "${COMMIT_ID-}" ] ; then
      export COMMIT_ID=$(openshift-baremetal-install version | grep '^built from commit' | awk '{print $4}')
    fi
    RHCOS_OPENSTACK_URI=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json  | jq .images.openstack.path | sed 's/"//g')
    RHCOS_QEMU_URI=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json  | jq .images.qemu.path | sed 's/"//g')
    RHCOS_PATH=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json | jq .baseURI | sed 's/"//g')
    RHCOS_QEMU_SHA_UNCOMPRESSED=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json  | jq -r '.images.qemu["uncompressed-sha256"]')
    RHCOS_OPENSTACK_SHA_COMPRESSED=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json  | jq -r '.images.openstack.sha256')
    curl -L $RHCOS_PATH$RHCOS_QEMU_URI > $RHCOS_QEMU_URI
    curl -L $RHCOS_PATH$RHCOS_OPENSTACK_URI > $RHCOS_OPENSTACK_URI
fi

{% if patch_rhcos_image %}
dnf -y install libguestfs-tools
export LIBGUESTFS_BACKEND=direct
STACK={{ 'dhcp6' if ':' in api_ip and not dualstack else 'dhcp' }}
EXTRACTED_FILE=openstack.qcow2
gunzip -c $RHCOS_OPENSTACK_URI > $EXTRACTED_FILE
BOOT_DISK=$(virt-filesystems -a $EXTRACTED_FILE -l | grep boot | cut -f1 -d" ")
virt-edit -a $EXTRACTED_FILE -m $BOOT_DISK /boot/loader/entries/ostree-1-rhcos.conf -e "s/^options/options ip=$STACK/"
gzip -c $EXTRACTED_FILE > $RHCOS_OPENSTACK_URI
RHCOS_OPENSTACK_SHA_COMPRESSED=$(sha256sum $RHCOS_OPENSTACK_URI | cut -d " " -f1)
EXTRACTED_FILE=qemu.qcow2
gunzip -c $RHCOS_QEMU_URI > $EXTRACTED_FILE
BOOT_DISK=$(virt-filesystems -a $EXTRACTED_FILE -l | grep boot | cut -f1 -d" ")
virt-edit -a $EXTRACTED_FILE -m $BOOT_DISK /boot/loader/entries/ostree-1-rhcos.conf -e "s/^options/options ip=$STACK/"
gzip -c $EXTRACTED_FILE > $RHCOS_QEMU_URI
RHCOS_QEMU_SHA_UNCOMPRESSED=$(sha256sum $EXTRACTED_FILE | cut -d " " -f1)
unset LIBGUESTFS_BACKEND
{% endif %}

SPACES=$(grep apiVIP /root/install-config.yaml | sed 's/apiVIP.*//' | sed 's/ /\\ /'g)
export BAREMETAL_IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d'/' -f1)
echo $BAREMETAL_IP | grep -q ':' && BAREMETAL_IP=[$BAREMETAL_IP]
sed -i "/apiVIP/i${SPACES}bootstrapOSImage: http://${BAREMETAL_IP}/${RHCOS_QEMU_URI}?sha256=${RHCOS_QEMU_SHA_UNCOMPRESSED}" /root/install-config.yaml
sed -i "/apiVIP/i${SPACES}clusterOSImage: http://${BAREMETAL_IP}/${RHCOS_OPENSTACK_URI}?sha256=${RHCOS_OPENSTACK_SHA_COMPRESSED}" /root/install-config.yaml

{% if acm %}
RHCOS_AI="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/pre-release/latest-4.8/rhcos-live.x86_64.iso"
RHCOS_ROOTFS="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/pre-release/latest-4.8/rhcos-live-rootfs.x86_64.img"
curl -Lk $RHCOS_AI > /var/www/html/$(basename $RHCOS_AI)
curl -Lk $RHCOS_ROOTFS > /var/www/html/$(basename $RHCOS_ROOTFS)
{% endif %}
