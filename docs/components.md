# Back up and restore ICP components

In this scenario, we will describe how to back up and restore specific ICP components.

[Back up and restore etcd](etcd.md)

[Back up and restore Docker Registry](registry.md)

[Back up and restore ICP metadata (Cloudant)](cloudant.md)

These components must be backed up in the following order:

* etcd
* Docker Registry
* cloudant 


They need to be restored in the reverse order
