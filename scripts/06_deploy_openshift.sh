#!/usr/bin/env bash

set -euo pipefail

cd /root
export PATH=/root/bin:$PATH
export HOME=/root
export PYTHONUNBUFFERED=true
export KUBECONFIG=/root/kubeconfig.{{ cluster }}

{% set virtual_ctlplanes_nodes = [] %}
{% set virtual_workers_nodes = [] %}
{% if virtual_ctlplanes %}
{% for num in range(0, virtual_ctlplanes_number) %}
{% do virtual_ctlplanes_nodes.append({}) %}
{% endfor %}
{% endif %}
{% if virtual_workers and virtual_workers_deploy %}
{% for num in range(0, virtual_workers_number) %}
{% do virtual_workers_nodes.append({}) %}
{% endfor %}
{% endif %}
{% set nodes = ctlplanes + workers + virtual_ctlplanes_nodes + virtual_workers_nodes %}
{% set sno = (ctlplanes + workers + virtual_ctlplanes_nodes + virtual_workers_nodes)|length == 1 %}

{% for node in nodes %}
{% set num = loop.index0|string %}
{% set role = 'ctlplane' if num|int < (ctlplanes + virtual_ctlplanes_nodes)|length else 'worker' %}
{% set url = node["redfish_address"]|default("http://127.0.0.1:9000/redfish/v1/Systems/kcli/%s-%s-%s" % (cluster, role, num)) %}
{% set user = node['bmc_user']|default(bmc_user) %}
{% set password = node['bmc_password']|default(bmc_password) %}
kcli stop baremetal-host -u {{ user }} -p {{ password }} {{ url }}
{% set reset = node['bmc_reset']|default(bmc_reset) %}
{% if reset %}
kcli reset baremetal-host -u {{ user }} -p {{ password }} {{ url }}
{% endif %}
{% endfor %}

{% if localhost_fix %}
cp /root/machineconfigs/99-localhost-fix*.yaml /root/manifests
{% endif %}
{% if monitoring_retention != None %}
cp /root/machineconfigs/99-monitoring.yaml /root/manifests
{% endif %}
find manifests -type f -empty -print -delete
grep -q "{{ api_ip }} api.{{ cluster }}.{{ domain }}" /etc/hosts || echo {{ api_ip }} api.{{ cluster }}.{{ domain }} >> /etc/hosts

kcli delete iso --yes {{ cluster }}.iso || true

export AI_URL=127.0.0.1:8090
if [ ! -f /root/pod.yml ] ; then
aicli create onprem
sleep 120
fi

aicli create deployment --force {{ cluster }}  2>&1 | tee -a /root/install.log
aicli download kubeconfig --path /root {{ cluster }}

{% if sno %}
SNO_IP=$(aicli list host | grep '|' | tail -1 | cut -d'|' -f8 | xargs)
sed -i /"{{ api_ip }} api.{{ cluster }}.{{ domain }}"/d /etc/hosts
echo $SNO_IP api.{{ cluster }}.{{ domain }} >> /etc/hosts
{% endif %}

{% if virtual_ctlplanes %}
for node in $(oc get nodes --selector='node-role.kubernetes.io/master' -o name) ; do
  oc label $node node-role.kubernetes.io/virtual=""
done
{% endif %}
