# INITIAL SETUP

```
telnet 10.0.0.1

enable
conf t
banner motd #
<MSG> #
line vty 0 15
password ******
login
exit
int vlan1
ip address 192.168.100.2 255.255.255.0
no shutdown
exit

enable password *****
ip default-gateway 192.168.100.1
ip http server
do show run
exit

write mem
```


https://community.cisco.com/t5/networking-knowledge-base/webcast-vip-slides-ios-upgrade-on-catalyst-switches-2900-3500/ta-p/3165049?attachment-id=13952