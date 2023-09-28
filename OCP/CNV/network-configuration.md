# COMMANDS

```bash
# NetworkNodeState
oc get nns 

# Create NodeNetworkConfigurationPolicy
cat << EOF | oc apply -f -
apiVersion: nmstate.io/v1alpha1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: br1-enp2s0-policy-workers
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
  desiredState:
    interfaces:
      - name: br1
        description: Linux bridge with enp2s0 as a port
        type: linux-bridge
        state: up
        ipv4:
          enabled: false
        bridge:
          options:
            stp:
              enabled: false
          port:
            - name: enp2s0
EOF

# NodeNetworkConfigurationPolicy
oc get nncp

# NodeNetworkConfigurationEnactment
oc get nnce

# NetworkAttachmentDefinition
cat << EOF | oc apply -f -
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: tuning-bridge-fixed
  annotations:
    k8s.v1.cni.cncf.io/resourceName: bridge.network.kubevirt.io/br1
spec:
  config: '{
    "cniVersion": "0.3.1",
    "name": "groot",
    "plugins": [
      {
        "type": "cnv-bridge",
        "bridge": "br1"
      },
      {
        "type": "tuning"
      }
    ]
  }'
EOF
```

Reference: https://github.com/rdoxenham/openshift-virt-labs/blob/master/docs/workshop/content/network-setup.md