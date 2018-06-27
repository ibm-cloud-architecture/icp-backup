# Backup and Restore the Docker Registry in IBM Cloud Private

This topic covers backup and restore of the Docker Registry in IBM Cloud Private.  If you do not have any images loaded in your registry, it may be useful to load one for testing purposes:

## Add an image in the ICP Docker Registry

First follow the steps at [Configuring authentication for the Docker CLI](https://www.ibm.com/support/knowledgecenter/SSBS6K_2.1.0/manage_images/configuring_docker_cli.html) to configure authentication.  Run the following commands in any machine that has access to the ICP master node and has Docker engine installed.

Next, pull an nginx image:  `docker pull nginx`

You should see the output resembling the following:
```text
patro:icp-backup edu$ docker pull nginx
Using default tag: latest
latest: Pulling from library/nginx
8176e34d5d92: Pull complete
5b19c1bdd74b: Pull complete
4e9f6296fa34: Pull complete
Digest: sha256:4771d09578c7c6a65299e110b3ee1c0a2592f5ea2618d23e4ffe7a4cab1ce5de
Status: Downloaded newer image for nginx:latest
```

Log in to your Docker Registry:  `docker login mycluster.icp:8500`

Provide the admin user and password when prompted.  Tag the image, by running the following command: `docker tag nginx mycluster.icp:8500/default/nginx`

Finally, push the image to the Docker Registry:  `docker push mycluster.icp:8500/default/nginx`

You will see output similar to the following:
```
patro:.docker edu$ docker push mycluster.icp:8500/default/nginx
The push refers to repository [mycluster.icp:8500/default/nginx]
e89b70d28795: Pushed
832a3ae4ac84: Pushed
014cf8bfcb2d: Pushed
latest: digest: sha256:600bff7fb36d7992512f8c07abd50aac08db8f17c94e3c83e47d53435a1a6f7c size: 948
```

Finally, open your browser to:  `https://$MASTER_ID:8443/console/images`

You will see the nginx image listed.

## Back up the ICP Docker Registry

Now that there are images loaded into the ICP Docker Registry, lets perform a backup by running the following command from one of the master nodes:

```
cd /var/lib/registry
tar czvf /tmp/icp_dr.tar.gz .
```

Now move the file `/tmp/icp_dr.tar.gz` to a safe location, outside the master node.

> If this process is automated, which is a good idea, move this file to a location that is included in either your shared storage or in-host backup routine.

## Simulating a Loss to the Docker Registry

In the case that you do not have a actual recovery situation, you can simulate a loss to the Docker Registry.  To do so simply delete the files under /var/lib/registry:  `rm -rf /var/lib/registry/*`

If you open your browser to:  `https://$MASTER_ID:8443/console/images`  You will see an empty response.

### Restore your ICP Docker Registry

To restore your Docker Registry, bring back to file `/tmp/icp_dr.tar.gz` to directory `/tmp` and run the following commands:

```
cd /var/lib/registry
tar xvzf /tmp/icp_dr.tar.gz
```

Next, run the following command to recycle the image manager Pod:

```
kubectl delete pod image-manager-0 -n kube-system
```

If you re-open the URL `https://$MASTER_ID:8443/console/images`, you should see the images restored.
