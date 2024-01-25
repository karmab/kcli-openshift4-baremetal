#!/usr/bin/env bash

set -euo pipefail

export NTP_DATA=$((cat << EOF
    pool {{ ntp_server }} iburst 
    driftfile /var/lib/chrony/drift
    makestep 1.0 3
    rtcsync
    logdir /var/log/chrony
EOF
) | base64 -w0)
export ROLE=worker
envsubst < /root/machineconfigs/99-openshift-chrony.sample.yaml > /root/manifests/99-openshift-worker-chrony.yaml
export ROLE=master
envsubst < /root/machineconfigs/99-openshift-chrony.sample.yaml > /root/manifests/99-openshift-ctlplane-chrony.yaml
