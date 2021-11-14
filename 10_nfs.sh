
set -euo pipefail

DEFAULT_NIC=$(ip r | grep default | head -1 | cut -d" " -f 5)
export KUBECONFIG=/root/ocp/auth/kubeconfig
export PRIMARY_IP=$(ip -o addr show $DEFAULT_NIC | head -1 | awk '{print $4}' | cut -d'/' -f1)
dnf -y install nfs-utils
systemctl disable --now firewalld || true
systemctl enable --now nfs-server
export MODE="ReadWriteOnce"
for i in `seq 1 20` ; do
    export PV=pv`printf "%03d" ${i}`
    mkdir /$PV
    echo "/$PV *(rw,no_root_squash)"  >>  /etc/exports
    chcon -t svirt_sandbox_file_t /$PV
    chmod 777 /$PV
    [ "$i" -gt "10" ] && export MODE="ReadWriteMany"
    envsubst < /root/10_nfs.yml | oc create -f -
done
exportfs -r
