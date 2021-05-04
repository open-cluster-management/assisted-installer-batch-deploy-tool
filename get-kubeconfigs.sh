#!/usr/bin/env bash

# Gets all provisioned cluster kubeconfigs
# Usage:
#   ./getkubeconfigs.sh kubeconfig_file inventory_file [start_index] [end_index]

if [ -z "$2" ]; then
  echo 'usage: /getkubeconfigs.sh kubeconfig_file inventory_file [start_index] [end_index]'
  exit 1
fi
kubeconfig_file=$1
inventory_file=$2
start_index=$3
end_index=$4
# Iterate through all clusters in the file if start and end indexes are not provided or not valid.
if [ -z "$4" ] || [ $start_index -gt $end_index ]; then
  if [ $start_index -gt $end_index ]; then
    echo 'Provided start index is greater than end index. Will be getting kubeconfigs for all clusters in inventory file'
  fi
  echo "$(date -u +%Y%m%d-%H%M%S) - Getting kubeconfigs for all clusters in inventory file"
  start_index='1'
  end_index=$(grep -c sno "$inventory_file")
fi

echo "$(date -u +%Y%m%d-%H%M%S) - Getting kubeconfigs"
echo "$(date -u +%Y%m%d-%H%M%S) - Clusters Start: ${start_index}"
echo "$(date -u +%Y%m%d-%H%M%S) - Clusters End: ${end_index}"

clusters=()
while IFS=',' read cluster_name _; do
  clusters=("${clusters[@]}" "$cluster_name")
done <"$inventory_file"

export KUBECONFIG=$kubeconfig_file
i=1 # Start with 1 because zsh arrays starting index is 1 instead of 0
for cluster_name in "${clusters[@]}"; do
  if [ $cluster_name == "cluster_name" ]; then
    continue
  fi
  if [ $i -lt "$start_index" ] || [ $i -gt "$end_index" ]; then
    ((i++))
    continue
  fi
  cluster_kubeconfig=$(oc get secret $cluster_name-admin-kubeconfig -n $cluster_name -o json)
  if [ "$?" -ne 0 ] ; then
    echo "Getting kubeconfig failed"
  else
    echo "Getting kubeconfig succeeded"
    cat "$cluster_kubeconfig" | jq -r '.data.kubeconfig' | base64 -d > clusters/$cluster_name/kubeconfig
  fi

  ((i++))
done
echo "$(date -u +%Y%m%d-%H%M%S) - Finished getting kubeconfigs"
