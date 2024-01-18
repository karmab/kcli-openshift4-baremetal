{% if schedulable_ctlplanes %}
echo "Setting ctlplane nodes schedulable"
oc patch scheduler cluster -p '{"spec":{"mastersSchedulable": true}}' --type merge
{% endif %}

if [ "$(grep quay.io /root/version.txt)" == "" ] ; then
  REGISTRY=$(cat /root/version.txt | cut -d/ -f1)
  openssl s_client -showcerts -connect $REGISTRY </dev/null 2>/dev/null| openssl x509 -outform PEM > registry.crt
  oc create configmap registry-cas -n openshift-config --from-file=$(echo $REGISTRY | sed 's/:/\.\./')=registry.crt
  oc patch image.config.openshift.io/cluster --patch '{"spec":{"additionalTrustedCA":{"name":"registry-cas"}}}' --type=merge
  sleep 20
  oc wait mcp/master --for condition=updated
  oc wait mcp/worker --for condition=updated
fi
