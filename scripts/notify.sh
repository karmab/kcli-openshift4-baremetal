#!/usr/bin/env bash

set -euo pipefail

export KUBECONFIG=/root/kubeconfig.{{ cluster }}
echo "Report from vm: $(hostname) ip: $(hostname -I | cut -d' ' -f1)"
echo "Update time: $(uptime | awk '{ print $3 }' | sed 's/,//')"
echo "Cluster info:"
oc get clusterversion
echo "Nodes info:"
oc get nodes
{% if ztp_spokes is defined %}
echo -e "\nSpokes:\n"
{% for spoke in ztp_spokes %}
export SPOKE={{ spoke.name }}
echo "Spoke $SPOKE"
echo "Agents:"
oc get agent -A
echo "Cluster State:"
oc get agentclusterinstall -n $SPOKE $SPOKE -o jsonpath={'.status.debugInfo.state'}
echo "Cluster Info:"
oc get agentclusterinstall -n $SPOKE $SPOKE -o jsonpath={'.status.debugInfo.stateInfo'}
{% endfor%}
{% endif %}
