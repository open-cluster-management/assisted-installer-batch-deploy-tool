#!/bin/bash
set -o nounset

# Apply manifests of SNO clusters that will be installed via Assisted Installer.
# Please create the manifests first via script create-manifests.sh.
# Usage:
#   ./apply-manifests.sh KUBECONFIG_PATH START_INDEX END_INDEX INVENTORY_FILE [NUM_CONCURRENT_APPLY] [INTERVAL_SECOND]
# Clusters between START_INDEX and END_INDEX will be applied.
# By default, 100 clusters will be applied at the same time, then sleep for 15
# seconds, then apply the next 100 cluster, so on and so forth.

if [ -z "$3" ]; then
  echo 'usage: ./apply-manifests.sh KUBECONFIG_PATH START_INDEX END_INDEX INVENTORY_FILE [NUM_CONCURRENT_APPLY] [INTERVAL_SECOND]'
  exit 1
fi
kubeconfig_path=$1
start_index=$2
end_index=$3
if [ $start_index -gt $end_index ]; then
  echo 'usage: ./apply-manifests.sh KUBECONFIG_PATH START_INDEX END_INDEX INVENTORY_FILE [NUM_CONCURRENT_APPLY] [INTERVAL_SECOND]'
  echo 'Please provide a valid start index and end index.'
  exit 1
fi
inventory_file=$4
num_concurrent_apply=${5:-'100'}
interval_second=${6:-'15'}

export KUBECONFIG=$kubeconfig_path

STOP_LOOP=false
function ctrl_c() {
  STOP_LOOP=true
  echo "Trapped CTRL-C: terminate all child process"
  for pid in ${pids[*]}; do
    kill -9 $pid
  done
}
# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function timestampLog() {
  echo "$(date +"%Y-%m-%d %H:%M:%S"), "$@""
}

function retry {
  local n=0
  local max=5
  local delay=$interval_second

  n=0
  until [ "$n" -ge $max ]; do
    "$@"
    if [ "$?" -eq 0 ]; then
      break
    fi
    ((n++))
    sleep "$delay"
    timestampLog "Command failed. Attempt $n/$max:" | tee -a "$log_file"
  done
}

clusters=()
sed 1d $inventory_file | while IFS=',' read -r cluster_name _; do
  clusters+=("$cluster_name")
done

i=1 # Start with 1 because zsh arrays starting index is 1 instead of 0
for cluster_name in "${clusters[@]}"; do
  if [ $i -lt "$start_index" ] || [ $i -gt "$end_index" ]; then
    ((i++))
    continue
  fi
  cluster_dir="clusters/cluster_name"
  [ "$STOP_LOOP" = "true" ] && break

  log_file="$cluster_dir"/logs
  true >"$log_file"
  # If i is divisible by num_concurrent_apply
  if ! ((i % num_concurrent_apply)); then
    timestampLog "----sleeping for $interval_second seconds" | tee -a "$log_file"
    sleep "$interval_second"
  fi

  timestampLog "($i) Applying manifests for $cluster_dir" | tee -a "$log_file"
  retry oc apply -f "$cluster_dir"/manifest &>>"$log_file" &
  pids[${i}]=$!
  ((i++))
done

for pid in ${pids[*]}; do
  wait $pid
done
