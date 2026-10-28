#!/usr/bin/env bash
#
# Pre-requisite validation for OpenShift agent-based installation.
#
#   1) install-config.yaml / agent-config.yaml format and consistency
#   2) DNS records (api, api-int, *.apps, nodes, PTR)
#   3) Mirror registry TLS/auth, using additionalTrustBundle + imageDigestSources
#   4) NTP servers from agent-config additionalNTPSources (SNTP query from this host)
#
# Usage: ./validate-prereqs.sh <config-dir> [--dns-server IP]... [--skip-dns] [--skip-registry] [--skip-ntp]
#
# Requires: python3 + PyYAML, openssl, curl, dig or nslookup.
# Exit code: 0 if no FAIL, 1 otherwise.

set -u

usage() {
  sed -n '9p' "$0" | sed 's/^# //'
  exit 2
}

CONFIG_DIR=""
DNS_OVERRIDE=""
SKIP_DNS=0
SKIP_REGISTRY=0
SKIP_NTP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dns-server) [ $# -ge 2 ] || usage; DNS_OVERRIDE="${DNS_OVERRIDE} $2"; shift 2 ;;
    --skip-dns) SKIP_DNS=1; shift ;;
    --skip-registry) SKIP_REGISTRY=1; shift ;;
    --skip-ntp) SKIP_NTP=1; shift ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *) [ -z "$CONFIG_DIR" ] || usage; CONFIG_DIR="$1"; shift ;;
  esac
done
[ -n "$CONFIG_DIR" ] || usage

INSTALL_CONFIG="${CONFIG_DIR%/}/install-config.yaml"
AGENT_CONFIG="${CONFIG_DIR%/}/agent-config.yaml"

# ---------------------------------------------------------------- output helpers
if [ -t 1 ]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_BLU=$'\033[1;34m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_OFF=""
fi
N_PASS=0; N_WARN=0; N_FAIL=0
pass()    { N_PASS=$((N_PASS+1)); echo "  ${C_GRN}[PASS]${C_OFF} $*"; }
warn()    { N_WARN=$((N_WARN+1)); echo "  ${C_YEL}[WARN]${C_OFF} $*"; }
fail()    { N_FAIL=$((N_FAIL+1)); echo "  ${C_RED}[FAIL]${C_OFF} $*"; }
info()    { echo "  ${C_DIM}       $*${C_OFF}"; }
section() { echo; echo "${C_BLU}== $* ==${C_OFF}"; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ocp-validate.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------- dependencies
section "Dependencies"
DEPS_OK=1
for bin in python3 openssl curl; do
  if command -v "$bin" >/dev/null 2>&1; then pass "$bin found"; else fail "$bin not found"; DEPS_OK=0; fi
done
if command -v python3 >/dev/null 2>&1; then
  if python3 -c 'import yaml' 2>/dev/null; then pass "python3 PyYAML found"; else fail "python3 PyYAML not found (pip install pyyaml / dnf install python3-pyyaml)"; DEPS_OK=0; fi
fi
if command -v dig >/dev/null 2>&1; then
  DNS_TOOL=dig; pass "dig found"
elif command -v nslookup >/dev/null 2>&1; then
  DNS_TOOL=nslookup; pass "nslookup found (dig not found)"
else
  DNS_TOOL=""; fail "neither dig nor nslookup found"
fi
if [ "$DEPS_OK" -eq 0 ]; then
  echo; echo "${C_RED}Missing required dependencies, aborting.${C_OFF}"; exit 1
fi

# ---------------------------------------------------------------- 1) format
section "1) Config file format"

# The Python helper prints:
#   PASS|msg, WARN|msg, FAIL|msg   -> validation results
#   KEY=value                      -> facts used by the DNS / registry checks
# Certificates and registry credentials are written to files in $TMP, never to stdout.
PY_OUT=$(python3 - "$INSTALL_CONFIG" "$AGENT_CONFIG" "$TMP" <<'PY'
import base64, ipaddress, json, os, re, sys

ic_path, ac_path, tmp = sys.argv[1:4]

def out(level, msg):
    print(f"{level}|{msg}")

def fact(key, value):
    print(f"{key}={value}")

try:
    import yaml
except ImportError:
    out("FAIL", "PyYAML not available"); sys.exit(0)

def load(path):
    if not os.path.isfile(path):
        out("FAIL", f"{path}: file not found")
        return None
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
    except yaml.YAMLError as e:
        mark = getattr(e, "problem_mark", None)
        where = f" (line {mark.line + 1}, column {mark.column + 1})" if mark else ""
        problem = getattr(e, "problem", None) or str(e).splitlines()[0]
        out("FAIL", f"{os.path.basename(path)}: invalid YAML{where}: {problem}")
        return None
    if not isinstance(data, dict):
        out("FAIL", f"{os.path.basename(path)}: top level is not a mapping")
        return None
    out("PASS", f"{os.path.basename(path)}: valid YAML")
    return data

def get(d, *keys):
    for k in keys:
        if isinstance(d, dict) and k in d:
            d = d[k]
        elif isinstance(d, list) and isinstance(k, int) and len(d) > k:
            d = d[k]
        else:
            return None
    return d

def as_list(v):
    if v is None:
        return []
    return v if isinstance(v, list) else [v]

def parse_ip(s):
    try:
        return ipaddress.ip_address(str(s))
    except ValueError:
        return None

ic = load(ic_path)
ac = load(ac_path)

machine_nets = []
cluster_name = None
api_vips, ingress_vips = [], []

# ---------------------------------------------------------- install-config
if ic is not None:
    required = [("apiVersion",), ("baseDomain",), ("metadata", "name"), ("controlPlane",),
                ("compute",), ("networking",), ("platform",), ("pullSecret",), ("sshKey",)]
    missing = [".".join(k) for k in required if get(ic, *k) in (None, "")]
    if missing:
        out("FAIL", "install-config: missing required keys: " + ", ".join(missing))
    else:
        out("PASS", "install-config: required keys present")

    cluster_name = get(ic, "metadata", "name")
    base_domain = get(ic, "baseDomain")
    if cluster_name and base_domain:
        fact("CLUSTER", cluster_name)
        fact("BASE", base_domain)

    # Networks
    nets = {}
    for label, entries in (("clusterNetwork", get(ic, "networking", "clusterNetwork")),
                           ("machineNetwork", get(ic, "networking", "machineNetwork")),
                           ("serviceNetwork", get(ic, "networking", "serviceNetwork"))):
        for e in as_list(entries):
            cidr = e.get("cidr") if isinstance(e, dict) else e
            try:
                n = ipaddress.ip_network(str(cidr), strict=True)
                nets.setdefault(label, []).append(n)
            except ValueError as err:
                out("FAIL", f"install-config: networking.{label} invalid CIDR '{cidr}': {err}")
    machine_nets = nets.get("machineNetwork", [])
    if not machine_nets:
        out("FAIL", "install-config: networking.machineNetwork missing")
    flat = [(l, n) for l, ns in nets.items() for n in ns]
    overlap = False
    for i in range(len(flat)):
        for j in range(i + 1, len(flat)):
            (l1, n1), (l2, n2) = flat[i], flat[j]
            if n1.version == n2.version and n1.overlaps(n2):
                overlap = True
                out("FAIL", f"install-config: {l1} {n1} overlaps {l2} {n2}")
    if flat and not overlap:
        out("PASS", "install-config: network CIDRs valid and non-overlapping (" +
            ", ".join(f"{l}={n}" for l, n in flat) + ")")

    # VIPs
    platform = get(ic, "platform") or {}
    pname = next(iter(platform), None) if isinstance(platform, dict) else None
    p = platform.get(pname) if pname else None
    if pname in ("baremetal", "vsphere", "nutanix") and isinstance(p, dict):
        api_vips = as_list(p.get("apiVIPs") or p.get("apiVIP"))
        ingress_vips = as_list(p.get("ingressVIPs") or p.get("ingressVIP"))
        for label, vips in (("apiVIPs", api_vips), ("ingressVIPs", ingress_vips)):
            if not vips:
                out("FAIL", f"install-config: platform.{pname}.{label} missing")
            for v in vips:
                ip = parse_ip(v)
                if ip is None:
                    out("FAIL", f"install-config: {label} '{v}' is not an IP address")
                elif machine_nets and not any(ip in n for n in machine_nets):
                    out("FAIL", f"install-config: {label} {ip} not inside machineNetwork")
                else:
                    out("PASS", f"install-config: {label} {ip} inside machineNetwork")
        if set(map(str, api_vips)) & set(map(str, ingress_vips)):
            out("FAIL", "install-config: apiVIPs and ingressVIPs must differ")
        for v in api_vips:
            fact("API_VIP", v)
        for v in ingress_vips:
            fact("INGRESS_VIP", v)
    elif pname == "none":
        out("WARN", "install-config: platform 'none' - api/ingress records must point to your load balancer (VIP checks skipped)")
    else:
        out("WARN", f"install-config: platform '{pname}' - VIP checks skipped")

    # Pull secret
    auths = {}
    ps = get(ic, "pullSecret")
    if ps:
        try:
            psj = json.loads(ps)
            auths = psj.get("auths") or {}
            if not auths:
                out("FAIL", "install-config: pullSecret has no 'auths' entries")
            else:
                out("PASS", f"install-config: pullSecret is valid JSON ({len(auths)} registries: {', '.join(auths)})")
        except (ValueError, AttributeError) as e:
            out("FAIL", f"install-config: pullSecret is not valid JSON: {e}")

    # sshKey
    ssh = get(ic, "sshKey")
    if ssh and not re.match(r"^\s*(ssh-(rsa|ed25519|dss)|ecdsa-sha2-\S+|sk-\S+)\s+\S+", str(ssh)):
        out("WARN", "install-config: sshKey does not look like an OpenSSH public key")

    # additionalTrustBundle
    atb = get(ic, "additionalTrustBundle")
    if atb:
        pems = re.findall(r"-----BEGIN CERTIFICATE-----\s+.*?-----END CERTIFICATE-----", str(atb), re.S)
        if not pems:
            out("FAIL", "install-config: additionalTrustBundle contains no PEM certificate")
        else:
            with open(os.path.join(tmp, "ca.pem"), "w") as f:
                for i, pem in enumerate(pems):
                    # Normalise indentation inside the PEM body.
                    lines = [l.strip() for l in pem.splitlines() if l.strip()]
                    body = "\n".join(lines) + "\n"
                    f.write(body)
                    cert_file = os.path.join(tmp, f"cert-{i}.pem")
                    with open(cert_file, "w") as cf:
                        cf.write(body)
                    fact("CERT", cert_file)
            fact("CA_BUNDLE", os.path.join(tmp, "ca.pem"))
    policy = get(ic, "additionalTrustBundlePolicy")
    if policy and policy not in ("Proxyonly", "Always"):
        out("FAIL", f"install-config: additionalTrustBundlePolicy '{policy}' must be Proxyonly or Always")

    # imageDigestSources / imageContentSources
    ids = get(ic, "imageDigestSources")
    if ids is None and get(ic, "imageContentSources") is not None:
        ids = get(ic, "imageContentSources")
        out("WARN", "install-config: imageContentSources is deprecated, use imageDigestSources")
    seen = {}
    for idx, entry in enumerate(as_list(ids)):
        if not isinstance(entry, dict) or not entry.get("source") or not entry.get("mirrors"):
            out("FAIL", f"install-config: imageDigestSources[{idx}] needs 'source' and 'mirrors'")
            continue
        for m in as_list(entry.get("mirrors")):
            m = str(m)
            if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*://", m):
                out("FAIL", f"install-config: mirror '{m}' must not include a scheme (use host[:port]/path)")
                m = re.sub(r"^[a-zA-Z][a-zA-Z0-9+.-]*://", "", m)
            m = m.rstrip("/")
            hostport, _, path = m.partition("/")
            # Credentials for this mirror: exact host[:port] or longest matching prefix.
            cred = auths.get(hostport)
            if cred is None:
                for k in sorted(auths, key=len, reverse=True):
                    if m == k or m.startswith(k.rstrip("/") + "/"):
                        cred = auths[k]
                        break
            if hostport not in seen:
                authfile = "-"
                if isinstance(cred, dict) and cred.get("auth"):
                    try:
                        userpass = base64.b64decode(cred["auth"]).decode()
                        authfile = os.path.join(tmp, f"auth-{len(seen)}")
                        fd = os.open(authfile, os.O_WRONLY | os.O_CREAT, 0o600)
                        with os.fdopen(fd, "w") as af:
                            af.write(userpass)
                    except Exception:
                        out("FAIL", f"install-config: pullSecret auth for '{hostport}' is not valid base64 user:password")
                elif cred is None:
                    out("WARN", f"install-config: no pullSecret entry for mirror host '{hostport}'")
                seen[hostport] = authfile
            fact("MIRROR", f"{hostport} {path or '-'} {seen[hostport]}")
    if ids:
        out("PASS", f"install-config: {len(as_list(ids))} imageDigestSources entries parsed")

# ---------------------------------------------------------- agent-config
if ac is not None:
    if ac.get("apiVersion") != "v1alpha1":
        out("FAIL", f"agent-config: apiVersion is '{ac.get('apiVersion')}', expected v1alpha1")
    if ac.get("kind") != "AgentConfig":
        out("FAIL", f"agent-config: kind is '{ac.get('kind')}', expected AgentConfig")
    if ac.get("apiVersion") == "v1alpha1" and ac.get("kind") == "AgentConfig":
        out("PASS", "agent-config: apiVersion/kind ok")
    ac_name = get(ac, "metadata", "name")
    if not ac_name:
        out("WARN", "agent-config: metadata.name missing (should match install-config metadata.name)")
    elif cluster_name and ac_name != cluster_name:
        out("FAIL", f"agent-config: metadata.name '{ac_name}' differs from install-config '{cluster_name}'")

    hosts = as_list(ac.get("hosts"))
    names, macs, ips, roles = [], [], [], []
    for i, h in enumerate(hosts):
        if not isinstance(h, dict):
            out("FAIL", f"agent-config: hosts[{i}] is not a mapping"); continue
        hn = h.get("hostname") or f"hosts[{i}]"
        names.append(hn)
        roles.append(h.get("role"))
        if h.get("role") not in ("master", "worker", None):
            out("FAIL", f"agent-config: {hn} role '{h.get('role')}' must be master or worker")
        iface_names = set()
        for itf in as_list(h.get("interfaces")):
            iface_names.add(itf.get("name"))
            mac = str(itf.get("macAddress", "")).strip().lower()
            if not re.match(r"^([0-9a-f]{2}:){5}[0-9a-f]{2}$", mac):
                out("FAIL", f"agent-config: {hn} interface {itf.get('name')} invalid macAddress '{mac}'")
            macs.append(mac)
        if not iface_names:
            out("FAIL", f"agent-config: {hn} has no 'interfaces' (name/macAddress) list")
        host_ips = []
        for nif in as_list(get(h, "networkConfig", "interfaces")):
            for port in as_list(get(nif, "link-aggregation", "port")):
                if port not in iface_names:
                    out("FAIL", f"agent-config: {hn} bond {nif.get('name')} port '{port}' not in host interfaces")
            for addr in as_list(get(nif, "ipv4", "address")):
                ip = parse_ip(addr.get("ip"))
                if ip is None:
                    out("FAIL", f"agent-config: {hn} invalid ip '{addr.get('ip')}'")
                    continue
                host_ips.append(ip)
                if machine_nets and not any(ip in n for n in machine_nets):
                    out("FAIL", f"agent-config: {hn} ip {ip} not inside machineNetwork")
        for r in as_list(get(h, "networkConfig", "routes", "config")):
            gw = parse_ip(r.get("next-hop-address"))
            if gw and machine_nets and not any(gw in n for n in machine_nets):
                out("WARN", f"agent-config: {hn} gateway {gw} not inside machineNetwork")
        for s in as_list(get(h, "networkConfig", "dns-resolver", "config", "server")):
            fact("DNS_SERVER", s)
        ips.extend(host_ips)
        fact("HOST", f"{hn} {host_ips[0] if host_ips else '-'}")

    for label, values in (("hostnames", names), ("MAC addresses", macs), ("IPs", [str(i) for i in ips])):
        dups = sorted({v for v in values if values.count(v) > 1})
        if dups:
            out("FAIL", f"agent-config: duplicate {label}: {', '.join(dups)}")
        elif values:
            out("PASS", f"agent-config: {len(values)} {label} unique")

    for vip in api_vips + ingress_vips:
        if str(vip) in map(str, ips):
            out("FAIL", f"agent-config: VIP {vip} is also assigned to a host")

    ntp = ac.get("additionalNTPSources")
    if ntp is not None:
        if not isinstance(ntp, list):
            out("FAIL", "agent-config: additionalNTPSources must be a list")
            ntp = []
        elif not ntp:
            out("WARN", "agent-config: additionalNTPSources is empty")
        valid = []
        for src in ntp:
            src = str(src).strip()
            if parse_ip(src) is None and not re.match(r"^(?=.{1,253}$)([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$", src):
                out("FAIL", f"agent-config: additionalNTPSources entry '{src}' is not an IP address or hostname")
                continue
            valid.append(src)
        dups = sorted({v for v in valid if valid.count(v) > 1})
        if dups:
            out("WARN", f"agent-config: duplicate additionalNTPSources: {', '.join(dups)}")
        elif valid:
            out("PASS", f"agent-config: {len(valid)} additionalNTPSources valid ({', '.join(valid)})")
        for src in dict.fromkeys(valid):
            fact("NTP_SOURCE", src)

    rip = parse_ip(ac.get("rendezvousIP"))
    if rip is None:
        out("FAIL", f"agent-config: rendezvousIP '{ac.get('rendezvousIP')}' missing or invalid")
    elif rip not in ips:
        out("FAIL", f"agent-config: rendezvousIP {rip} does not match any host IP")
    else:
        out("PASS", f"agent-config: rendezvousIP {rip} matches a host")

    if ic is not None:
        want_m = get(ic, "controlPlane", "replicas")
        want_w = get(ic, "compute", 0, "replicas")
        got_m = sum(1 for r in roles if r == "master")
        got_w = sum(1 for r in roles if r == "worker")
        unset = sum(1 for r in roles if r is None)
        if unset:
            out("WARN", f"agent-config: {unset} hosts without role (assigned automatically)")
        elif want_m is not None and got_m != want_m:
            out("FAIL", f"agent-config: {got_m} masters defined, controlPlane.replicas is {want_m}")
        elif want_w is not None and got_w != want_w:
            out("FAIL", f"agent-config: {got_w} workers defined, compute.replicas is {want_w}")
        else:
            out("PASS", f"agent-config: host roles match replicas ({got_m} masters, {got_w} workers)")
PY
)

CLUSTER=""; BASE=""; CA_BUNDLE=""
API_VIPS=""; INGRESS_VIPS=""; HOSTS=""; DNS_SERVERS=""; MIRRORS=""; CERTS=""; NTP_SOURCES=""
while IFS= read -r line; do
  case "$line" in
    PASS\|*) pass "${line#PASS|}" ;;
    WARN\|*) warn "${line#WARN|}" ;;
    FAIL\|*) fail "${line#FAIL|}" ;;
    CLUSTER=*)     CLUSTER="${line#*=}" ;;
    BASE=*)        BASE="${line#*=}" ;;
    CA_BUNDLE=*)   CA_BUNDLE="${line#*=}" ;;
    API_VIP=*)     API_VIPS="${API_VIPS} ${line#*=}" ;;
    INGRESS_VIP=*) INGRESS_VIPS="${INGRESS_VIPS} ${line#*=}" ;;
    CERT=*)        CERTS="${CERTS} ${line#*=}" ;;
    NTP_SOURCE=*)  NTP_SOURCES="${NTP_SOURCES} ${line#*=}" ;;
    HOST=*)        HOSTS="${HOSTS}${line#*=}"$'\n' ;;
    MIRROR=*)      MIRRORS="${MIRRORS}${line#*=}"$'\n' ;;
    DNS_SERVER=*)  case " $DNS_SERVERS " in *" ${line#*=} "*) ;; *) DNS_SERVERS="${DNS_SERVERS} ${line#*=}" ;; esac ;;
    "") ;;
    *) info "$line" ;;
  esac
done <<EOF
$PY_OUT
EOF

# Certificate details from additionalTrustBundle
for cert in $CERTS; do
  if subj=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null | sed 's/^subject= *//'); then
    end=$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2-)
    if openssl x509 -in "$cert" -noout -checkend 0 >/dev/null 2>&1; then
      if openssl x509 -in "$cert" -noout -checkend $((30*86400)) >/dev/null 2>&1; then
        pass "additionalTrustBundle cert $subj (expires $end)"
      else
        warn "additionalTrustBundle cert $subj expires within 30 days ($end)"
      fi
    else
      fail "additionalTrustBundle cert $subj EXPIRED ($end)"
    fi
  else
    fail "additionalTrustBundle: openssl cannot parse certificate #$(basename "$cert" .pem | cut -d- -f2)"
  fi
done

# ---------------------------------------------------------------- DNS helpers
# resolve_a NAME [SERVER] -> IPv4 addresses, one per line
resolve_a() {
  if [ "$DNS_TOOL" = dig ]; then
    dig +short +time=3 +tries=1 A "$1" ${2:+@$2} 2>/dev/null | grep -E '^[0-9]+(\.[0-9]+){3}$'
  else
    nslookup "$1" ${2:+$2} 2>/dev/null | awk '/^Name:/{n=1;next} n && /^Address/{print $NF}' | grep -E '^[0-9]+(\.[0-9]+){3}$'
  fi
}
# resolve_ptr IP [SERVER] -> names, one per line
resolve_ptr() {
  if [ "$DNS_TOOL" = dig ]; then
    dig +short +time=3 +tries=1 -x "$1" ${2:+@$2} 2>/dev/null | grep -v '^;' | sed 's/\.$//'
  else
    nslookup "$1" ${2:+$2} 2>/dev/null | awk -F'name = ' '/name = /{print $2}' | sed 's/\.$//'
  fi
}
# check_a LEVEL NAME EXPECTED_IP SERVER
check_a() {
  local level="$1" name="$2" want="$3" srv="$4" got
  got=$(resolve_a "$name" "$srv" | tr '\n' ' ' | sed 's/ $//')
  if [ -z "$got" ]; then
    "$level" "$name -> no A record (server: ${srv:-system})"
  elif [ "$want" = "-" ]; then
    pass "$name -> $got (server: ${srv:-system})"
  elif echo " $got " | grep -q " $want "; then
    if [ "$got" = "$want" ]; then
      pass "$name -> $got (server: ${srv:-system})"
    else
      warn "$name -> $got, expected only $want (server: ${srv:-system})"
    fi
  else
    "$level" "$name -> $got, expected $want (server: ${srv:-system})"
  fi
}
# check_ptr LEVEL IP SERVER [EXPECTED_NAME]
check_ptr() {
  local level="$1" ip="$2" srv="$3" want="${4:-}" got
  got=$(resolve_ptr "$ip" "$srv" | tr '\n' ' ' | sed 's/ $//')
  if [ -z "$got" ]; then
    "$level" "PTR $ip -> no record (server: ${srv:-system})"
  elif [ -n "$want" ] && ! echo " $got " | grep -qi " $want "; then
    warn "PTR $ip -> $got, expected $want (server: ${srv:-system})"
  else
    pass "PTR $ip -> $got (server: ${srv:-system})"
  fi
}
is_ip() { echo "$1" | grep -Eq '^[0-9]+(\.[0-9]+){3}$'; }

# ---------------------------------------------------------------- 2) DNS
section "2) DNS"
if [ "$SKIP_DNS" -eq 1 ]; then
  warn "DNS checks skipped (--skip-dns)"
elif [ -z "$DNS_TOOL" ]; then
  fail "DNS checks skipped: no dig/nslookup"
elif [ -z "$CLUSTER" ] || [ -z "$BASE" ]; then
  fail "DNS checks skipped: cluster name / baseDomain not available from install-config"
else
  DOMAIN="${CLUSTER}.${BASE}"
  if [ -n "$DNS_OVERRIDE" ]; then
    SERVERS="$DNS_OVERRIDE"
  else
    SERVERS="$DNS_SERVERS"
    [ -n "$SERVERS" ] || warn "no dns-resolver servers in agent-config, using the system resolver only"
  fi
  # "" = system resolver of this machine
  for srv in $SERVERS ""; do
    echo "  -- resolver: ${srv:-system ($(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf 2>/dev/null))}"
    if [ -n "$srv" ] && [ "$DNS_TOOL" = dig ]; then
      if ! dig +time=3 +tries=1 "$BASE" SOA "@$srv" >/dev/null 2>&1; then
        fail "DNS server $srv not reachable"; continue
      fi
    fi
    api_vip=$(echo $API_VIPS | awk '{print $1}')
    ing_vip=$(echo $INGRESS_VIPS | awk '{print $1}')
    check_a fail "api.${DOMAIN}" "${api_vip:--}" "$srv"
    check_a fail "api-int.${DOMAIN}" "${api_vip:--}" "$srv"
    rand="validate-$$-$RANDOM"
    check_a fail "${rand}.apps.${DOMAIN}" "${ing_vip:--}" "$srv"
    check_a fail "console-openshift-console.apps.${DOMAIN}" "${ing_vip:--}" "$srv"
    check_a fail "oauth-openshift.apps.${DOMAIN}" "${ing_vip:--}" "$srv"
    for vip in $API_VIPS; do check_ptr warn "$vip" "$srv" "api.${DOMAIN}"; done
    while read -r hn ip; do
      [ -n "$hn" ] || continue
      [ "$ip" = "-" ] && { warn "$hn: no static IP in agent-config, skipping"; continue; }
      check_a warn "${hn}.${DOMAIN}" "$ip" "$srv"
      check_ptr warn "$ip" "$srv" "${hn}.${DOMAIN}"
    done <<EOF
$HOSTS
EOF
    while read -r hostport _path _auth; do
      [ -n "$hostport" ] || continue
      mhost="${hostport%%:*}"
      is_ip "$mhost" || check_a fail "$mhost" "-" "$srv"
    done <<EOF
$(echo "$MIRRORS" | awk 'NF && !seen[$1]++')
EOF
    if [ "$SKIP_NTP" -eq 0 ]; then
      for src in $NTP_SOURCES; do
        is_ip "$src" || check_a fail "$src" "-" "$srv"
      done
    fi
  done
fi

# reg_get URL AUTHFILE [SCOPE] -> prints "<http code>|<note>"
# Authenticates like a container client: Basic auth, then the Bearer token
# challenge (WWW-Authenticate) when the registry asks for it (Quay, Harbor, Nexus...).
reg_get() {
  python3 - "$1" "$CA_BUNDLE" "$2" "${3:-}" <<'PY' 2>&1
import base64, json, re, ssl, sys, urllib.error, urllib.parse, urllib.request
url, ca, authfile, scope = sys.argv[1:5]
ctx = ssl.create_default_context(cafile=ca)
basic = None
if authfile != "-":
    with open(authfile) as f:
        basic = "Basic " + base64.b64encode(f.read().strip().encode()).decode()

def get(u, auth=None):
    req = urllib.request.Request(u, headers={"Authorization": auth} if auth else {})
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=15) as r:
            return r.status, r.headers, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e.read()

try:
    code, hdrs, _ = get(url, basic)
    chal = hdrs.get("WWW-Authenticate", "") if code == 401 else ""
    if chal.lower().startswith("bearer"):
        params = dict(re.findall(r'(\w+)="([^"]*)"', chal))
        q = {"service": params.get("service", "")}
        if scope:
            q["scope"] = scope
        tcode, _, body = get(params["realm"] + "?" + urllib.parse.urlencode(q), basic)
        if tcode != 200:
            print(f"{tcode}|token endpoint rejected credentials"); sys.exit()
        tok = json.loads(body)
        tok = tok.get("token") or tok.get("access_token")
        code, _, _ = get(url, "Bearer " + tok)
        print(f"{code}|bearer token")
    else:
        print(f"{code}|basic auth" if basic else f"{code}|anonymous")
except Exception as e:
    print(f"000|{e}")
PY
}

# ---------------------------------------------------------------- 3) registry
section "3) Mirror registry"
if [ "$SKIP_REGISTRY" -eq 1 ]; then
  warn "registry checks skipped (--skip-registry)"
elif [ -z "$MIRRORS" ]; then
  info "no imageDigestSources defined, skipping"
elif [ -z "$CA_BUNDLE" ]; then
  warn "imageDigestSources defined but no additionalTrustBundle; registry checks skipped"
else
  UNREACHABLE=""
  while read -r hostport path authfile; do
    [ -n "$hostport" ] || continue
    host="${hostport%%:*}"
    port=443
    case "$hostport" in *:*) port="${hostport##*:}" ;; esac
    echo "  -- ${host}:${port}"

    # TLS: chain + hostname/IP verification against the bundle (python ssl has timeouts and SAN checks).
    tls=$(python3 - "$host" "$port" "$CA_BUNDLE" <<'PY' 2>&1
import socket, ssl, sys
host, port, ca = sys.argv[1], int(sys.argv[2]), sys.argv[3]
ctx = ssl.create_default_context(cafile=ca)
try:
    sock = socket.create_connection((host, port), timeout=8)
except OSError as e:
    print(f"UNREACHABLE|{e}"); sys.exit()
try:
    with ctx.wrap_socket(sock, server_hostname=host) as s:
        print(f"OK|{s.version()}")
except ssl.SSLCertVerificationError as e:
    print(f"VERIFY|{e.verify_message}")
except (ssl.SSLError, OSError) as e:
    print(f"ERROR|{e}")
PY
)
    case "$tls" in
      UNREACHABLE\|*) fail "cannot connect to ${host}:${port}: ${tls#*|}"; UNREACHABLE="${UNREACHABLE} ${hostport}"; continue ;;
      OK\|*)          pass "TLS verified with additionalTrustBundle, hostname/IP matches certificate (${tls#*|})" ;;
      VERIFY\|*)      fail "TLS verification failed: ${tls#*|}" ;;
      *)              fail "TLS error: ${tls#*|}" ;;
    esac

    # Same check as `openssl s_client ... | grep 'Verify return code'` (chain only, no hostname check)
    sni=""; is_ip "$host" || sni="-servername $host"
    s_out=$(openssl s_client -connect "${host}:${port}" $sni -CAfile "$CA_BUNDLE" -showcerts </dev/null 2>&1)
    vrc=$(echo "$s_out" | grep 'Verify return code' | tail -1 | sed 's/^ *//')
    case "$vrc" in
      *"code: 0 "*) pass "openssl chain: $vrc" ;;
      "")           fail "openssl s_client: no handshake" ;;
      *)            fail "openssl chain: $vrc" ;;
    esac
    echo "$s_out" | awk '/-----BEGIN CERTIFICATE-----/{p=1} p{print} /-----END CERTIFICATE-----/{exit}' > "$TMP/server.pem"
    if [ -s "$TMP/server.pem" ]; then
      info "server cert $(openssl x509 -in "$TMP/server.pem" -noout -subject 2>/dev/null)"
      san=$(openssl x509 -in "$TMP/server.pem" -noout -text 2>/dev/null | grep -A1 'Subject Alternative Name' | tail -1 | sed 's/^ *//')
      info "SAN: ${san:-<none>}"
      info "expires: $(openssl x509 -in "$TMP/server.pem" -noout -enddate 2>/dev/null | cut -d= -f2-)"
    fi

    # Registry API
    base_url="https://${host}:${port}"
    code=$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 8 --max-time 20 --cacert "$CA_BUNDLE" "${base_url}/v2/" 2>"$TMP/curl.err")
    if [ "$code" = 200 ] || [ "$code" = 401 ]; then
      pass "GET ${base_url}/v2/ -> HTTP $code (curl --cacert)"
    else
      fail "GET ${base_url}/v2/ -> HTTP $code $(head -1 "$TMP/curl.err")"
    fi

    if [ "$authfile" != "-" ]; then
      res=$(reg_get "${base_url}/v2/" "$authfile")
      if [ "${res%%|*}" = 200 ]; then
        pass "authenticated GET /v2/ with pullSecret credentials -> HTTP 200 (${res#*|})"
      else
        fail "authenticated GET /v2/ with pullSecret credentials -> HTTP ${res%%|*} (${res#*|})"
      fi
    fi
  done <<EOF
$(echo "$MIRRORS" | awk 'NF && !seen[$1]++')
EOF

  # Repository existence, per mirror path (informational)
  while read -r hostport path authfile; do
    [ -n "$hostport" ] && [ "$path" != "-" ] || continue
    case " $UNREACHABLE " in *" $hostport "*) continue ;; esac
    case "$hostport" in *:*) url="https://${hostport}" ;; *) url="https://${hostport}:443" ;; esac
    res=$(reg_get "${url}/v2/${path}/tags/list" "$authfile" "repository:${path}:pull")
    code="${res%%|*}"
    if [ "$code" = 200 ]; then
      pass "repository ${hostport}/${path} exists (tags/list -> 200)"
    else
      warn "repository ${hostport}/${path}: tags/list -> HTTP $code (${res#*|})"
    fi
  done <<EOF
$MIRRORS
EOF
fi

# ntp_query SERVER -> prints "OK|<stratum>|<offset s>", "UNSYNC|<detail>", "NOREPLY|<detail>" or "ERROR|<detail>"
# Single SNTP (RFC 4330) client request over UDP/123.
ntp_query() {
  python3 - "$1" <<'PY' 2>&1
import socket, struct, sys, time
host = sys.argv[1]
NTP_EPOCH = 2208988800

def ts(b):
    sec, frac = struct.unpack("!II", b)
    return sec - NTP_EPOCH + frac / 2**32

try:
    family, _, _, _, addr = socket.getaddrinfo(host, 123, 0, socket.SOCK_DGRAM)[0]
except socket.gaierror as e:
    print(f"ERROR|cannot resolve: {e}"); sys.exit()
sock = socket.socket(family, socket.SOCK_DGRAM)
sock.settimeout(3)
try:
    t0 = time.time()
    sock.sendto(b"\x23" + 47 * b"\0", addr)  # LI=0, VN=4, Mode=3 (client)
    data, _ = sock.recvfrom(512)
    t3 = time.time()
except OSError as e:
    print(f"NOREPLY|{e}"); sys.exit()
if len(data) < 48:
    print("ERROR|short reply"); sys.exit()
li, stratum = data[0] >> 6, data[1]
if stratum == 0:
    print(f"UNSYNC|kiss-of-death {data[12:16].decode(errors='replace')}")
elif li == 3 or stratum >= 16:
    print(f"UNSYNC|server reports unsynchronized clock (stratum {stratum})")
else:
    offset = ((ts(data[32:40]) - t0) + (ts(data[40:48]) - t3)) / 2
    print(f"OK|{stratum}|{offset:+.3f}")
PY
}

# ---------------------------------------------------------------- 4) NTP
section "4) NTP"
if [ "$SKIP_NTP" -eq 1 ]; then
  warn "NTP checks skipped (--skip-ntp)"
elif [ -z "$NTP_SOURCES" ]; then
  info "no additionalNTPSources defined, skipping"
else
  # Queried from this machine: nodes on another network segment may still reach a server that fails here.
  for src in $NTP_SOURCES; do
    res=$(ntp_query "$src")
    case "$res" in
      OK\|*)
        stratum=$(echo "$res" | cut -d'|' -f2); offset=$(echo "$res" | cut -d'|' -f3)
        pass "$src: NTP reply, stratum $stratum, offset ${offset}s vs this host" ;;
      NOREPLY\|*) warn "$src: no NTP reply on UDP/123 from this host (${res#*|})" ;;
      UNSYNC\|*)  warn "$src: ${res#*|}" ;;
      *)          warn "$src: NTP query failed (${res#*|})" ;;
    esac
  done
fi

# ---------------------------------------------------------------- summary
section "Summary"
echo "  ${C_GRN}${N_PASS} passed${C_OFF}, ${C_YEL}${N_WARN} warnings${C_OFF}, ${C_RED}${N_FAIL} failed${C_OFF}"
[ "$N_FAIL" -eq 0 ]
