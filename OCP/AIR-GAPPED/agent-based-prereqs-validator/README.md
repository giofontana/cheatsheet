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

## Exit status

- `0`: no checks failed (warnings may be present).
- `1`: one or more checks failed, or required dependencies are missing.
- `2`: usage error or `--help`.

The script creates a temporary directory for extracted certificates and registry credentials and removes it on exit. Do not share validation output without reviewing it for environment-specific hostnames and addresses.
