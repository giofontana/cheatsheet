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
          allow-extra-patch-ports: true
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
        type: ovs-bridge
    ovn:
      bridge-mappings:
        - bridge: br-4
          localnet: ovs-bridge-localnet
          state: present
```

Create the NAD using the same name in `locanet` (in this case `ovs-bridge-localnet`):

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: ovs-bridge-localnet
  namespace: default
spec:
  config: '{"name":"ovs-bridge-localnet","type":"ovn-k8s-cni-overlay","cniVersion":"0.4.0","topology":"localnet","netAttachDefName":"default/ovs-bridge-localnet"}'
```

Important notes:
1. Use the SAME name on both NNCP `spec.desiredState.ovn.bridge-mappings[*].localnet` and NAD `spec.config.name`
2. Define netAttachDefName to the NAD `namespace/name`