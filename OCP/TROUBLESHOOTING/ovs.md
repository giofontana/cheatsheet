
# OVS Helpful commands

List of commands:

```
sudo ovs-appctl list-commands
```

## For OVS Bond 

Getting bond statistics 

```
# sudo ovs-appctl bond/show
---- ovs-bond ----
bond_mode: balance-slb
bond may use recirculation: no, Recirc-ID : -1
bond-hash-basis: 0
lb_output action: disabled, bond-id: -1
all members active: false
updelay: 0 ms
downdelay: 0 ms
next rebalance: 5590 ms
lacp_status: off
lacp_fallback_ab: false
active-backup primary: <none>
active member mac: xx:yy:zz:12:15:58(eno1)

member eno1: enabled
  active member
  may_enable: true
  hash 77: 22327 kB load

member eno2: enabled
  may_enable: true
```

Finding hash:

```
# sudo ovs-appctl bond/hash 'xx:yy:zz:12:15:58'
77
```

## For Bridge Mappings

```
ovs-vsctl get Open_vSwitch . external_ids:ovn-bridge-mappings
ovn-nbctl list logical_switch_port | grep network_name -A10 -B10

# When a new bridge-mapping is created for instance for br-ex, you will see a new mapping, example:
# $ ovs-vsctl get Open_vSwitch . external_ids:ovn-bridge-mappings
# "physnet:br-ex,trunk:br-ex"
```

