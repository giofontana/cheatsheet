
# Add insecure registry conf for Podman

```bash
export REGISTRY_NAME=quayacm
sudo vi /etc/containers/registries.conf.d/$REGISTRY_NAME.conf
[[registry]]
location = "quay-local-quay-openshift-operators.apps.rhacm.sandbox1416.opentlc.com"
insecure = true
```
