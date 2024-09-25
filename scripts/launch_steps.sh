#!/usr/bin/env bash

set -euo pipefail

blue='\033[0;36m'
clear='\033[0m'

echo -e "${blue}************ RUNNING HUB steps ************${clear}"
{% if http_proxy != None %}
echo -e "${blue}************ RUNNING .proxy.sh ************${clear}"
/root/scripts/proxy.sh
source /etc/profile.d/proxy.sh
{% endif %}

{% if virtual_hub %}
echo -e "${blue}************ RUNNING 00_virtual.sh ************${clear}"
/root/scripts/00_virtual.sh || exit 1
{% endif %}

echo -e "${blue}************ RUNNING 01_patch_config.sh ************${clear}"
/root/scripts/01_patch_config.sh

echo -e "${blue}************ RUNNING 02_packages.sh ************${clear}"
/root/scripts/02_packages.sh

if [ -f /root/ocp/auth/kubeconfig ] ; then
echo -e "${blue}************ RUNNING ZTP steps ************${clear}"
/root/ztp/scripts/launch_steps.sh
exit 0
fi

{% if dns %}
echo -e "${blue}************ RUNNING 03_dns.sh ************${clear}"
/root/scripts/03_dns.sh
{% endif %}


{% if disconnected %}
{% if disconnected_url == None %}
echo -e "${blue}************ RUNNING 04_disconnected_{{ 'quay.sh' if disconnected_quay else 'registry.sh' }} ************${clear}"
/root/scripts/04_disconnected_{{ 'quay.sh' if disconnected_quay else 'registry.sh' }} || exit 1
{% endif %}
echo -e "${blue}************ RUNNING 04_disconnected_mirror.sh ************${clear}"
/root/scripts/04_disconnected_mirror.sh || exit 1
{% if (disconnected_operators or disconnected_certified_operators or disconnected_community_operators or disconnected_marketplace_operators or disconnected_extra_catalogs) and not disconnected_operators_deploy_after_openshift %}
echo -e "${blue}************ RUNNING 04_disconnected_olm.sh ************${clear}"
/root/scripts/04_disconnected_olm.sh
{% if disconnected_url == None and disconnected_quay %}
rm -rf /root/manifests-redhat-operator-index-*
/root/scripts/04_disconnected_olm.sh
{% endif %}
{% endif %}
{% endif %}

{% if nbde %}
echo -e "${blue}************ RUNNING 05_nbde.sh ************${clear}"
/root/scripts/05_nbde.sh
{% endif %}

{% if ntp %}
echo -e "${blue}************ RUNNING 06_ntp.sh ************${clear}"
/root/scripts/06_ntp.sh
{% endif %}

{% if deploy_hub %}
echo -e "${blue}************ RUNNING 07_deploy_hub.sh ************${clear}"
export KUBECONFIG=/root/ocp/auth/kubeconfig
/root/scripts/07_deploy_hub.sh

{% if nfs %}
echo -e "${blue}************ RUNNING 08_nfs.sh ************${clear}"
/root/scripts/08_nfs.sh
{% endif %}

{% if imageregistry %}
echo -e "${blue}************ RUNNING imageregistry patch ************${clear}"
oc patch configs.imageregistry.operator.openshift.io cluster --type merge -p '{"spec":{"managementState":"Managed","storage":{"pvc":{}}}}'
{% endif %}

{% if disconnected and (disconnected_operators or disconnected_certified_operators or disconnected_community_operators or disconnected_marketplace_operators or disconnected_extra_catalogs) and disconnected_operators_deploy_after_openshift %}
echo -e "${blue}************ RUNNING 04_disconnected_olm.sh ************${clear}"
/root/scripts/04_disconnected_olm.sh
{% endif %}

echo -e "${blue}************ RUNNING 09_post_install.sh ************${clear}"
/root/scripts/09_post_install.sh

{% if apps %}
echo -e "${blue}************ RUNNING 10_apps.sh ************${clear}"
/root/scripts/10_apps.sh
{% endif %}

touch /root/cluster_ready.txt

echo -e "${blue}************ RUNNING ZTP steps ************${clear}"
/root/ztp/scripts/launch_steps.sh

{% endif %}
