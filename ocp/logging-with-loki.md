

```yaml
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: loki-bucket-odf
  namespace: openshift-logging
spec:
  generateBucketName: loki-bucket-odf
  storageClassName: openshift-storage.noobaa.io
---
kind: Secret
apiVersion: v1
metadata:
  name: logging-loki-odf
  namespace: openshift-logging
stringData:
  access_key_id: *************
  access_key_secret: *************
  bucketnames: *************
  endpoint: https://s3.openshift-storage.svc:443
  insecure: true
type: Opaque
```

```bash
oc extract secret/router-certs-default  -n openshift-ingress  --confirm
oc create configmap loki-s3-ca --from-file=service-ca.crt=./tls.crt  -n openshift-logging
```

```yaml
---
apiVersion: loki.grafana.com/v1
kind: LokiStack
metadata:
  name: logging-loki
  namespace: openshift-logging
spec:
  managementState: Managed
  size: 1x.demo
  storage:
    schemas:
      - effectiveDate: '2022-06-01'
        version: v12
    secret:
      name: logging-loki-odf
      type: s3
    tls:
      caName: loki-s3-ca
  storageClassName: ocs-storagecluster-ceph-rbd
  tenants:
    mode: openshift-logging
---
apiVersion: logging.openshift.io/v1
kind: ClusterLogging
metadata:
  name: instance
  namespace: openshift-logging
spec:
  collection:
    type: vector
  logStore:
    lokistack:
      name: logging-loki
    type: lokistack
  managementState: Managed
```