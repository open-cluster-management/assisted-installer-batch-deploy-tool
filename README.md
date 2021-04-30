# SNO Cluster Deployment

## Prerequisite
You must have your VM hosts setup according to https://github.com/taragu/acm-ai-sno-tools/tree/main/ai_sno_test.

## Create SNO clusters
First, create an inventory csv file by following the example [`inventory-manifest.csv.example` file](https://github.com/open-cluster-management/assisted-installer-batch-deploy-tool/blob/main/inventory-manifest.csv.example) with the hardware information of your VM hosts.  The first row of the file indicates the columns. Please keep this line and start a new line with the inventories.

Then provide the addons you would like to enable or disabled in all VM hosts in the `acm-agent-addon.json` file.

On the Bastion machine, run script [`create-manifests.sh`](https://github.com/open-cluster-management/assisted-installer-batch-deploy-tool/blob/main/create-manifests.sh) to create the SNO clusters:
```sh
./create-manifests.sh inventory/csv/path pull/secret/path private-key-path
```

If the script is exited without errors, manifests should be created for each inventory. The generated manifests are under `/clusters`. Under `/clusters`, directories will be created for each SNO clusters, with the directory name being the cluster name. Before continuing to the next step, we recommend spot checking the manifests of one of the generated clusters.

Before applying the manifests, you can start the monitoring script that measures the progress of the installation will also be started in the background. Its output will be saved in `managedsnocluster.csv`:
```sh
./monitor-deployment.sh
```

You can now run the script to apply these manifests for all clusters:
```sh
./apply-manifests.sh kubeconfig/path start_index end_index [NUM_CONCURRENT_APPLY] [INTERVAL_SECOND]
```
You can specify two optional parameters to this script: number of concurrent applies (default value is 1000) and the number of seconds (default value is 0) to wait in between each batch of concurrent applies.

## Debug

You can check the logs generated when applying manifests with the log file: `cluster/cluster-name/logs`.

You can also check the progress of the Assisted Installer installation of a particular SNO cluster by checking status:
```sh
curl `oc get infraenv -n cluster-name cluster-name \
  -ojsonpath='{.status.isoDownloadURL}' | \
  sed 's~downloads/image~events~g'`
```

If the SNO cluster is created successfully, you can download the `kubeconfig` of a range of SNO clusters with:
```sh
./getkubeconfigs.sh start_index end_index
```
The `kubeconfig` file will be downloaded to `cluster/cluster-name/kubeconfig`.
