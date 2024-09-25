export HOME=/root
export PYTHONUNBUFFERED=true
{% for spoke in spokes %}
{% set spoke_deploy = spoke.get('deploy', spoke_deploy) %}
{% set spoke_ctlplanes_number = spoke.get('ctlplanes', 1) %}
{% set spoke_workers_number = spoke.get('workers', 0) %}
{% if spoke_deploy and spoke.get('wait', spoke_wait) %}
{% set spoke_wait_time = spoke.get('wait_time', spoke_wait_time) %}
SPOKE={{ spoke.name }}
kcli delete iso -y $SPOKE.iso || true
timeout=0
installed=false
failed=false
while [ "$timeout" -lt "{{ spoke_wait_time }}" ] ; do
  MSG=$(oc get agentclusterinstall -n $SPOKE $SPOKE -o jsonpath={'.status.conditions[-1].message'})
  INFO=$(oc get agentclusterinstall -n $SPOKE $SPOKE -o jsonpath={'.status.debugInfo.stateInfo'})
  echo $INFO | grep -q installed && installed=true && break;
  echo $MSG | grep -q failed && failed=true && break;
  echo "Waiting for spoke cluster $SPOKE to be deployed"
  sleep 60
  timeout=$(($timeout + 60))
done
if [ "$installed" == "true" ] ; then
  echo "Cluster $SPOKE deployed"
  oc get secret -n $SPOKE $SPOKE-admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > /root/kubeconfig.$SPOKE
{% if spoke_ctlplanes_number == 1 %}
{% if ':' in baremetal_cidr %}
  SNO_IP=$(oc get -n $SPOKE $(oc get agent -n $SPOKE -o name) -o jsonpath={'.status.inventory.interfaces[0].ipV6Addresses[0]'} | cut -d/ -f1)
{% else %}
  SNO_IP=$(oc get -n $SPOKE $(oc get agent -n $SPOKE -o name) -o jsonpath={'.status.inventory.interfaces[0].ipV4Addresses[0]'} | cut -d/ -f1)
{% endif %}
  echo ${SNO_IP} api.$SPOKE.{{ domain }} >> /etc/hosts
{% endif %}
elif [ "$failed" == "true" ] ; then
  echo Hit issue during deployment of $SPOKE
  echo message: $MSG
else
  echo Timeout waiting for spoke cluster $SPOKE to be deployed
fi

{% endif %}
{% endfor %}
