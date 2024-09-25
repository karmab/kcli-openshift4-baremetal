kcli create app openshift openshift-gitops-operator
kcli create app openshift topology-aware-lifecycle-manager
sleep 120
cd /root/ztp/scripts/gitops
OCP_RELEASE=$(openshift-install version | head -1 | cut -d' ' -f2)-x86_64
export MINOR=$(echo $OCP_RELEASE | cut -d. -f1,2)

{% if dns and disconnected %}
GIT_SERVER=registry.{{ cluster }}.{{ domain }}
{% else %}
PRIMARY_NIC=$(ls -1 /sys/class/net | grep -v podman | head -1)
IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d'/' -f1)
GIT_SERVER=$(echo $IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io
{% endif %}

GIT_USER={{ gitops_user }}
export REPO_URL={{ gitops_repo_url or 'http://$GIT_SERVER:3000/karmalabs/ztp' }}
export REPO_BRANCH={{ gitops_repo_branch }}
export CLUSTERS_APP_PATH={{ gitops_clusters_app_path }}
export POLICIES_APP_PATH={{ gitops_policies_app_path }}
export HUB={{ cluster }}

{% if disconnected %}
export REGISTRY=$GIT_SERVER:5000
/root/bin/sync_image.sh registry.redhat.io/openshift4/ztp-site-generate-rhel8:v$MINOR
{% else %}
export REGISTRY=registry.redhat.io
{% endif %}

envsubst < openshift-gitops-patch.json.template > openshift-gitops-patch.json
rm openshift-gitops-patch.json.template
oc patch argocd openshift-gitops -n openshift-gitops --type=merge --patch-file openshift-gitops-patch.json
envsubst < clusters-app.yaml.template > clusters-app.yaml
rm clusters-app.yaml.template
if [[ ! "$REPO_URL" =~ "$GIT_SERVER:3000" ]] || [ -d /root/ztp/scripts/site-policies ] ; then
  envsubst < policies-app.yaml.template > policies-app.yaml
  rm policies-app.yaml.template
else
  sed -i /policies-app-project.yaml/d kustomization.yaml
  sed -i /policies-app.yaml/d kustomization.yaml
fi

if [[ "$REPO_URL" =~ "$GIT_SERVER:3000" ]] ; then
  cd /root/git
  mkdir -p site-configs/$HUB
  touch site-configs/$HUB/.gitkeep
  cp /root/ztp/scripts/kustomization.yaml site-configs
  mv /root/ztp/scripts/requirements.yml site-configs/$HUB
  mv /root/ztp/scripts/siteconfig.yml site-configs/$HUB
  if [ -d /root/ztp/scripts/site-policies ] ; then
    if [ "$REGISTRY" != "registry.redhat.io" ] ; then
      sed -i "s/image: registry.redhat.io/image: $REGISTRY/" /root/ztp/scripts/site-policies/*
    fi
    cp -r /root/ztp/scripts/site-policies .
  fi
  git config --global user.name "Jimi Hendrix"
  git add --all
  git commit -m 'Initial spokes'
  git push origin main
fi
