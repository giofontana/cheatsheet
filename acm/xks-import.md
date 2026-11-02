# To import xks clusters

https://access.redhat.com/solutions/6243011

Add pull secret at open-cluster-management (https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.14/html/install/installing#custom-image-pull-secret):

1. Go to cloud.redhat.com/openshift/install/pull-secret to download the OpenShift Container Platform pull secret file.
2. Click Download pull secret.
3. Run the following command to create your secret:

```
oc create secret generic <secret> -n <namespace> --from-file=.dockerconfigjson=<path-to-pull-secret> --type=kubernetes.io/dockerconfigjson
```

4. Replace secret with the name of the secret that you want to create.
5. Replace namespace with your project namespace, as the secrets are namespace-specific.
6. Replace path-to-pull-secret with the path to your OpenShift Container Platform pull secret that you downloaded.
7. The following example displays the `spec.imagePullSecret` template to use if you want to use a custom pull secret. Replace secret with the name of your pull secret:

```
apiVersion: operator.open-cluster-management.io/v1
kind: MultiClusterHub
metadata:
  name: multiclusterhub
  namespace: <namespace>
spec:
  imagePullSecret: <secret>
```
