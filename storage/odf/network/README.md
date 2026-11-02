
# Instructions to set dedicated network for ODF

1. Create NNCP
2. Create NADs
3. Edit ocs-storage cluster to add the networks:

```
# Under network block of the ocs-storage cluster add the following:

oc edit storagecluster ocs-storagecluster -n openshift-storage

    provider: multus
    selectors:
      cluster: openshift-storage/cluster-net
      public: openshift-storage/public-net
```