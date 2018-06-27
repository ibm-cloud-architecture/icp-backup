# Backup and Restore Certain ICP Nodes

### Validate the Environment Works with just 2 Master Nodes

We are looking for specific procedures / recordings / practices to prove out the destruction of a Master Node, evidence of Master Node fail-over, continued operation of the cluster and finally detailed restoration of the failed Master.  All of this in multi-Master Node clusters.  We would like to see this performed on multiple hypervisors, public clouds and baremetal.

### Validate the ICP Components

This includes showing health of each ICP component and how to recognize health in customer environments.  This is a good opportunity to share a dashboard from Kibana and perhaps Grafana.

## Note on Proxy Nodes

It is recommended to backup and changes made to Proxy Node configuration, however we do not recommend backup and restore of the proxy nodes themselves.  These nodes can be recreated from command line.


## Destroy a Worker Node

We don't backup and restore Worker Nodes, but we do keep track and manage backups of persistent storage for stateful workload.  We should design a test of a Worker Node going "belly-up" and seeing the PV relaease and follow the workload as it finds another Worker Node.  We should attempt to identify (programitically) the death of a Worker Node and trigger the deletion and creation of an identidal node keeping in mind taints, hostgroups and the like.
