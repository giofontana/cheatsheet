
# Use Ceph as the S3 backing Store

1. If on AWS, run this procedure to enable Rados GW: https://red-hat-storage.github.io/ocs-training/training/ocs4/ocs4-enable-rgw.html
2. Create a CephObjectStoreUser:

```yaml
apiVersion: ceph.rook.io/v1
kind: CephObjectStoreUser
metadata:
  name: admin
  namespace: openshift-storage
spec:
  store: ocs-storagecluster-cephobjectstore
  displayName: "Admin User"
```

