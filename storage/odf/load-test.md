
# Test ODF/Ceph Performance

Enable Ceph Tools

```
oc patch storagecluster ocs-storagecluster -n openshift-storage --type json --patch '[{ "op": "replace", "path": "/spec/enableCephTools", "value": true }]'
```

Connect to ceph tools container and run the following:

```
ceph osd pool create testbench 128 128
ceph df
rados bench -p testbench 10 write --no-cleanup
rados bench -p testbench 10 rand
```

