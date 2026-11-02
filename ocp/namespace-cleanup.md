# Tips when namespace is stuck on Terminating

Delete clusterroles before reinstall :

```
oc get clusterroles | grep open-cluster-management | awk {'print $1'} | while read i; do oc delete clusterroles     $i; 
```

Check the stuck resources from the below command:

```
oc api-resources --verbs=list --namespaced -o name | xargs -n 1 oc get --show-kind --ignore-not-found -n open-cluster-management
oc project open-cluster-management
oc patch <Resource Name>  -p '{"metadata":{"finalizers":[]}}' --type=merge
```

Delete namespace, if you got stuck with message: `Discovery failed for some groups, 1 failing: unable to retrieve the complete list of server APIs: metrics.k8s.io/v1beta1: the server is currently unable to handle the request` :

```
oc get validatingwebhookconfigurations.admissionregistration.k8s.io -n open-cluster-management | grep multiclusterhub
oc delete $validationwebhook
oc get APIServices | grep clusterview.open-cluster-management.io
oc delete APIServices v1.clusterview.open-cluster-management.io
```