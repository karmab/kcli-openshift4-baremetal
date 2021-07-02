#!/usr/bin/env bash

export KUBECONFIG=/root/ocp/auth/kubeconfig
echo "Report from vm: $(hostname) ip: $(hostname -I | cut -d' ' -f1)"
echo "Cluster info:"
oc get clusterversion
echo "Nodes info:"
oc get nodes
echo "Update time:"
uptime | awk '{ print $3 }' | sed 's/,//'
touch /root/cluster_ready.txt
{% if acm %}
oc describe -n {{ acm_spoke_name }} AgentClusterInstall
{% endif %}
