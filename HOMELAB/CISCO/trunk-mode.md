# Configure a port to Trunk mode

```
configure terminal
interface interface-id
switchport mode trunk
switchport trunk native vlan 1
end
show interfaces interface-id switchport
show interfaces interface-id trunk
copy running-config startup-config
write mem
```
