#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

# Create manifests of SNO clusters that will be installed via Assisted Installer.
# Please provide the hardware information of VM Hosts in inventory-manifest.csv,
# as well as which addons you would like to enable or disable in acm-agent-addon.json.
# Usage:
#   ./create-siteconfig.sh INVENTORY_FILE PULL_SECRET_PATH SSH_KEY_PATH CLUSTER_IMAGE_SET'

if [ -z "$4" ]; then
  echo 'usage: ./create-siteconfig.sh INVENTORY_FILE PULL_SECRET_PATH SSH_KEY_PATH CLUSTER_IMAGE_SET'
  exit 1
fi
inventory_file=$1
pull_secret_path=$2
ssh_key_path=$3
cluster_image_set=$4

enable_workload_partitioning=${enable_workload_partitioning:-"false"}
use_ipv4=${use_ipv4:-"false"}
enable_static_ip=${enable_static_ip:-"true"}

#network_type="OpenShiftSDN"
network_type="OVNKubernetes"

# ipv6
nmstate_ip_version="ipv6"
nmstate_default_route="::/0"
cluster_network_cidr="fd01::/48"
cluster_network_host_prefix=64
service_network="fd02::/112"
if [[ $use_ipv4 == "true" ]] ; then
  # ipv4
  nmstate_ip_version="ipv4"
  nmstate_default_route="0.0.0.0/0"
  cluster_network_cidr="10.128.0.0/14"
  cluster_network_host_prefix=23
  service_network="172.30.0.0/16"
fi

cpu_set=''
if [[ $enable_workload_partitioning == "true" ]] ; then
  cpu_set='cpuset: "0-1,2-3"'
fi

generate_manifest_yamls() {
  local row=$1
  IFS="," read cluster_name base_domain mac_addr ip_addr public_ip_network_prefix gateway machine_network_cidr dns_resolver bmc_addr bmc_username_base64 bmc_password_base64 <<< "$row"
  
  ipv4_settings="{\"enabled\":false}"
  ipv6_settings="{\"enabled\":false}"
  if [[ $use_ipv4 == "true" ]] ; then
    ipv4_settings="{\"enabled\":true,\"address\":{\"ip\":\"${ip_addr}\",\"prefix-length\":${public_ip_network_prefix}}}"
  else
    ipv6_settings="{\"enabled\":true,\"address\":{\"ip\":\"${ip_addr}\",\"prefix-length\":${public_ip_network_prefix}}}"
  fi

  local yaml_dir=clusters/"$cluster_name"/manifest
  if [ -d "$yaml_dir" ]; then
    rm -rf "$yaml_dir"
  fi
  mkdir -p "$yaml_dir"
  local siteconfigs_dir=clusters/siteconfigs/"$cluster_name"
  mkdir -p "$siteconfigs_dir"

  echo "====== Generating manifests for $cluster_name  ======"

  sed -e s/\{\{CLUSTER_NAME\}\}/"$cluster_name"/g \
    -e s/\{\{BMC_USERNAME_BASE64\}\}/"$bmc_username_base64"/g \
    -e s/\{\{BMC_PASSWORD_BASE64\}\}/"$bmc_password_base64"/g \
    templates/bmh-secret.template.yaml >"$yaml_dir"/200-bmh-secret.yaml

  sed -e s/\{\{CLUSTER_NAME\}\}/"$cluster_name"/g \
    templates/namespace.template.yaml >"$yaml_dir"/100-namespace.yaml

  sed -e s/\{\{CLUSTER_NAME\}\}/"$cluster_name"/g \
    -e s/\{\{PULL_SECRET_BASE64\}\}/"$pull_secret_base64"/g \
    templates/pull-secret.template.yaml >"$yaml_dir"/400-pull-secret.yaml
  
  # Append addon enable info
  observability_replacement=""
  for k in $(jq -r '.[]' -c acm-agent-addon.json); do
    addon_name=$(echo $k | jq -c -j -r '.addonName')
    enabled=$(echo $k | jq -c -j -r '.enabled')

    # If user wants to disable the observability addon, just simply delete the line
    # because it's enabled by default
    if [[ $addon_name == "observability" && $enabled == "false" ]]; then
      observability_replacement="observability: disabled"
    fi

  done


  sed -e s/\{\{CLUSTER_NAME\}\}/"$cluster_name"/g \
    -e s/\{\{BASE_DOMAIN\}\}/"$base_domain"/g \
    -e "s~{{CLUSTER_NETWORK_CIDR}}~'$cluster_network_cidr'~g" \
    -e s/\{\{CLUSTER_NETWORK_HOST_PREFIX\}\}/"$cluster_network_host_prefix"/g \
    -e "s~{{SERVICE_NETWORK}}~'$service_network'~g" \
    -e "s~{{PUBLIC_KEY}}~'$public_key'~g" \
    -e s~\{\{MACHINE_NETWORK_DIR\}\}~"$machine_network_cidr"~g \
    -e s/\{\{CLUSTER_IMAGE_SET\}\}/"$cluster_image_set"/g \
    -e s/\{\{BMC_USERNAME_BASE64\}\}/"$bmc_username_base64"/g \
    -e s/\{\{BMC_PASSWORD_BASE64\}\}/"$bmc_password_base64"/g \
    -e "s~{{DNS_RESOLVER}}~'$dns_resolver'~g" \
    -e "s~{{IP_ADDR}}~'$ip_addr'~g" \
    -e "s~{{IPV4_SETTINGS}}~$ipv4_settings~g" \
    -e "s~{{IPV6_SETTINGS}}~$ipv6_settings~g" \
    -e "s~{{CPU_SET}}~$cpu_set~g" \
    -e "s~{{MAC_ADDR}}~'$mac_addr'~g" \
    -e "s~{{GATEWAY}}~'$gateway'~g" \
    -e "s~{{NMSTATE_IP_VERSION}}~'$nmstate_ip_version'~g" \
    -e "s~{{NMSTATE_DEFAULT_ROUTE}}~'$nmstate_default_route'~g" \
    -e s/\{\{PUBLIC_IP_NETWORK_PREFIX\}\}/"$public_ip_network_prefix"/g \
    -e s/\{\{OBSERVABILITY_LABEL\}\}/"$observability_replacement"/g \
    -e "s~{{BMC_ADDR}}~'$bmc_addr'~g" \
    templates/siteconfig.template.yaml >"$siteconfigs_dir"/siteconfig.yaml

}

pull_secret_base64=$(base64 -b 0 "$pull_secret_path")
public_key=$(cat "${ssh_key_path}.pub")

sed 1d $inventory_file | while IFS="," read row; do
  generate_manifest_yamls "$row"
done
