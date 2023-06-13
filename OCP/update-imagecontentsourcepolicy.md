
1. Test the secret for new registry first:

```
podman pull --authfile pull-secret quay-2.sandbox1829.opentlc.com/openshift/openshift/release-images:4.11.38-x86_64
```

2. Edit pull secret adding cred for new registry:

```
oc get secret/pull-secret -n openshift-config --template='{{index .data ".dockerconfigjson" | base64decode}}' > pull-secret
oc registry login --registry=quay-2.sandbox1829.opentlc.com --auth-basic="openshift+ocp:*******************" --to=pull-secret
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=pull-secret
```

3. Edit ImageContentSourcePolicy and add the new mirror
```
oc edit ImageContentSourcePolicy image-policy-0

# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  creationTimestamp: "2023-06-13T01:21:21Z"
  generation: 1
  name: image-policy-0
  resourceVersion: "1107"
  uid: 54282e12-5398-495c-98a6-54b44185469c
spec:
  repositoryDigestMirrors:
  - mirrors:
    - quay-public.sandbox1829.opentlc.com/openshift/openshift/release-images
    - quay-2.sandbox1829.opentlc.com/openshift/openshift/release-images
    source: quay.io/openshift-release-dev/ocp-release

oc edit ImageContentSourcePolicy image-policy-1

# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  creationTimestamp: "2023-06-13T01:21:21Z"
  generation: 2
  name: image-policy-1
  resourceVersion: "57867"
  uid: 41167c1f-1227-467e-8a9c-13ccd14f40d1
spec:
  repositoryDigestMirrors:
  - mirrors:
    - quay-public.sandbox1829.opentlc.com/openshift/openshift/release
    - quay-2.sandbox1829.opentlc.com/openshift/openshift/release
    source: quay.io/openshift-release-dev/ocp-v4.0-art-dev

```

**Result:** File /etc/containers/registries.conf is updated automatically:

```
[core@ip-10-0-139-196 ~]$ cat /etc/containers/registries.conf
unqualified-search-registries = ["registry.access.redhat.com", "docker.io"]
short-name-mode = ""

[[registry]]
  prefix = ""
  location = "quay.io/openshift-release-dev/ocp-release"
  mirror-by-digest-only = true

  [[registry.mirror]]
    location = "quay-public.sandbox1829.opentlc.com/openshift/openshift/release-images"

  [[registry.mirror]]
    location = "quay-2.sandbox1829.opentlc.com/openshift/openshift/release-images"

[[registry]]
  prefix = ""
  location = "quay.io/openshift-release-dev/ocp-v4.0-art-dev"
  mirror-by-digest-only = true

  [[registry.mirror]]
    location = "quay-public.sandbox1829.opentlc.com/openshift/openshift/release"

  [[registry.mirror]]
    location = "quay-2.sandbox1829.opentlc.com/openshift/openshift/release"
```


