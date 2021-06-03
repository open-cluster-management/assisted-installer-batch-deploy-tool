#!/bin/bash
set -o nounset

# Starts monitoring the progress of the creation and provisioning of SNO clusters
# installed with Assisted Installer.
# Usage:
#   ./monitor-deployment.sh KUBECONFIG_FILE [INTERVAL_SECONDS]
# The output of the stats will both be displayed in terminal output and saved to
# csv file managedsnocluster.csv.
# You can optionally supply the number of seconds between each intervals of collecting
# stats. The default value is 10 seconds.

# The following stats are reported:
#   - initialized: the number of clusterdeployment that have been created.
#   - iso_gen: the number of infraenvs that have a discovery iso url generated.
#   - iso_bmh: the number of baremetalhosts that have been injected with a discovery iso url.
#   - booted: baremetal hosts that are provisioned; currently running discovery iso and downloading rootfs.
#   - discovered: rootfs has been downloaded and discovery results sent back to the hub; agent created.
#   - provisioning: agentclusterinstall in provisioning state
#   - installfailed: agentclusterinstall in failed state
#   - completed: clusterdeployment in completed state
#   - managed: managedcluster avaialble
#   - agents_available: managedclusteraddon avaialble

if [ -z "$1" ]; then
  echo 'usage: ./monitor-deployment.sh KUBECONFIG_FILE [INTERVAL_SECONDS]'
  exit 1
fi
kubeconfig_path=$1
sleep_seconds=${2:-'10'}
export KUBECONFIG=$kubeconfig_path

file=managedsnocluster.csv

if [ ! -f ${file} ]; then
  echo "\
date,\
initialized,\
iso_gen,\
iso_bmh,\
booted,\
discovered,\
provisioning,\
installfailed,\
completed,\
managed,\
agents_available\
" > ${file}
fi

while true; do
  D=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  agentclusterinstall_readyforinstallation=$(oc get agentclusterinstall -A --no-headers -o custom-columns=READY:'.status.conditions[?(@.type=="Completed")].reason',name:'.metadata.name')
  clusterdeployments_installed=$(oc get clusterdeployment -A --no-headers -o custom-columns=installed:'.spec.installed',name:'.spec.clusterName')

  initialized=$(echo "$clusterdeployments_installed" | grep -c sno | tr -d " ")

  iso_gen=$(oc get infraenv -A -o custom-columns=NAME:.metadata.name,ISO:.status.isoDownloadURL --no-headers | grep assisted-install  | wc -l)
  bmh_base64=$(oc get bmh -A --no-headers -o custom-columns=NAME:.metadata.name,IMAGE:.spec.image,PROVISIONED:.status.provisioning.state | base64 -w 0)
  iso_bmh=$(echo $bmh_base64 | base64 -d | grep assisted-install | wc -l )
  booted=$(echo $bmh_base64 | base64 -d | grep -c provisioned | tr -d " ")
  discovered=$(oc get agent -A --no-headers | wc -l | tr -d " ")

  provisioning=$(echo "$agentclusterinstall_readyforinstallation" | grep -c InstallationInProgress | tr -d " ")
  installfailed=$(echo "$agentclusterinstall_readyforinstallation" | grep -c InstallationFailed | tr -d " ")
  completed=$(echo "$clusterdeployments_installed" | grep -i -c true | tr -d " ")

  managed=$(oc get managedcluster -A --no-headers -o custom-columns=JOINED:'.status.conditions[?(@.type=="ManagedClusterJoined")].status',AVAILABLE:'.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status' | grep -v none | grep -i true | grep -v Unknown | wc -l | tr -d " ")
  agents_available=$(oc get managedclusteraddon -A --no-headers -o custom-columns=AVAILABLE:'.status.conditions[?(@.type=="Available")].status',CLUSTER:'.status.addOnConfiguration.crName' | grep -i true | grep -c sno)

  echo "$D"
  echo "$D initialized: $initialized"
  echo "$D iso_gen: $iso_gen"
  echo "$D iso_bmh: $iso_bmh"
  echo "$D booted: $booted"
  echo "$D discovered: $discovered"
  echo "$D provisioning: $provisioning"
  echo "$D installfailed: $installfailed"
  echo "$D completed: $completed"
  echo "$D managed: $managed"
  echo "$D agents_available: $agents_available"

  echo "\
$D,\
$initialized,\
$iso_gen,\
$iso_bmh,\
$booted,\
$discovered,\
$provisioning,\
$installfailed,\
$completed,\
$managed,\
$agents_available\
" >> ${file}

  sleep "$sleep_seconds"
done
