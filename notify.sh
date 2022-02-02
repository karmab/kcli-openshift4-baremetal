#!/usr/bin/env bash

set -euo pipefail

export KUBECONFIG=/root/ocp/auth/kubeconfig
echo "Report from vm: $(hostname) ip: $(hostname -I | cut -d' ' -f1)"
echo "Cluster info:"
oc get clusterversion
echo "Nodes info:"
oc get nodes
echo "Update time:"
uptime | awk '{ print $3 }' | sed 's/,//'
{% if ztp_spokes is defined %}
{% for spoke in ztp_spokes %}
export SPOKE={{ spoke.name }}
oc get agent -A
oc get agentclusterinstall -n $SPOKE $SPOKE -o jsonpath={'.status.conditions[-1].message'}
oc get agentclusterinstall -n $SPOKE $SPOKE -o jsonpath={'.status.debugInfo.state'}
oc get agentclusterinstall -n $SPOKE $SPOKE -o jsonpath={'.status.debugInfo.stateInfo'}
{% endfor%}
{% endif %}
