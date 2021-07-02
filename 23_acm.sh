for i in `oc get node -o wide | awk '{print $6}' | grep -v INTERN` ; do ssh core@$i "sudo sed -i 's/mirror-by-digest-only = true/mirror-by-digest-only = false/' /etc/containers/registries.conf && sudo systemctl restart kubelet crio" ; done
sleep 120

oc create -f /root/acm_install.yml
timeout=0
ready=false
while [ "$timeout" -lt "60" ] ; do
  oc get crd | grep -q multiclusterhubs.operator.open-cluster-management.io && ready=true && break;
  echo "Waiting for CRD multiclusterhubs.operator.open-cluster-management.io to be created"
  sleep 5
  timeout=$(($timeout + 5))
done
if [ "$ready" == "false" ] ; then
 echo timeout waiting for CRD multiclusterhubs.operator.open-cluster-management.io
 exit 1
fi
oc create -f /root/acm_cr.yml
sleep 240
oc patch hiveconfig hive --type merge -p '{"spec":{"targetNamespace":"hive","logLevel":"debug","featureGates":{"custom":{"enabled":["AlphaAgentInstallStrategy"]},"featureSet":"Custom"}}}'

export RELEASE_IMAGE=$(cat /root/version.txt)
BAREMETAL_IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d'/' -f1)
REVERSE_NAME=$(dig -x $BAREMETAL_IP +short | sed 's/\.[^\.]*$//')
echo $BAREMETAL_IP | grep -q ':' && SERVER6=$(grep : /etc/resolv.conf | grep -v fe80 | cut -d" " -f2) && REVERSE_NAME=$(dig -6x $BAREMETAL_IP +short @$SERVER6 | sed 's/\.[^\.]*$//')
export LOCAL_REGISTRY=${REVERSE_NAME:-$(hostname -f)}:5000
echo $BAREMETAL_IP | grep -q ':' && BAREMETAL_IP=[$BAREMETAL_IP]
export BAREMETAL_IP
export PULLSECRET=$(cat /root/openshift_pull.json | tr -d [:space:])
export SSH_PUB_KEY=$(cat /root/.ssh/id_rsa.pub)
export SSH_PRIV_KEY=$(cat /root/.ssh/id_rsa |sed "s/^/    /")
export CA_CERT=$(cat /opt/registry/certs/domain.crt | sed "s/^/    /")
export SPOKE_NAME={{ acm_spoke_name }}
export DOMAIN={{ domain }}
export MASTERS_NUMBER={{ acm_spoke_masters_number }}
export WORKERS_NUMBER={{ acm_spoke_workers_number }}

envsubst < /root/acm_assisted-service.sample.yml > /root/acm_assisted-service.yml
envsubst < /root/acm_spoke.sample.yml > /root/acm_spoke.yml
oc create -f /root/acm_assisted-service.yml
oc create -f /root/acm_spoke.yml

oc patch provisioning provisioning-configuration --type merge -p '{"spec":{"watchAllNamespaces": true}}'
sed -i "s@IP@$BAREMETAL_IP@" /root/acm_bmc.yml
export LIBVIRT_DEFAULT_URI=qemu+ssh://{{ 'root' if config_user == 'apache' else config_user }}@{{ config_host if config_host != '127.0.0.1' else baremetal_net|local_ip(true) }}/system
{% for num in range(0, acm_virtual_nodes_number) %}
UUID=$(virsh domuuid {{ cluster }}-acm-node-{{ num }})
sed -i "s@UUID-{{ num }}@$UUID@" /root/acm_bmc.yml
{% endfor %}
oc create -f /root/acm_bmc.yml
