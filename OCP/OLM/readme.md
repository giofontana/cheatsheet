
# Creating Catalog Source for different version

```bash
oc get catalogsource redhat-operators -n openshift-marketplace -o yaml > redhat-operators.yaml
cp redhat-operators.yaml redhat-operators-418.yaml
vi redhat-operators-418.yaml
# Clean up and change the following line, setting the appropriate version
image: registry.redhat.io/redhat/redhat-operator-index:v4.18
oc create -f redhat-operators-418.yaml
```
