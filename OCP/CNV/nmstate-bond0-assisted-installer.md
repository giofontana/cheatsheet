
# Assisted Installer with Bond

Use this yaml on Assisted Installer to deploy nodes using bonds:

**Note**: Requires LACP/MLAG - Other modes supported are: balance-xor, and active-backup

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