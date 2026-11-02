# Generate Let's Encrypt Certificate on RHEL/CentOS 8


```bash
sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y
sudo dnf install certbot python3-certbot-apache -y
sudo certbot --version
sudo certbot certonly --standalone
```


```bash
wget https://github.com/joohoi/acme-dns-certbot-joohoi/raw/master/acme-dns-auth.py
chmod +x acme-dns-auth.py
vi acme-dns-auth.py
# Change python to python3
#!/usr/bin/env python3

sudo mv acme-dns-auth.py /etc/letsencrypt/
sudo certbot certonly --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --debug-challenges -d quay.lab.gfontana.me

# Add the CNAME indicated in the DNS
```
