while true; do 
	date -u +"%Y-%m-%dT%H:%M:%SZ"
	oc get managedcluster | grep False
done
