#
# Workaround.
# NOTE: Replace NIC1_CON_NAME and NIC2_CON_NAME variables to NIC correct names in your environment.
#
#!/bin/bash
set -eux -o pipefail

# for syslog
echo "$0" "$@"

INTERFACE_NAME=$1
OPERATION=$2
NIC1_CON_NAME='eno1'
NIC2_CON_NAME='eno2'

# Only execute on pre-up
if [[ "${OPERATION}" != "pre-up" ]]; then
	exit 0
fi

# ignore everything except the bond
if [[ "${INTERFACE_NAME}" != "ovs-bond"  ]]; then
	exit 0
fi

nmcli connection modify $NIC1_CON_NAME connection.autoconnect-retries 0
nmcli conn up $NIC1_CON_NAME &
nmcli connection modify "$NIC2_CON_NAME" connection.autoconnect-retries 0
nmcli conn up $NIC2_CON_NAME &
