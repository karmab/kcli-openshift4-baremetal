#!/usr/bin/env bash

set -euo pipefail

cd /root
export PATH=/root/bin:$PATH
export HOME=/root
export PYTHONUNBUFFERED=true
export KUBECONFIG=/root/ocp/auth/kubeconfig

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
{% set hosts = ctlplanes + workers + virtual_ctlplanes_nodes + virtual_workers_nodes %}

{% for host in hosts %}
{% set num = loop.index0|string %}
{% set role = 'ctlplane' if num|int < (ctlplanes + virtual_ctlplanes_nodes)|length else 'worker' %}
{% set url = host["redfish_address"]|default("http://127.0.0.1:9000/redfish/v1/Systems/kcli/%s-%s-%s" % (cluster, role, num)) %}
{% set user = host['bmc_user']|default(bmc_user) %}
{% set password = host['bmc_password']|default(bmc_password) %}
kcli stop baremetal-host -P url={{ url }} -P user={{ user }} -P password={{ password }}
{% set reset = host['bmc_reset']|default(bmc_reset) %}
{% if reset %}
kcli reset baremetal-host -P url={{ url }} -P user={{ user }} -P password={{ password }}
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

mkdir -p ocp/openshift
cp install-config.yaml ocp 
cp agent-config.yaml ocp

if [ -f manifests/*y*ml ] ; then
cp manifests/*y*ml >/dev/null 2>&1 ocp/openshift
openshift-install agent create cluster-manifests --dir ocp
fi

openshift-install agent create image --dir ocp --log-level debug

mv -f ocp/agent.x86_64.iso /var/www/html/{{ cluster }}.iso
restorecon -Frv /var/www/html
chown apache.apache /var/www/html/{{ cluster }}.iso

PRIMARY_NIC=$(ls -1 /sys/class/net | grep -v podman | head -1)
IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d "/" -f 1 | head -1)
echo $IP | grep -q ':' && IP=[$IP]
{% for host in hosts %}
{% set num = loop.index0|string %}
{% set role = 'ctlplane' if num|int < (ctlplanes + virtual_ctlplanes_nodes)|length else 'worker' %}
{% set url = host["redfish_address"]|default("http://127.0.0.1:9000/redfish/v1/Systems/kcli/%s-%s-%s" % (cluster, role, num)) %}
{% set user = host['bmc_user']|default(bmc_user) %}
{% set password = host['bmc_password']|default(bmc_password) %}
kcli start baremetal-host -P url={{ url }} -P user={{ user }} -P password={{ password }} -P iso_url=http://$IP/{{ cluster }}.iso
{% endfor %}

openshift-install wait-for install-complete --dir ocp --log-level debug

{% if hosts|length == 1 %}
# SNO_IP=$(aicli list host | grep '|' | tail -1 | cut -d'|' -f8 | xargs)
#sed -i /"{{ api_ip }} api.{{ cluster }}.{{ domain }}"/d /etc/hosts
# echo $SNO_IP api.{{ cluster }}.{{ domain }} >> /etc/hosts
echo DO SNO STUFF
{% endif %}

{% if virtual_ctlplanes %}
for node in $(oc get nodes --selector='node-role.kubernetes.io/master' -o name) ; do
  oc label $node node-role.kubernetes.io/virtual=""
done
{% endif %}
