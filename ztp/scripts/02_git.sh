#!/usr/bin/env bash

{% if dns and disconnected %}
GIT_SERVER=registry.{{ cluster }}.{{ domain }}
{% else %}
PRIMARY_NIC=$(ls -1 /sys/class/net | grep -v podman | head -1)
IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d'/' -f1)
GIT_SERVER=$(echo $IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io
{% endif %}
export GIT_SERVER
GIT_USER={{ gitops_user }}
GIT_PASSWORD={{ gitops_password }}

mkdir -p /opt/gitea
chown -R 1000:1000 /opt/gitea
envsubst < /root/ztp/scripts/gitea.service > /etc/systemd/system/gitea.service
systemctl daemon-reload
systemctl enable gitea --now
sleep 20
podman exec --user 1000 gitea /bin/sh -c "gitea admin user create --username $GIT_USER --password $GIT_PASSWORD --email jhendrix@karmalabs.corp --must-change-password=false --admin"

curl -u "$GIT_USER:$GIT_PASSWORD" -H 'Content-Type: application/json' -d '{"username": "karmalabs", "full_name": "karmalabs"}' http://$GIT_SERVER:3000/api/v1/admin/users/$GIT_USER/orgs
curl -u "$GIT_USER:$GIT_PASSWORD" -H 'Content-Type: application/json' -d '{"name":"ztp"}' http://$GIT_SERVER:3000/api/v1/org/karmalabs/repos

git clone http://$GIT_USER:$GIT_PASSWORD@$GIT_SERVER:3000/karmalabs/ztp.git /root/git
