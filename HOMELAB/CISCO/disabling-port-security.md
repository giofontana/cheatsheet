# DISABLE PORT SECURITY

```
conf t
interface range Gi1/0/1-52
no switchport port-security
no switchport port-security violation
no switchport port-security aging time
no switchport port-security aging type
no switchport port-security mac-address sticky
exit
write mem
```
