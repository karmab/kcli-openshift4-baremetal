cd /root
{% for manifest in 'ztp_spoke_manifests'|find_manifests %}
echo " {{ manifest }} : |" >> ztp_spoke_manifests.yml
sed -e "s/^/  /g" ztp_spoke_manifests/{{ manifest }} >> ztp_spoke_manifests.yml
{% endfor %}
cat ztp_spoke_manifests.yml >> ztp_spoke.yml
