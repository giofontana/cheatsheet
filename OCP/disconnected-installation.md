
* To reproduce a disconnected installation on AWS, proceed with the following.
  * Create a VPC with a public and private subnet
  * On public subnet use the ../QUAY/all-in-one-deploy.md to deploy a quay instance
  * Use this procedure to mirror OCP images: QUAY/mirror-ocp-repos.md
  * On quay install squid as a proxy server, instructions here: ../RHEL/install-squid-proxy.md
  * Deploy a bastion (RHEL 8) on private subnet
  * Run the installation using quay as the image registry and also proxy

* Commands:

```bash


* Example of install-config for a disconnected installation:

```yaml
apiVersion: v1
baseDomain: sandbox1829.opentlc.com
publish: Internal
proxy:
  httpProxy: http://10.0.11.251:3128
  httpsProxy: http://10.0.11.251:3128
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform:
    aws:
      rootVolume:
        iops: 2000
        size: 500
        type: io1 
      metadataService:
        authentication: Optional 
      type: m5.2xlarge
      zones:
      - us-east-2a
  replicas: 3
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform: 
    aws:
      rootVolume:
        iops: 2000
        size: 500
        type: io1
      metadataService:
        authentication: Optional
      type: m5.2xlarge
      zones:
      - us-east-2a
  replicas: 3
metadata:
  creationTimestamp: null
  name: ocppoc
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.0.128.0/20
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  aws:
    region: us-east-2
    subnets:
    - subnet-0fe58c47b5ea9e635
pullSecret: '{"auths": {"quay-public.sandbox1829.opentlc.com": {"auth": "***********************"}}}'
additionalTrustBundle: |
  -----BEGIN CERTIFICATE-----
  MIIFTjCCBDagAwIBAgISBKscXB6oy8PiyVq8KEKMWHQoMA0GCSqGSIb3DQEBCwUA
  MDIxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQswCQYDVQQD
  **************
  vdMRafjhVAO/bvXgVg8sLugi
  -----END CERTIFICATE-----
  -----BEGIN CERTIFICATE-----
  MIIFFjCCAv6gAwIBAgIRAJErCErPDBinU/bWLiWnX1owDQYJKoZIhvcNAQELBQAw
  **************
  HlUjr8gRsI3qfJOQFy/9rKIJR0Y/8Omwt/8oTWgy1mdeHmmjk7j1nYsvC9JSQ6Zv
  MldlTTKB3zhThV1+XWYp6rjd5JW1zbVWEkLNxE7GJThEUG3szgBVGP7pSWTUTsqX
  nLRbwHOoq7hHwg==
  -----END CERTIFICATE-----
  -----BEGIN CERTIFICATE-----
  MIIFYDCCBEigAwIBAgIQQAF3ITfU6UK47naqPGQKtzANBgkqhkiG9w0BAQsFADA/
  MSQwIgYDVQQKExtEaWdpdGFsIFNpZ25hdHVyZSBUcnVzdCBDby4xFzAVBgNVBAMT
  ******************
  WCLKTVXkcGdtwlfFRjlBz4pYg1htmf5X6DYO8A4jqv2Il9DjXA6USbW1FzXSLr9O
  he8Y4IWS6wY7bCkjCWDcRQJMEhg76fsO3txE+FiYruq9RUWhiF1myv4Q6W+CyBFC
  Dfvp7OOGAN6dEOM4+qR9sdjoSYKEBpsr6GtPAQw4dy753ec5
  -----END CERTIFICATE-----
imageContentSources:
  - mirrors:
    - quay-public.sandbox1829.opentlc.com/openshift/openshift/release-images
    source: quay.io/openshift-release-dev/ocp-release
  - mirrors:
    - quay-public.sandbox1829.opentlc.com/openshift/openshift/release
    source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
sshKey: 'ssh-ed25519 AAAAC3Nza************' 
```
