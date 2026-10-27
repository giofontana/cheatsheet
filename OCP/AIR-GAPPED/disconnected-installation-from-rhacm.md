
# Sample of install-config and ACM manifests for disconnected

```yaml
apiVersion: v1
metadata:
  name: ocp1
baseDomain: sandbox1416.opentlc.com
proxy:
  httpProxy: http://10.0.10.14:3128
  httpsProxy: http://10.0.10.14:3128
controlPlane:
  name: master
  hyperthreading: Enabled
  replicas: 3
  platform:
    aws:
      rootVolume:
        iops: 4000
        size: 100
        type: io1
      type: m5.xlarge
      zones:
      - us-east-2a
compute:
  - name: worker
    hyperthreading: Enabled
    replicas: 3
    platform:
      aws:
        rootVolume:
          iops: 2000
          size: 100
          type: io1
        type: m5.xlarge
        zones:
        - us-east-2a
networking:
  networkType: OpenShiftSDN
  clusterNetwork:
    - cidr: 10.128.0.0/14
      hostPrefix: 23
  machineNetwork:
    - cidr: 10.0.0.0/16
  serviceNetwork:
    - 172.30.0.0/16
platform:
  aws:
    region: us-east-2
    subnets:
      - subnet-0c5127264ab0e6b0c
publish: Internal
pullSecret: ''
sshKey: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEx/GI**************
additionalTrustBundle: |-
  -----BEGIN CERTIFICATE-----
  **************
  -----END CERTIFICATE-----
imageContentSources:
  - mirrors:
      - quay-local-quay-openshift-operators.apps.rhacm.sandbox1416.opentlc.com/openshift/openshift/release-images
    source: quay.io/openshift-release-dev/ocp-release
  - mirrors:
      - quay-local-quay-openshift-operators.apps.rhacm.sandbox1416.opentlc.com/openshift/openshift/release
    source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
  - mirrors:
      - quay-local-quay-openshift-operators.apps.rhacm.sandbox1416.opentlc.com/openshift/quay
    source: registry.redhat.io/quay
  - mirrors:
      - quay-local-quay-openshift-operators.apps.rhacm.sandbox1416.opentlc.com/openshift/openshift4
    source: registry.redhat.io/openshift4
  - mirrors:
      - quay-local-quay-openshift-operators.apps.rhacm.sandbox1416.opentlc.com/openshift/odf4
    source: registry.redhat.io/odf4
  - mirrors:
      - quay-local-quay-openshift-operators.apps.rhacm.sandbox1416.opentlc.com/openshift/rhel8
    source: registry.redhat.io/rhel8
  - mirrors:
      - quay-local-quay-openshift-operators.apps.rhacm.sandbox1416.opentlc.com/openshift/rhceph
    source: registry.redhat.io/rhceph
  - mirrors:
      - quay-local-quay-openshift-operators.apps.rhacm.sandbox1416.opentlc.com/openshift/rhel8
    source: registry.redhat.io/rhel8
  - mirrors:
      - quay-local-quay-openshift-operators.apps.rhacm.sandbox1416.opentlc.com/openshift/multicluster-engine
    source: registry.redhat.io/multicluster-engine
  - mirrors:
      - quay-local-quay-openshift-operators.apps.rhacm.sandbox1416.opentlc.com/openshift/rhacm2
    source: registry.redhat.io/rhacm2
```


```yaml
apiVersion: hive.openshift.io/v1
kind: ClusterDeployment
metadata:
  name: ocp1
  namespace: ocp1
  labels:
    cloud: AWS
    region: us-east-2
    vendor: OpenShift
spec:
  baseDomain: sandbox1416.opentlc.com
  clusterName: ocp1
  controlPlaneConfig:
    servingCertificates: {}
  installAttemptsLimit: 1
  installed: false
  platform:
    aws:
      credentialsSecretRef:
        name: ocp1-aws-creds
      region: us-east-2
  provisioning:
    installConfigSecretRef:
      name: ocp1-install-config
    sshPrivateKeySecretRef:
      name: ocp1-ssh-private-key
    imageSetRef:
      name: img4.11.43-x86-64-quayfd
  pullSecretRef:
    name: ocp1-pull-secret
---
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: ocp1
  labels:
    name: ocp1
    cloud: Amazon
    region: us-east-2
    vendor: OpenShift
spec:
  hubAcceptsClient: true
---
apiVersion: hive.openshift.io/v1
kind: ClusterImageSet
metadata:
  name: img4.11.43-x86-64-quayfd
  labels:
    visible: 'true'
spec:
  releaseImage: quayfd.sandbox1416.opentlc.com/openshift/openshift/release-images:4.11.43-x86_64
---
apiVersion: hive.openshift.io/v1
kind: MachinePool
metadata:
  name: ocp1-worker
  namespace: ocp1
spec:
  name: worker
  clusterDeploymentRef:
    name: ocp1
  platform:
    aws:
      rootVolume:
        iops: 2000
        size: 100
        type: io1
      type: m5.xlarge
  replicas: 3
---
apiVersion: v1
kind: Secret
metadata:
  name: ocp1-pull-secret
  namespace: ocp1
stringData:
  .dockerconfigjson:
type: kubernetes.io/dockerconfigjson
---
apiVersion: v1
kind: Secret
metadata:
  name: ocp1-install-config
  namespace: ocp1
type: Opaque
data:
  install-config.yaml: >-
    ************
---
apiVersion: v1
kind: Secret
metadata:
  name: ocp1-ssh-private-key
  namespace: ocp1
stringData:
  ssh-privatekey:
type: Opaque
---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: ocp1-aws-creds
  namespace: ocp1
stringData:
  aws_access_key_id: ************
  aws_secret_access_key:
---
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  name: ocp1
  namespace: ocp1
spec:
  clusterName: ocp1
  clusterNamespace: ocp1
  clusterLabels:
    cloud: Amazon
    vendor: OpenShift
  applicationManager:
    proxyPolicy: OCPGlobalProxy
    enabled: true
  policyController:
    proxyPolicy: OCPGlobalProxy
    enabled: true
  searchCollector:
    proxyPolicy: OCPGlobalProxy
    enabled: true
  certPolicyController:
    proxyPolicy: OCPGlobalProxy
    enabled: true
  iamPolicyController:
    proxyPolicy: OCPGlobalProxy
    enabled: true

```