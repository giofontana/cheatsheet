# Deploy all-in-one Quay

* Run the following commands in a RHEL 8 VM:

```bash
sudo dnf install podman -y
sudo podman login registry.redhat.io

export QUAY=/opt/quay
mkdir -p $QUAY/postgres-quay
setfacl -m u:26:-wx $QUAY/postgres-quay

sudo podman run -d --rm --name postgresql-quay \
  -e POSTGRESQL_USER=quayuser \
  -e POSTGRESQL_PASSWORD=quaypass \
  -e POSTGRESQL_DATABASE=quay \
  -e POSTGRESQL_ADMIN_PASSWORD=adminpass \
  -p 5432:5432 \
  -v $QUAY/postgres-quay:/var/lib/pgsql/data:Z \
  registry.redhat.io/rhel8/postgresql-13:1-109

sudo podman run -d --rm --name redis \
-p 6379:6379 \
-e REDIS_PASSWORD=strongpassword \
registry.redhat.io/rhel8/redis-6:1-110

sudo podman exec -it postgresql-quay /bin/bash -c 'echo "CREATE EXTENSION IF NOT EXISTS pg_trgm" | psql -d quay -U postgres'
sudo podman run --rm -it --name quay_config -p 80:8080 -p 443:8443 registry.redhat.io/quay/quay-rhel8:v3.8.7 config secret
```

* Log into config web page using credentials below:

```
username: quayconfig
password: secret
```

**NOTE**: If needed use the letsencrypt procedure in ../RHEL/letsencrypt-certificate.md to create a let's encrypt certificate to use with Quay.

* Follow the instructions as stated here: https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html-single/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index#poc-configuring-quay

* Prepare Quay configuration:

```bash
mkdir $QUAY/config
cp ~/Downloads/quay-config.tar.gz $QUAY/config/
cd $QUAY/config
tar xvf quay-config.tar.gz
mkdir $QUAY/storage
setfacl -m u:1001:-wx $QUAY/storage
```

* Run it:

```bash
sudo podman run -d --rm -p 80:8080 -p 443:8443  \
--name=quay \
-v $QUAY/config:/conf/stack:Z \
-v $QUAY/storage:/datastorage:Z \
registry.redhat.io/quay/quay-rhel8:v3.8.7
```
