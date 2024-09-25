export HOME=/root
export PYTHONUNBUFFERED=true
export HUB={{ cluster }}
SPOKE_WAIT_TIME={{ spoke_wait_time }}

for SPOKE in $(cat /root/ztp/scripts/snoplus.txt) ; do
  sed -i "s/^##//" /root/git/site-configs/$HUB/siteconfig.yml
done

cd /root/git
git commit -am 'Snoplus handling'
git push origin main

for SPOKE in $(cat /root/ztp/scripts/snoplus.txt) ; do
  timeout=0
  installed=false
  while [ "$timeout" -lt "$SPOKE_WAIT_TIME" ] ; do
    AGENTS=$(oc get agent -n $SPOKE -o jsonpath="{range .items[?(@.status.progress.currentStage==\"Done\")]}{.metadata.name}{'\n'}{end}" | wc -l)
    [ "$AGENTS" == "2" ] && installed=true && break;
    echo "Waiting for extra worker to be deployed in spoke $SPOKE"
    sleep 60
    timeout=$(($timeout + 60))
  done
  if [ "$installed" == "true" ] ; then
    echo "Extra worker deployed in spoke $SPOKE"
  else
    echo Timeout waiting for extra worker in $SPOKE to be deployed
  fi
done
