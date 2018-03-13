#!/bin/bash

# Login and context for kubectl.  Only valid for 12 hours.
# Edit with new cut-and-paste from ICP Console "configure client" 
#
# NOTE: If you run this script at some point you need to reset the 
# preferred namespace by running 07_set-namespace-kube-system.sh

### Replace this section
# There should be 5 kubectl lines when the configuration commands are pasted in.

kubectl config set-cluster mycluster.icp --server=https://10.0.0.10:8001 --insecure-skip-tls-verify=true
kubectl config set-context mycluster.icp-context --cluster=mycluster.icp
kubectl config set-credentials admin --token=eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdF9oYXNoIjoiZTN1OG0ybG9meG1ncmo4MWs4OWUiLCJyZWFsbU5hbWUiOiJjdXN0b21SZWFsbSIsInVuaXF1ZVNlY3VyaXR5TmFtZSI6ImFkbWluIiwiaXNzIjoiaHR0cHM6Ly9teWNsdXN0ZXIuaWNwOjk0NDMvb2lkYy9lbmRwb2ludC9PUCIsImF1ZCI6IjYzZmRmYmE4MTZlYzNlYWZiYzZlODQ5NjU0MGM1ZDI2IiwiZXhwIjoxNTIwOTA3MTI2LCJpYXQiOjE1MjA5MDcxMjYsInN1YiI6ImFkbWluIiwidGVhbVJvbGVNYXBwaW5ncyI6W119.ELl90UevuxZCjY74WKLKrFZiRRzJC8dHeYD3vipJqwox-crWONfSCdGzUmmlavGBcXS6HnqfDcFjqNCnmp07Rzz0Ns1exhMOjIxGYQ0cUxkmUHxhbxOu-tPoOW2RvsCLm5Boh0DkhSTvoi48G0r15elRHpEQ_L-MmpRl_CRPN_5b6Yif4PWfKW5EDPGbXwdS8BWgnM2Ueb2CnHwY72lmdsrf_YCQGyzHtGmb41IErphs6X4tDdLXRPjX4fCqFKPl9BiPZevEfwqBffk_EEbZ6A55865pFF4WEls0J2MYy3sJ6qHJdPI9PgIwtZ7mMyIXyd8H6JQ6WUveP8of4GeZGg
kubectl config set-context mycluster.icp-context --user=admin --namespace=default
kubectl config use-context mycluster.icp-context

### End of section to replace

# Change context to use the kube-system namespace as preferred
kubectl config set-context mycluster.icp-context --user admin --namespace=kube-system
