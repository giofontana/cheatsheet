
# Using wildcard domains in pihole

1. Log into pihole container
2. Enable dnsmasq:

```
vi /etc/pihole/pihole.toml

# Should FTL load additional dnsmasq configuration files from /etc/dnsmasq.d/?          
# Warning: This is an advanced setting and should only be used with care.             
# Incorrectly formatted or config files specifying options which can only be defined
# once can result in conflicts with the automatic configuration of Pi-hole (see       
# /etc/pihole/dnsmasq.conf) and may stop DNS resolution from working.                 
etc_dnsmasq_d = true ### CHANGED, default = false                  
```

3. Create dnsmasq file:

```
vi /etc/dnsmasq.d/ocp-wildcard.conf
address=/apps.ocp.<domain>/<vip>
```
