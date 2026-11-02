#!/bin/bash
# This script enables multipath on OpenShift nodes by creating a MachineConfig that configures the multipath daemon and related services.

set -euo pipefail

usage() {
    echo "Usage: $0 [ROLE] [-y]"
    echo "  [ROLE] - Optional. The role of the nodes to which the multipath configuration will be applied (e.g., worker, master)."
    echo "           If omitted, you will be prompted for it."
    echo "  -y     - Optional. Answer yes to all prompts and use ROLE (default: worker) without asking."
}

ASSUME_YES=false
ROLE_ARG=""
for arg in "$@"; do
    case "$arg" in
        -h|--help) usage; exit 0 ;;
        -y|--yes) ASSUME_YES=true ;;
        -*) echo "Error: unknown option '${arg}'."; usage; exit 1 ;;
        *) ROLE_ARG="$arg" ;;
    esac
done

# Prompt for an answer, or print the prompt with the -y answer and use that
ask() {
    local prompt=$1 var=$2 yes_answer=$3
    if [ "$ASSUME_YES" = true ]; then
        echo "${prompt}${yes_answer}"
        printf -v "$var" '%s' "$yes_answer"
    else
        read -r -p "$prompt" "$var"
    fi
}

# multipath.conf is read from the same folder as this script
MULTIPATH_CONF_FILE="$(cd "$(dirname "$0")" && pwd)/multipath.conf"
if [ ! -f "$MULTIPATH_CONF_FILE" ]; then
    echo "Error: ${MULTIPATH_CONF_FILE} not found."
    exit 1
fi

cat << 'EOF'
==============================================================================
 Enable multipath on OpenShift nodes
==============================================================================
This script creates a MachineConfig named 99-<ROLE>-multipath that:
  - writes /etc/multipath.conf from the multipath.conf next to this script
  - enables the iscsid and multipathd systemd services

The MachineConfig is applied to every node in the selected MachineConfigPool.
The Machine Config Operator will roll it out one node at a time, and each
node will be drained and rebooted.
==============================================================================

EOF

# Check that oc is installed and logged in to a cluster
if ! command -v oc > /dev/null 2>&1; then
    echo "Error: 'oc' command not found. Install the OpenShift CLI first."
    exit 1
fi

if ! oc whoami > /dev/null 2>&1; then
    echo "Error: 'oc' is not connected to a cluster. Run 'oc login' first."
    exit 1
fi

# Show which cluster we are connected to
echo "Connected cluster:"
echo "  API server: $(oc whoami --show-server)"
echo "  User:       $(oc whoami)"
echo "  Context:    $(oc config current-context)"
CLUSTER_VERSION=$(oc get clusterversion version -o jsonpath='{.status.desired.version}' 2>/dev/null || true)
[ -n "$CLUSTER_VERSION" ] && echo "  Version:    ${CLUSTER_VERSION}"
echo

ask "Is this the correct cluster? [y/N]: " CLUSTER_OK y
if [[ ! "$CLUSTER_OK" =~ ^[Yy]$ ]]; then
    echo "Aborted. Switch to the correct cluster and run the script again."
    exit 1
fi
echo

# Ask for the ROLE (use the first argument as default, if provided)
echo "Available MachineConfigPools:"
oc get mcp -o custom-columns='NAME:.metadata.name,MACHINECOUNT:.status.machineCount' --no-headers | sed 's/^/  /'
echo

DEFAULT_ROLE=${ROLE_ARG:-worker}
ask "Which ROLE should the multipath configuration be applied to? [${DEFAULT_ROLE}]: " ROLE "$DEFAULT_ROLE"
ROLE=${ROLE:-$DEFAULT_ROLE}

if ! oc get mcp "$ROLE" > /dev/null 2>&1; then
    echo "Error: MachineConfigPool '${ROLE}' does not exist on this cluster."
    exit 1
fi

MC_NAME="99-${ROLE}-multipath"
if oc get machineconfig "$MC_NAME" > /dev/null 2>&1; then
    echo "Warning: MachineConfig '${MC_NAME}' already exists and will be updated."
fi

MULTIPATH_CONF=$(cat "$MULTIPATH_CONF_FILE")
# 'tr -d' instead of 'base64 -w0' so it works with both GNU and macOS base64
MULTIPATH_CONF_B64=$(printf '%s\n' "$MULTIPATH_CONF" | base64 | tr -d '\n')

MACHINE_CONFIG=$(cat << EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: ${ROLE}
  name: ${MC_NAME}
spec:
  config:
    ignition:
      version: 3.5.0
    storage:
      files:
      - path: /etc/multipath.conf
        mode: 420
        overwrite: true
        contents:
          source: data:text/plain;charset=utf-8;base64,${MULTIPATH_CONF_B64}
    systemd:
      units:
      - name: iscsid.service
        enabled: true
      - name: multipathd.service
        enabled: true
EOF
)

echo
echo "The following MachineConfig will be applied to $(oc whoami --show-server):"
echo "------------------------------------------------------------------------------"
echo "$MACHINE_CONFIG"
echo "------------------------------------------------------------------------------"
echo "Contents of /etc/multipath.conf:"
echo "$MULTIPATH_CONF"
echo "------------------------------------------------------------------------------"
echo

ask "Apply this MachineConfig to the '${ROLE}' pool? Nodes will reboot. [y/N]: " APPLY_OK y
if [[ ! "$APPLY_OK" =~ ^[Yy]$ ]]; then
    echo "Aborted. Nothing was applied."
    exit 0
fi

echo "$MACHINE_CONFIG" | oc apply -f -

echo
echo "Done. Monitor the rollout with:"
echo "  oc get mcp ${ROLE} -w"
