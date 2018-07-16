# Back up and restore ICP components

The most important (and detailed) step in the In this scenario is performing backups of the ICP components.  It is vital to perform this backups in the spirit of this guide.  Improperly taken backups may prove later to be useless.  Useless backups may leave your cluster in a state that requires redeployment.

[Back up and restore etcd](etcd.md)

[Back up and restore Docker Registry](registry.md)

[Back up and restore Cloudant 2.1.0.2 and earlier clusters only](cloudant.md)

[Back up and restore MongoDB 2.1.0.3 and earlier clusters only](mongodb.md)

These components must be backed up in the following order:

* etcd
* Docker Registry
* Cloudant (2.1.0.2 and earlier)
* MongoDB (2.1.0.3 and later)

> When restoring our Master Node we will proceed in the opposite order.
