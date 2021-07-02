{% if baremetal_cidr == None %}
echo baremetal_cidr not set. No network, no party!
exit 1
{% endif %}
{% if version in ['latest', 'stable'] %}
DOTS=$(echo {{ tag }} | grep -o '\.' | wc -l)
[ "$DOTS" -eq "1" ] || (echo tag should be 4.X && exit 1)
{% if version == 'nightly' %}
{% set tag = tag|string %}
TAG={{ tag if tag.split('.')|length > 2 else "latest-" + tag }}
VERSIONCHECK=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/$TAG/release.txt | grep -q 'Pull from')
[ "$VERSIONCHECK" == "" ] || (echo incorrect mix {{ version }} and {{ tag }} && exit 1)
{% endif %}
{% if version in ['latest', 'stable'] %}
VERSIONCHECK=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/{{ version }}-{{ tag }}/release.txt | grep -q 'Pull from')
[ "$VERSIONCHECK" == "" ] || (echo incorrect mix {{ version }} and {{ tag }} && exit 1)
{% endif %}
{% elif version == 'ci' %}
grep -q registry.ci.openshift.org {{ pullsecret }} || (echo Missing token for registry.ci.openshift.org && exit 1)
{% endif %}
{% if config_host == '127.0.0.1' and not lab %}
ip a l {{ baremetal_net }} >/dev/null 2>&1 || (echo Issue with network {{ baremetal_net }} && exit 1)
{% endif %}

{% if acm %}
{% if acm_spoke_masters_number > 1 %}
{% if acm_spoke_api_ip == None %}
echo acm_spoke_api_ip needs to be set if deploying an HA spoke && exit 1
{% endif %}
{% if acm_spoke_ingress_ip == None %}
echo acm_spoke_ingress_ip needs to be set if deploying an HA spoke && exit 1
{% endif %}
{% endif %}
{% endif %}
