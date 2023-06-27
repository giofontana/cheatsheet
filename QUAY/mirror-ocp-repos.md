
# Using oc mirror to mirror repositories to Quay for air-gapped OCP installation

* In a RHEL box run the following (DO NOT RUN THE FOLLOWING WITH ROOT USER!)

```bash
QUAY_HOST=quay-public.sandbox1829.opentlc.com
sudo dnf install jq podman wget -y
cat ./pull-secret.txt | jq . > ./pull-secret.json
podman login $QUAY_HOST
cat ./pull-secret.json # COPY CONTENT

vi $XDG_RUNTIME_DIR/containers/auth.json # PASTE CONTENT HERE BETWEEN BRACKETS
```

* Test it using the following command:

```
podman login registry.redhat.io
```

* You should see the following output:

```
$ podman login registry.redhat.io
Authenticating with existing credentials for registry.redhat.io
Existing credentials are valid. Already logged in to registry.redhat.io

```

* Run oc mirror init:

```bash
wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz
tar xvzf openshift-client-linux.tar.gz
chmod +x oc
sudo mv oc /bin

wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/oc-mirror.tar.gz
tar xvzf oc-mirror.tar.gz
chmod +x oc-mirror
sudo mv oc-mirror /bin
oc mirror help

oc mirror init --registry $QUAY_HOST/openshift/oc-mirror-metadata > imageset-config.yaml 
```

* Edit the file imageset-config.yaml with your changes. Examples: https://github.com/openshift/oc-mirror/tree/main/docs/examples

* Run the mirror:

```
oc mirror --config=./imageset-config.yaml \
  docker://$QUAY_HOST/openshift
```

* After finish run the following to the the ImageContentSourcePolicy:

```
cat oc-mirror-workspace/results-1686609747/imageContentSourcePolicy.yaml
```

## Useful commands:

```bash
oc mirror list operators --catalog registry.redhat.io/redhat/redhat-operator-index:v4.11
oc mirror list operators --package rhacs-operator --catalog registry.redhat.io/redhat/redhat-operator-index:v4.11
```


## References:

https://cloud.redhat.com/blog/mirroring-openshift-registries-the-easy-way
https://github.com/openshift/oc-mirror/tree/main/docs/examples

