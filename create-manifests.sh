#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

# Create manifests of SNO clusters that will be installed via Assisted Installer.
# Please provide the hardware information of VM Hosts in inventory-manifest.csv,
# as well as which addons you would like to enable or disable in acm-agent-addon.json.
# Usage:
#   ./create-manifests.sh INVENTORY_FILE PULL_SECRET_PATH SSH_KEY_PATH'

if [ -z "$3" ]; then
  echo 'usage: ./create-manifests.sh INVENTORY_FILE PULL_SECRET_PATH SSH_KEY_PATH'
  exit 1
fi
inventory_file=$1
pull_secret_path=$2
ssh_key_path=$3

generate_manifest_yamls() {
  local row=$1
  IFS="," read cluster_name base_domain mac_addr ip_addr public_ip_network_prefix gateway machine_network_cidr dns_resolver bmc_addr bmc_username_base64 bmc_password_base64 <<<$row

  local yaml_dir=clusters/"$cluster_name"/manifest
  mkdir -p "$yaml_dir"

  echo "====== Generating manifests for $cluster_name  ======"
  sed -e s/\{\{CLUSTER_NAME\}\}/"$cluster_name"/g \
    -e "s~{{PUBLIC_KEY}}~'$public_key'~g" \
    -e s~\{\{MACHINE_NETWORK_DIR\}\}~"$machine_network_cidr"~g \
    -e s/\{\{BASE_DOMAIN\}\}/"$base_domain"/g \
    templates/clusterdeployment.yaml.template >"$yaml_dir"/500-clusterdeployment.yaml

  sed -e s/\{\{CLUSTER_NAME\}\}/"$cluster_name"/g \
    -e s/\{\{BMC_USERNAME_BASE64\}\}/"$bmc_username_base64"/g \
    -e s/\{\{BMC_PASSWORD_BASE64\}\}/"$bmc_password_base64"/g \
    templates/bmh-secret.yaml.template >"$yaml_dir"/200-bmh-secret.yaml

  sed -e s/\{\{CLUSTER_NAME\}\}/"$cluster_name"/g \
    -e "s~{{PUBLIC_KEY}}~'$public_key'~g" \
    templates/infraenv.yaml.template >"$yaml_dir"/800-infraenv.yaml

  sed -e s/\{\{CLUSTER_NAME\}\}/"$cluster_name"/g \
    templates/managedcluster.yaml.template >"$yaml_dir"/700-managedcluster.yaml

  sed -e s/\{\{CLUSTER_NAME\}\}/"$cluster_name"/g \
    templates/namespace.yaml.template >"$yaml_dir"/100-namespace.yaml

  sed -e s/\{\{CLUSTER_NAME\}\}/"$cluster_name"/g \
    -e "s~{{DNS_RESOLVER}}~'$dns_resolver'~g" \
    -e "s~{{IP_ADDR}}~'$ip_addr'~g" \
    -e "s~{{MAC_ADDR}}~'$mac_addr'~g" \
    -e "s~{{GATEWAY}}~'$gateway'~g" \
    -e s/\{\{PUBLIC_IP_NETWORK_PREFIX\}\}/"$public_ip_network_prefix"/g \
    templates/nmstate.yaml.template >"$yaml_dir"/300-nmstate.yaml

  sed -e s/\{\{CLUSTER_NAME\}\}/"$cluster_name"/g \
    -e s/\{\{PULL_SECRET_BASE64\}\}/"$pull_secret_base64"/g \
    templates/pull-secret.yaml.template >"$yaml_dir"/400-pull-secret.yaml

  sed -e s/\{\{CLUSTER_NAME\}\}/"$cluster_name"/g \
    -e s/\{\{PRIVATE_KEY_BASE64\}\}/"$private_key_base64"/g \
    templates/private-key.yaml.template >"$yaml_dir"/400-private-key.yaml

  sed -e s/\{\{CLUSTER_NAME\}\}/"$cluster_name"/g \
    templates/klusterletaddonconfig.yaml.template >"$yaml_dir"/600-klusterletaddonconfig.yaml
  # Append addon enable info
  for k in $(jq '.[]' acm-agent-addon.json); do
    addon_name=$(jq -r ".[$k].addonName" acm-agent-addon.json)
    enabled=$(jq -r ".[$k].enabled" acm-agent-addon.json)

    # If user wants to disable the observability addon, just simply delete the line
    # because it's enabled by default
    if [[ $addon_name == "observability" && ! $enabled ]]; then
      sed -e "s/\{\{OBSERVABILITY_LABEL\}\}/observability=disabled/g" \
        templates/managedcluster.yaml.template \
        >$yaml_dir/700-managedcluster.yaml
    fi

    # Need to write to yaml; cannot use yq because bastion machine doesn't have yq
    echo -e "\n  $addon_name:\n    enabled: $enabled" >>"$yaml_dir"/600-klusterletaddonconfig.yaml
  done
  # Delete the {{OBSERVABILITY_LABEL}} in the yaml
  sed -e "/\{\{OBSERVABILITY_LABEL\}\}/d" templates/managedcluster.yaml.template \
    >$yaml_dir/700-managedcluster.yaml

  sed -e s/\{\{CLUSTER_NAME\}\}/"$cluster_name"/g \
    -e "s~{{BMC_ADDR}}~'$bmc_addr'~g" \
    -e "s~{{MAC_ADDR}}~'$mac_addr'~g" \
    templates/baremetalhost.yaml.template >"$yaml_dir"/900-baremetalhost.yaml
}

pull_secret_base64=$(base64 -w 0 "$pull_secret_path")
public_key=$(cat "${ssh_key_path}.pub")
private_key_base64=$(base64 -w 0 "${ssh_key_path}")

sed 1d $inventory_file | while IFS="," read row; do
  generate_manifest_yamls "$row"
done
