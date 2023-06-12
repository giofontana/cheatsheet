
DO NOT RUN THE FOLLOWING WITH ROOT USER!

```bash
QUAY_HOST=quay-public.sandbox1829.opentlc.com
dnf install jq
cat ./pull-secret.txt | jq . > ./pull-secret.json
podman login $QUAY_HOST
cat ./pull-secret.json # COPY CONTENT

vi $XDG_RUNTIME_DIR/containers/auth.json # PASTE CONTENT HERE BETWEEN BRACKETS
```

Test it using the following command:

```
podman login registry.redhat.io
```

Should see the following output:

```
# podman login registry.redhat.io
Authenticating with existing credentials for registry.redhat.io
Existing credentials are valid. Already logged in to registry.redhat.io

```

Run oc mirror init:

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

Edit the file imageset-config.yaml with your changes. Examples: https://github.com/openshift/oc-mirror/tree/main/docs/examples

Run the mirror:

```
oc mirror --config=./imageset-config.yaml \
  docker://$QUAY_HOST/openshift
```