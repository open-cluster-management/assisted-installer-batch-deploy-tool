for file in `find . | grep kubeconfig`; do oc --kubeconfig=$file cluster-info &> /dev/null; echo $file ret=$?; done | grep -v ret=0
