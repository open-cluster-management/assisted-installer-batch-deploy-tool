#!/usr/bin/env bash

# Gets all provisioned cluster kubeconfigs
# Usage:
#   ./getkubeconfigs.sh start_index end_index
# cluster-name: the cluster of the kubeconfig you wish to download.
# cluster-directory: the location of the downloaded kubeconfig will be
#   put here with `/kubeconfig` appended to the path.

start_index=$1
end_index=$2
echo "$(date -u +%Y%m%d-%H%M%S) - Getting kubeconfigs"
echo "$(date -u +%Y%m%d-%H%M%S) - Clusters Start: ${start_index}"
echo "$(date -u +%Y%m%d-%H%M%S) - Clusters End: ${end_index}"

for idx in `seq -f "%05g" ${start_index} ${end_index}`; do
  oc get secret -n sno${idx} | grep kubeconfig | awk '{print $1}' | xargs -I % oc get secret -n sno${idx} % -o json | jq -r '.data.kubeconfig' | base64 -d > clusters/sno${idx}/kubeconfig
done
echo "$(date -u +%Y%m%d-%H%M%S) - Finished getting kubeconfigs"
