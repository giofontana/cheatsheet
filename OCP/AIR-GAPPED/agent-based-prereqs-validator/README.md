# OpenShift Agent-Based Installation Prerequisite Validator

`validate-prereqs.sh` checks an OpenShift agent-based installation's `install-config.yaml` and `agent-config.yaml` before installation. It validates configuration consistency, resolves expected DNS records, and checks mirror-registry connectivity and TLS when registry settings are present.

The script reports each check as `PASS`, `WARN`, or `FAIL`. Warnings do not cause a nonzero exit; any failure does.

## Requirements

- Bash
- Python 3 and PyYAML
- OpenSSL
- curl
- Either `dig` or `nslookup` (DNS checks require one)

Install PyYAML with `python3 -m pip install PyYAML` or your operating system's package manager (for example, `dnf install python3-pyyaml`).

## Usage

Run the script with a directory containing both configuration files:

```sh
./validate-prereqs.sh install
```

This expects:

```text
install/
  install-config.yaml
  agent-config.yaml
```

You can also validate the included `my-lab` configuration directory:

```sh
./validate-prereqs.sh my-lab
```

Options:

```text
--dns-server IP   Query this DNS server; may be supplied more than once
--skip-dns        Skip DNS checks
--skip-registry   Skip mirror-registry checks
-h, --help        Show usage
```

For example, to query a particular DNS server and skip registry checks:

```sh
./validate-prereqs.sh install --dns-server 192.0.2.53 --skip-registry
```

Without `--dns-server`, the script uses DNS servers listed in the agent config's `networkConfig.dns-resolver.config.server`, then checks the system resolver as well. If no DNS servers are configured, it warns and checks the system resolver only.

## What it checks

### Configuration

- YAML syntax and required `install-config.yaml` keys.
- Machine, cluster, and service network CIDRs, including overlap and machine-network validity.
- API and ingress VIPs for `baremetal`, `vsphere`, and `nutanix` platforms, including whether they are in the machine network and differ from each other. Other platforms receive a warning and skip VIP validation.
- Pull-secret JSON and registry auth entries; mirror-source format and credentials when available.
- `additionalTrustBundle` PEM certificates and their expiration dates.
- `imageDigestSources` entries (or deprecated `imageContentSources`, with a warning).
- Agent-config API version and kind, cluster name, host roles, interfaces and MAC addresses, host IPs, rendezvous IP, and replica counts.

Some checks are informational or warnings rather than failures. For example, SSH-key shape, missing mirror credentials, and hosts without an explicit role are warnings.

### DNS

For each selected resolver, the script checks:

- `api.<cluster>.<base-domain>` and `api-int.<cluster>.<base-domain>` against the first API VIP, when defined.
- A generated name under `*.apps.<cluster>.<base-domain>`, plus the console and OAuth application names, against the first ingress VIP, when defined.
- A records for configured hosts with static IPs and PTR records for hosts and API VIPs.
- A records for mirror registry hostnames.

PTR mismatches, missing host records, and records for hosts without static IPs are warnings. API, ingress, and mirror DNS failures are failures.

### Mirror registry

Registry checks run only when mirror sources are configured and `additionalTrustBundle` contains a certificate bundle. For each mirror registry, the script checks TLS trust and hostname/IP verification, the registry `/v2/` endpoint, and pull-secret authentication when credentials are available. For mirror paths, it also attempts to list repository tags; inability to list tags is reported as a warning.

Use `--skip-registry` to omit these network checks. If mirror sources are present without a trust bundle, registry checks are skipped with a warning.

## Example output

The following run (hostnames and addresses anonymized) shows a three-node compact cluster with a few typical problems:

- The mirror entries in `imageDigestSources` include an `https://` scheme, which is not allowed (use `host[:port]/path`).
- `agent-config.yaml` has no `metadata.name`.
- `api-int` resolves to a different address than the API VIP.
- The pull-secret credentials authenticate to the registry but cannot list tags in the mirror repositories.

```text
# ./validate-prereqs.sh /root/ocp-install/

== Dependencies ==
  [PASS] python3 found
  [PASS] openssl found
  [PASS] curl found
  [PASS] python3 PyYAML found
  [PASS] dig found

== 1) Config file format ==
  [PASS] install-config.yaml: valid YAML
  [PASS] agent-config.yaml: valid YAML
  [PASS] install-config: required keys present
  [PASS] install-config: network CIDRs valid and non-overlapping (clusterNetwork=10.128.0.0/14, machineNetwork=192.0.2.0/24, serviceNetwork=172.30.0.0/16)
  [PASS] install-config: apiVIPs 192.0.2.208 inside machineNetwork
  [PASS] install-config: ingressVIPs 192.0.2.210 inside machineNetwork
  [PASS] install-config: pullSecret is valid JSON (1 registries: quay.example.com)
  [FAIL] install-config: mirror 'https://quay.example.com/repository/openshift/base/openshift/release' must not include a scheme (use host[:port]/path)
  [FAIL] install-config: mirror 'https://quay.example.com/repository/openshift/ocp422/openshift/release-images' must not include a scheme (use host[:port]/path)
  [PASS] install-config: 2 imageDigestSources entries parsed
  [PASS] agent-config: apiVersion/kind ok
  [WARN] agent-config: metadata.name missing (should match install-config metadata.name)
  [PASS] agent-config: 3 hostnames unique
  [PASS] agent-config: 6 MAC addresses unique
  [PASS] agent-config: 3 IPs unique
  [PASS] agent-config: rendezvousIP 192.0.2.201 matches a host
  [PASS] agent-config: host roles match replicas (3 masters, 0 workers)
  [PASS] additionalTrustBundle cert C=US, ST=State, L=City, O=Example, CN=quay.example.com, emailAddress=admin@example.com (expires Jul 29 15:13:53 2029 GMT)

== 2) DNS ==
  -- resolver: 192.0.2.53
  [PASS] api.ocp01.example.com -> 192.0.2.208 (server: 192.0.2.53)
  [FAIL] api-int.ocp01.example.com -> 192.0.2.209, expected 192.0.2.208 (server: 192.0.2.53)
  [PASS] validate-64828-369.apps.ocp01.example.com -> 192.0.2.210 (server: 192.0.2.53)
  [PASS] console-openshift-console.apps.ocp01.example.com -> 192.0.2.210 (server: 192.0.2.53)
  [PASS] oauth-openshift.apps.ocp01.example.com -> 192.0.2.210 (server: 192.0.2.53)
  [PASS] PTR 192.0.2.208 -> api.ocp01.example.com (server: 192.0.2.53)
  [PASS] master01.ocp01.example.com -> 192.0.2.201 (server: 192.0.2.53)
  [PASS] PTR 192.0.2.201 -> master01.ocp01.example.com (server: 192.0.2.53)
  [PASS] master02.ocp01.example.com -> 192.0.2.202 (server: 192.0.2.53)
  [PASS] PTR 192.0.2.202 -> master02.ocp01.example.com (server: 192.0.2.53)
  [PASS] master03.ocp01.example.com -> 192.0.2.203 (server: 192.0.2.53)
  [PASS] PTR 192.0.2.203 -> master03.ocp01.example.com (server: 192.0.2.53)
  [PASS] quay.example.com -> 192.0.2.50 (server: 192.0.2.53)
  -- resolver: system (192.0.2.53)
  [PASS] api.ocp01.example.com -> 192.0.2.208 (server: system)
  [FAIL] api-int.ocp01.example.com -> 192.0.2.209, expected 192.0.2.208 (server: system)
  [PASS] validate-64828-254.apps.ocp01.example.com -> 192.0.2.210 (server: system)
  [PASS] console-openshift-console.apps.ocp01.example.com -> 192.0.2.210 (server: system)
  [PASS] oauth-openshift.apps.ocp01.example.com -> 192.0.2.210 (server: system)
  [PASS] PTR 192.0.2.208 -> api.ocp01.example.com (server: system)
  [PASS] master01.ocp01.example.com -> 192.0.2.201 (server: system)
  [PASS] PTR 192.0.2.201 -> master01.ocp01.example.com (server: system)
  [PASS] master02.ocp01.example.com -> 192.0.2.202 (server: system)
  [PASS] PTR 192.0.2.202 -> master02.ocp01.example.com (server: system)
  [PASS] master03.ocp01.example.com -> 192.0.2.203 (server: system)
  [PASS] PTR 192.0.2.203 -> master03.ocp01.example.com (server: system)
  [PASS] quay.example.com -> 192.0.2.50 (server: system)

== 3) Mirror registry ==
  -- quay.example.com:443
  [PASS] TLS verified with additionalTrustBundle, hostname/IP matches certificate (TLSv1.3)
  [PASS] openssl chain: Verify return code: 0 (ok)
         server cert subject=C=US, ST=State, L=City, O=Example, CN=quay.example.com, emailAddress=admin@example.com
         SAN: DNS:quay.example.com, IP Address:192.0.2.50
         expires: Sep 30 15:29:32 2027 GMT
  [PASS] GET https://quay.example.com:443/v2/ -> HTTP 401 (curl --cacert)
  [PASS] authenticated GET /v2/ with pullSecret credentials -> HTTP 200 (bearer token)
  [WARN] repository quay.example.com/repository/openshift/base/openshift/release: tags/list -> HTTP 401 (bearer token)
  [WARN] repository quay.example.com/repository/openshift/ocp422/openshift/release-images: tags/list -> HTTP 401 (bearer token)

== Summary ==
  48 passed, 3 warnings, 4 failed
```

## Exit status

- `0`: no checks failed (warnings may be present).
- `1`: one or more checks failed, or required dependencies are missing.
- `2`: usage error or `--help`.

The script creates a temporary directory for extracted certificates and registry credentials and removes it on exit. Do not share validation output without reviewing it for environment-specific hostnames and addresses.
