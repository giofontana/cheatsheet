
# Assisted Installer with Bond

Use this yaml on Assisted Installer to deploy nodes using bonds:

**Notes**: 
1. Requires LACP/MLAG - Other modes supported are: balance-xor, and active-backup
2. This example uses static IP with VLAN. See here examples with DHCP: https://docs.openshift.com/container-platform/4.16/networking/k8s_nmstate/k8s-nmstate-updating-node-network-config.html#virt-creating-interface-on-nodes_k8s_nmstate-updating-node-network-config

**With Static IP:**

```yaml
interfaces:
- name: eno1
  description: Ethernet eno1
  type: ethernet
  state: up
  ipv4:
    enabled: false
- name: eno2
  description: Ethernet eno1
  type: ethernet
  state: up
  ipv4:
    enabled: false
- name: bond0
  description: Bond with ports eno1 and eno2
  type: bond
  state: up
  ipv4:
    dhcp: false
    enabled: false
  link-aggregation:
    mode: 802.3ad
    options:
      miimon: '100'
    port:
    - eno1
    - eno2
- name: bond0.3
  description: VLAN3 using bond0
  type: vlan
  state: up
  ipv4:
    address: 
    - ip: 10.0.1.11
      prefix-length: 24
    enabled: true
  vlan:
    base-iface: bond0
    id: 3
routes:
  config:
  - destination: 0.0.0.0/0
    next-hop-address: 10.0.1.1 
    next-hop-interface: bond0.3
dns-resolver:
  config:
    search:
    - gfontana.me
    - lab.gfontana.me
    server:
    - 10.0.1.2
```    

**With DHCP:**

```yaml
interfaces:
- name: eno1
  description: Ethernet eno1
  type: ethernet
  state: up
  ipv4:
    enabled: false
- name: eno2
  description: Ethernet eno2
  type: ethernet
  state: up
  ipv4:
    enabled: false
- name: bond0
  description: Bond with ports eno1 and eno2
  type: bond
  state: up
  ipv4:
    dhcp: false
    enabled: false
  link-aggregation:
    mode: 802.3ad
    options:
      miimon: '100'
    port:
    - eno1
    - eno2
- name: bond0.3
  description: VLAN3 using bond0
  type: vlan
  state: up
  ipv4:
    dhcp: true
    enabled: true
  vlan:
    base-iface: bond0
    id: 3
routes:
  config:
  - destination: 0.0.0.0/0
    next-hop-address: 10.0.1.1 
    next-hop-interface: bond0.3
dns-resolver:
  config:
    search:
    - gfontana.me
    - lab.gfontana.me
    server:
    - 10.0.1.2
```    
