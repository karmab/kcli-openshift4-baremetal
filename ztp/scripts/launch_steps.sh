#!/usr/bin/env bash

set -euo pipefail

blue='\033[0;36m'
clear='\033[0m'

export KUBECONFIG=/root/ocp/auth/kubeconfig

echo -e "${blue}************ RUNNING ztp/scripts/01_assisted-service.sh ************${clear}"
/root/ztp/scripts/01_assisted-service.sh

{% if gitops_repo_url == None %}
echo -e "${blue}************ RUNNING ztp/scripts/02_git.sh ************${clear}"
/root/ztp/scripts/02_git.sh
{% endif %}

{% if spoke_deploy and (spokes|length > 0 or gitops_repo_url != None) %}
echo -e "${blue}************ RUNNING ztp/scripts/03_spokes_deploy.sh ************${clear}"
/root/ztp/scripts/03_spokes_deploy.sh

echo -e "${blue}************ RUNNING ztp/scripts/04_spokes_wait.sh ************${clear}"
/root/ztp/scripts/04_spokes_wait.sh

if [ -f /root/ztp/scripts/snoplus.txt ] ; then
  echo -e "${blue}************ RUNNING ztp/scripts/05_snoplus.sh ************${clear}"
  /root/ztp/scripts/05_snoplus.sh
fi

if [ -d /root/ztp/scripts/site-policies ] ; then
  echo -e "${blue}************ RUNNING ztp/scripts/06_compliance.sh ************${clear}"
  /root/ztp/scripts/06_compliance.sh
fi

{% endif %}
