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

Assign VLANs to Ports:
```
configure terminal
interface range Gi1/0/37-50
switchport access vlan 30
exit
end
write mem
```

Configure Trunk Port for pfSense:
```
interface Gi1/0/1
switchport mode trunk
switchport trunk allowed vlan 1,10,20,30
exit
end
write mem
```

Trunk with native VLAN:
```
interface <interface-id>
 switchport mode trunk
 switchport trunk native vlan 3
 switchport trunk allowed vlan all
exit
end
write mem
```
