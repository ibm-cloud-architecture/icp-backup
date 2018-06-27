# Create some workloads in ICP
If you are performing these steps in a lab or non-production environment it may be useful to give your etcd some personality before running this test.  WE can do that by loading some data in the form of ConfigMaps.

This script creates and deletes config maps continuously:  `./createConfigMaps.sh`

If you leave this script running for a while, you will see many ConfigMaps created:

```
root@icp-master:~/icp-backup/scripts# kubectl get configmaps | grep snake
snake-0         1         9m
snake-1         1         9m
snake-2         1         9m
snake-3         1         9m
snake-4         1         9m
snake-85        1         9m
snake-86        1         9m
snake-87        1         9m
snake-88        1         9m
snake-89        1         9m
snake-90        1         9m
snake-91        1         9m
snake-92        1         9m
snake-93        1         9m
snake-94        1         9m
snake-95        1         9m
snake-96        1         9m
snake-97        1         9m
snake-98        1         9m
snake-99        1         9m
```
Ok ... **kill it** and move on to the backup.
