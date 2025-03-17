
# Procedure to set RH ACM observability to work with ODF Ceph RGW

## Insecure

Define the thanos.yaml definition in the thanos-object-storage secret to insecure and port 80. View the following example:

```
thanos.yaml: |
   type: s3
   config:
     bucket: "thanos"
     endpoint: "rook-ceph-rgw-ocs-storagecluster-cephobjectstore.openshift-storage.svc:80"
     insecure: true
     access_key: "xxxxxxx"
     secret_key: "yyyyyyyy"
```         

## Secure

Create secret to store ceph rgw certs on open-cluster-management-observability namespace

```
oc get secrets/ocs-storagecluster-cos-ceph-rgw-tls-cert -n openshift-storage -o jsonpath='{.data..tls\.crt}' | base64 -d > ceph-rgw.crt
oc create secret generic ceph-rgw-tls --from-file=ca.crt=ceph-rgw.crt -n open-cluster-management-observability
```

Add the TLS secret details to the metricObjectStorage section by using the following command:

```
oc edit mco observability -o yaml
```

Your file might resemble the following YAML:

```
metricObjectStorage:
  key: thanos.yaml
  name: thanos-object-storage
  tlsSecretName: ceph-rgw-tls
  tlsSecretMountPath: /etc/ceph/certs
```

Update the thanos.yaml definition in the thanos-object-storage secret by adding the http_config.tls_config section with the certificate details. View the following example:

```
thanos.yaml: |
   type: s3
   config:
     bucket: "thanos"
     endpoint: "rook-ceph-rgw-ocs-storagecluster-cephobjectstore.openshift-storage.svc:443"
     insecure: false
     access_key: "xxxxxxx"
     secret_key: "yyyyyyyy"
     http_config:
       tls_config:
         ca_file: /etc/ceph/certs/ca.crt
         insecure_skip_verify: false
```         

References:
* https://docs.redhat.com/en/documentation/red_hat_openshift_data_foundation/4.18/html/managing_hybrid_and_multicloud_resources/using-tls-certificates-for-applications-accessing-rgw_rhodf#using-tls-certificates-for-applications-accessing-rgw_rhodf
* https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.12/html/observability/observing-environments-intro#customizing-certificates-object-store