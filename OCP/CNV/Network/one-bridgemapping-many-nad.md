
To be able to have one single NNCP bridge-mapping to many NAD, use `physicalNetworkName`.

**Instructions**

NNCP:

```
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: trunk
spec:
  desiredState:
    ovn:
      bridge-mappings:
        - bridge: br-ex
          localnet: trunk #1
          state: present
```

On NAD use the `physicalNetworkName` with same name used at `spec.desiredState.ovn.bridge-mappings[].localnet`

```
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: vlan1
  namespace: default
spec:
  config: '{
    "name":"vlan1",
    "type":"ovn-k8s-cni-overlay",
    "cniVersion":"0.4.0",
    "physicalNetworkName":"trunk", #2
    "vlanId": 1,
    "topology":"localnet",
    "netAttachDefName":"default/vlan1"
    }'
```

Values `#1` and `#2` needs to match.

More examples:

```
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: vlan2
  namespace: default
spec:
  config: '{
    "name":"vlan2",
    "type":"ovn-k8s-cni-overlay",
    "cniVersion":"0.4.0",
    "physicalNetworkName":"trunk",
    "vlanId": 2,
    "topology":"localnet",
    "netAttachDefName":"default/vlan2"
    }'
```

```
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: vlan3
  namespace: default
spec:
  config: '{
    "name":"vlan3",
    "type":"ovn-k8s-cni-overlay",
    "cniVersion":"0.4.0",
    "physicalNetworkName":"trunk",
    "vlanId": 3,
    "topology":"localnet",
    "netAttachDefName":"default/vlan3"
    }'
```

```
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: vlan4
  namespace: default
spec:
  config: '{
    "name":"vlan4",
    "type":"ovn-k8s-cni-overlay",
    "cniVersion":"0.4.0",
    "physicalNetworkName":"trunk",
    "vlanId": 4,
    "topology":"localnet",
    "netAttachDefName":"default/vlan4"
    }'    
```

Helpful commands:

```
ovs-vsctl get Open_vSwitch . external_ids:ovn-bridge-mappings
ovn-nbctl list logical_switch_port | grep network_name -A10 -B10
```

When a new bridge-mapping is created for instance for br-ex, you will see a new mapping:

```
# ovs-vsctl get Open_vSwitch . external_ids:ovn-bridge-mappings
"physnet:br-ex,trunk:br-ex"
```
