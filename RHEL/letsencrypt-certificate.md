# Generate Let's Encrypt Certificate on RHEL/CentOS 8


```bash
sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
sudo dnf install certbot python3-certbot-apache
certbot --version
certbot certonly --standalone
```
