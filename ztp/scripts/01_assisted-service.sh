#!/usr/bin/env bash

export PYTHONUNBUFFERED=true
export PATH=/root/bin:$PATH
dnf -y install httpd
systemctl enable --now httpd

{% if acm %}
APP=advanced-cluster-management
SOURCE_ARGS="-P acm_mce_catalog=$(kcli info app openshift multicluster-engine | grep ^source: | cut -d: -f2 | xargs)"
{% else %}
APP=multicluster-engine
SOURCE_ARGS=""
{% endif %}

{% if disconnected_url != None %}
DISCONNECTED_ARGS="-P disconnected_url={{ disconnected_url }}"
{% elif disconnected %}
{% if dns %}
REGISTRY_NAME=registry.{{ cluster }}.{{ domain }}
{% else %}
BAREMETAL_IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d'/' -f1)
REGISTRY_NAME=$(echo $BAREMETAL_IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io
{% endif %}
LOCAL_PORT={{ 8443 if disconnected_quay else 5000 }}
DISCONNECTED_ARGS="-P disconnected_url=${REGISTRY_NAME}:$LOCAL_PORT"
{% else %}
DISCONNECTED_ARGS=""
{% endif %}

EXTRA_ARGS="{{ ' -P assisted=true -P pull_secret=/root/openshift_pull.json -P assisted_disable_validations=true' if disable_validations|default(False) else '' }}{{  ' -P assisted_converged_flow=true' if converged_flow|default(False) else '' }}"

kcli create app openshift $APP $DISCONNECTED_ARGS $SOURCE_ARGS $EXTRA_ARGS
sleep 120
