
# Creating new execution environment

1. Pre-req: Run from a RHEL 9 server registered with subscription manager
2. Install ansible-builder

```
sudo dnf install python3 python3-pip podman systemd-devel
pip install ansible-builder --user
```

3. Create execution-environment.yml

```
mkdir openshift_installer_ee && cd openshift_installer_ee

cat <<EOF > execution-environment.yml
version: 3

images:
  base_image: 
    name: 'registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel8:latest'

dependencies:
  galaxy:
    collections:
      - name: 'amazon.aws'
  system:
    - nmstate [platform:rpm]

options:
  package_manager_path: '/usr/bin/microdnf'

EOF
```

4. Build image:

```
podman login registry.redhat.io
ansible-builder build --tag <registry>/<user>/openshift_installer_ee
```

5. Push into registry:
```
podman login <registry> --tls-verify=false
podman push <registry>/<user>/openshift_installer_ee --tls-verify=false
```
