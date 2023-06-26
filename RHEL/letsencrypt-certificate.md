# Generate Let's Encrypt Certificate on RHEL/CentOS 8


```bash
sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y
sudo dnf install certbot python3-certbot-apache -y
sudo certbot --version
sudo certbot certonly --standalone
```
