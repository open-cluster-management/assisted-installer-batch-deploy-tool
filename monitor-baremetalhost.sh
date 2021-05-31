#!/bin/bash
set -o nounset

if [ -z "$1" ]; then
  echo 'usage: ./monitor-baremetalhost.sh KUBECONFIG_FILE [INTERVAL_SECONDS]'
  exit 1
fi

kubeconfig_path=$1
sleep_seconds=${2:-'10'}
export KUBECONFIG=$kubeconfig_path

file=baremetalhost.csv

states=(
  "unmanaged"
  "registering"
  "match profile"
  "preparing"
  "ready"
  "available"
  "provisioning"
  "provisioned"
  "externally provisioned"
  "deprovisioning"
  "inspecting"
  "deleting"
)

if [ ! -f ${file} ]; then
  echo -n "date,total" > ${file}
  for state in ${states[@]}; do 
    echo -n ",$state" >> ${file}
  done
  echo "" >> ${file}
fi

while true; do
  D=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "$D"; echo -n "$D" >> ${file}
  
  bmh_base64=$(oc get baremetalhost -A --no-headers -o custom-columns=NAME:.metadata.name,STATE:.status.provisioning.state | base64 -w 0)
  
  total=$(echo $bmh_base64 | base64 -d | wc -l)
  echo "$D total: $total"; echo -n ",$total" >> ${file}

  for state in ${states[@]}; do
    count=$(echo $bmh_base64 | base64 -d | grep -c $state)
    echo "$D $state: $count"; echo -n ",$count" >> ${file}
  done
  echo "" >> ${file}

  sleep "$sleep_seconds"
done
