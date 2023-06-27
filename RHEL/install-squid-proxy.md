
```bash
sudo yum -y install squid
sudo systemctl start squid
sudo systemctl enable squid

sudo -i
cat <<EOF > /etc/squid/whitelist.txt 
.google.com
.redhat.com
.openshift.com
.aws
.amazonaws.com
.opentlc.com
EOF

cat <<EOF > /etc/squid/squid.conf
 
# An ACL named 'whitelist'
acl whitelist dstdomain '/etc/squid/whitelist.txt'
 
# Allow whitelisted URLs through
http_access allow whitelist
 
# Block the rest
http_access deny all
 
# Default port
http_port 3128
EOF
exit
sudo systemctl restart squid
```
