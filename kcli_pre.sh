#!/usr/bin/env bash

# CLEANING
kcli delete iso --yes {{ cluster }}.iso || true

# NETWORK CHECK
{% if baremetal_cidr == None %}
echo baremetal_cidr not set. No network, no party!
exit 1
{% else %}
{% set baremetal_prefix = baremetal_cidr.split('/')[1] %}
{% endif %}

{% if dns and installer_ip == None %}
echo Deploying dns requires to set installer_ip
exit 1
{% endif %}

{% set virtual_ctlplanes_nodes = [] %}
{% if virtual_hub %}
{% for num in range(0, ctlplanes) %}
{% do virtual_ctlplanes_nodes.append({}) %}
{% endfor %}
{% endif %}
{% set ctlplanes_hosts = baremetal_ctlplanes + virtual_ctlplanes_nodes %}

{% if ctlplanes_hosts|length > 1 and api_ip == None %}
echo api_ip not set. No network, no party!
exit 1
{% endif %}
{% if ctlplanes_hosts|length > 1 and ingress_ip == None %}
echo ingress_ip not set. No network, no party!
exit 1
{% endif %}
{% if api_ip != None and ingress_ip != None and api_ip == ingress_ip %}
echo api_ip and ingress_ip cant be set to the same value
exit 1
{% endif %}
{% if ctlplanes_hosts|length > 1 %}
if [ -n "$(which ipcalc)" ] ; then
  api_cidr=$(ipcalc {{ api_ip }}/{{ baremetal_prefix }} | grep ^Network: | sed 's/Network://' | xargs)
  if [ "$api_cidr" != "{{ baremetal_cidr }}" ] ; then
   echo {{ api_ip }} doesnt belong to to {{ baremetal_cidr }}
   exit 1
  fi
  ingress_cidr=$(ipcalc {{ ingress_ip }}/{{ baremetal_prefix }} | grep ^Network: | sed 's/Network://' | xargs)
  if [ "$ingress_cidr" != "{{ baremetal_cidr }}" ] ; then
    echo {{ ingress_ip }} doesnt belong to to {{ baremetal_cidr }}
    exit 1
  fi
else
  echo Couldnt check whether api_ip and ingress ip belong to baremetal cidr because ipcalc is not present
fi
{% endif %}

{% if dual_api_ip != None and dual_ingress_ip == None %}
echo dual_api_ip set but not dual_ingress_ip. No network, no party!
exit 1
{% elif dual_ingress_ip != None and dual_api_ip == None %}
echo dual_ingress_ip set but not dual_api_ip. No network, no party!
exit 1
{% elif dual_api_ip != None and dual_api_ip == dual_ingress_ip %}
echo dual_api_ip and dual_ingress_ip cant be set to the same value
exit 1
{% elif dual_api_ip != None and dualstack_cidr == None %}
echo dualstack_cidr needs to be set along with dual_api_ip
exit 1
{% elif dual_api_ip != None and dual_ingress_ip != None %}
if [ -n "$(which ipcalc)" ] ; then
  {% set dual_prefix = dualstack_cidr.split('/')[1] %}
  dual_api_cidr=$(ipcalc {{ dual_api_ip }}/{{ dual_prefix }} | grep ^Network: | sed 's/Network://' | xargs)
  if [ "$dual_api_cidr" != "{{ dualstack_cidr }}" ] ; then
   echo {{ dual_api_ip }} doesnt belong to to {{ dualstack_cidr }}
   exit 1
  fi
  dual_ingress_cidr=$(ipcalc {{ dual_ingress_ip }}/{{ dual_prefix }} | grep ^Network: | sed 's/Network://' | xargs)
  if [ "$dual_ingress_cidr" != "{{ dualstack_cidr }}" ] ; then
    echo {{ dual_ingress_ip }} doesnt belong to to {{ dualstack_cidr }}
    exit 1
  fi
else
  echo Couldnt check whether api_ip and ingress ip belong to baremetal cidr because ipcalc is not present
fi
{% endif %}

{% if dualstack %}
{% if ':' in baremetal_cidr %}
echo baremetal_cidr needs to be ipv4 for dual stack
exit 1
{% endif %}
{% if dualstack_cidr == None %}
echo dualstack_cidr needs to be set for dual stack
exit 1
{% elif ':' not in dualstack_cidr %}
echo dualstack_cidr needs to be ipv6 for dual stack
{% endif %}
{% endif %}

{% if config_host in ['127.0.0.1', 'localhost'] and not create_network %}
{% set baremetal_bridge = baremetal_net if baremetal_net != 'default' else 'virbr0' %}
ip a l {{ baremetal_bridge }} >/dev/null 2>&1 || { echo Issue with network {{ baremetal_net }} ; exit 1; }
{% endif %}

# VERSION CHECK
{% if version is defined %}

{% if version not in ['dev-preview', 'stable', 'nightly', 'ci', 'latest'] %}
  echo "Incorrect version {{ version }}. Should be stable, dev-preview, ci, latest or nightly" && exit 1
{% endif %}

{% if version in ['dev-preview', 'stable'] %}
{% set tag = tag|string %}
{% if tag.split('.')|length > 2 %}
TAG={{ tag }}
{% else %}
TAG={{"latest-" + tag }}
{% endif %}
OCP_REPO={{ 'ocp-dev-preview' if version == 'dev-preview' else 'ocp' }}
export OPENSHIFT_RELEASE_IMAGE=$(curl -Ls https://mirror.openshift.com/pub/openshift-v4/clients/$OCP_REPO/$TAG/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}')
{% elif version == 'latest' %}
export OPENSHIFT_RELEASE_IMAGE=$(curl -Ls https://mirror.openshift.com/pub/openshift-v4/clients/ocp/{{ version }}-{{ tag }}/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}')
{% elif version == 'ci' %}
{% if openshift_image == None %}
{% set openshift_image = tag if '/' in tag|string else "registry.ci.openshift.org/ocp/release:" + tag|string %}
{% endif %}
export OPENSHIFT_RELEASE_IMAGE={{ openshift_image }}
{% elif version == 'nightly' %}
export OPENSHIFT_RELEASE_IMAGE=$(curl -Ls https://amd64.ocp.releases.ci.openshift.org/api/v1/releasestream/{{ tag|string }}.0-0.nightly/latest | jq -r .pullSpec)
{% endif %}
if [ -z "$OPENSHIFT_RELEASE_IMAGE" ] ; then
  echo Couldnt gather release image associated to {{ version }} and {{ tag }}
  exit 1
fi
{% endif %}

# DISCONNECTED_URL CHECK

{% if disconnected and disconnected_url != None %}
{% if disconnected_url.split(':')|length != 2 %}
echo disconnected_url needs to be fqdn:port && exit 1
{% endif %}
{% set registry_port = disconnected_url.split(':')[-1] %}
{% set registry_name = disconnected_url|replace(":" + registry_port, '') %}
{% set registry_name_split = registry_name.split('.') %}
{% if registry_name_split|length == 4 and registry_name_split[0]|int != 0 and registry_name_split[1]|int != 0 and registry_name_split[2]|int != 0 and registry_name_split[3]|int != 0%}
echo disconnected_url cant use an ip. Considering using sslip.io && exit 1
{% endif %}
{% endif %}

# QUAY CHECK

{% if disconnected_quay %}
echo disconnected_user will be forced to 'init'
{% if disconnected_password|length < 8  %}
echo disconnected_password will be forced to super{{ disconnected_password }}
{% endif %}
{% endif %}

# ZTP CHECKS
{% set total_spoke_nodes_number = namespace(value=0) %}
{% for spoke in spokes %}
{% set spoke_name = spoke.get('name') %}
{% set spoke_api_ip = spoke.get('api_ip') %}
{% set spoke_ingress_ip= spoke.get('ingress_ip') %}
{% set spoke_ctlplanes_number = spoke.get('ctlplanes', 1) %}
{% set spoke_workers_number = spoke.get('workers', 0) %}
{% set virtual_nodes_number = spoke.get('virtual_nodes', 0) %}
{% if spoke_name == None %}
echo spoke_name needs to be on each entry of spokes && exit 1
{% elif '_' in spoke_name %}
echo Incorrect spoke_name {{ spoke_name }}: cant contain an underscore && exit 1
{% endif %}
kcli delete iso --yes {{ spoke_name }}.iso || true
{% if spoke_ctlplanes_number <= 0 %}
echo Incorrect spoke ctlplanes {{ spoke_ctlplanes_number }} in {{ spoke_name }}: must be higher than 0 && exit 1
{% endif %}
{% if spoke_workers_number < 0 %}
echo Incorrect spoke workers {{ spoke_workers_number }} in {{ spoke_name }}: cant be negative && exit 1
{% endif %}
{% if spoke_ctlplanes_number > 1 %}
{% if spoke_api_ip == None %}
echo no spoke_api_ip. This is mandatory for an HA spoke && exit 1
{% endif %}
{% if spoke_ingress_ip == None %}
echo no spoke_ingress_ip. This is mandatory for an HA spoke && exit 1
{% endif %}
{% endif %}
{% set total_spoke_nodes_number.value = total_spoke_nodes_number.value + spoke_ctlplanes_number + spoke_workers_number %}
{% endfor %}

{% set total_ctlplanes = baremetal_ctlplanes|length %}
{% if virtual_hub %}
{% set total_ctlplanes = total_ctlplanes + ctlplanes %}
{% endif %}
{% set total_workers = baremetal_workers|length %}
{% if virtual_hub %}
{% set total_workers = total_workers + workers %}
{% endif %}
{% set total_hub_nodes_number = total_ctlplanes + total_workers %}

{% if baremetal_ips|length == 0 %}
echo You need to populate baremetal_ips with at least one ip for rendezvous
exit 1
{% endif %}

{% if baremetal_macs|length < total_hub_nodes_number + total_spoke_nodes_number.value %}
echo You need to populate baremetal_macs with the complete list of mac addresses including your spokes
exit 1
{% endif %}
