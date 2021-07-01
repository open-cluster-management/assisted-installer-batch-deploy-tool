for file in `find . | grep kubeconfig`;do if [ `cat $file | wc -l` == 0 ]; then rm -rf $file; fi; done
