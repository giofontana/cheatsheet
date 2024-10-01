# Creating new VLANs and Linux Bridges

First create a NNCP to create the new VLAN interfaces and the linux bridge:

```yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: vlan4-bond0
spec:
  desiredState:
    interfaces:
      - description: vlan4 using bond0
        ipv4:
          enabled: false
        name: bond0.4
        state: up
        type: vlan
        vlan:
          base-iface: bond0
          id: 4
      - bridge:
          options:
            stp:
              enabled: false
          port:
            - name: bond0.4
        description: Bridge on VLAN4 using bond0
        ipv4:
          enabled: false
        name: br-4
        state: up
        type: linux-bridge
```

Now create the NAD to connect the VMs to the linux-bridge. If you create it on default project, it will be available for all projects:

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: vm-net-vlan4
  namespace: default
spec:
  config: '{"name":"vm-net-vlan4","type":"bridge","cniVersion":"0.3.1","bridge":"br-4","macspoofchk":true,"ipam":{},"preserveDefaultVlan":false}'
```