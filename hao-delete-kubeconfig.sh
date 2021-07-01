for file in `find clusters | grep kubeconfig`; do rm -rf $file; done
