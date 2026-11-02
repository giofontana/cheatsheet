# Enable multipath on OpenShift nodes

Device Mapper Multipath (DM Multipath) combines the I/O paths to a storage
LUN into one device. If a path fails (a cable, HBA, switch or storage
controller), I/O keeps going on the remaining paths. Shared block storage
over iSCSI or Fibre Channel should go through multipath. That includes LUNs
used by CSI drivers and OpenShift Virtualization.

`enable-multipath.sh` turns on multipath for the nodes in one
MachineConfigPool by creating a MachineConfig.

## Why a MachineConfig

OpenShift nodes run Red Hat Enterprise Linux CoreOS (RHCOS). Do not configure
RHCOS by hand with `oc debug node` or `ssh`:

- The Machine Config Operator (MCO) owns the node's configuration. It builds
  it from the `MachineConfig` objects in the cluster.
- A file you change by hand isn't in any MachineConfig. A new node won't
  get it, and it can be lost on an upgrade or overwritten by the MCO.
- If a file the MCO manages no longer matches what the MCO expects, the MCO
  sets the node to `Degraded` and stops updating it.

A MachineConfig puts the change in the cluster API. Every node in the pool
gets it, nodes added later get it, and it stays in place across upgrades.

## What the script creates

The script creates one MachineConfig named `99-<ROLE>-multipath`. The
`machineconfiguration.openshift.io/role: <ROLE>` label assigns it to that
pool:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-worker-multipath
spec:
  config:
    ignition:
      version: 3.5.0
    storage:
      files:
      - path: /etc/multipath.conf
        mode: 420            # 0644
        overwrite: true
        contents:
          source: data:text/plain;charset=utf-8;base64,<multipath.conf>
    systemd:
      units:
      - name: iscsid.service
        enabled: true
      - name: multipathd.service
        enabled: true
```

- **The `99-` prefix:** The MCO merges every MachineConfig for a pool into
  one `rendered-<pool>-<hash>` config, in name order. A later config wins
  when two set the same thing. With `99-`, this config is applied after the
  `00-`/`01-` configs that OpenShift ships.
- **`/etc/multipath.conf`:** Ignition files are inline and
  base64-encoded. The `mode` value is decimal (`420` = `0644`).
- **`iscsid.service`:** The iSCSI initiator daemon. It's needed for iSCSI
  LUNs. On Fibre Channel-only nodes it does nothing.
- **`multipathd.service`:** The daemon that builds the multipath devices and
  watches their paths.

### multipath.conf

```
defaults {
    user_friendly_names no
    find_multipaths yes
    enable_foreign "^$"
}
blacklist {
}
```

- **`user_friendly_names no`:** Names devices by WWID
  (`/dev/mapper/3600a0980...`), not by `mpatha`, `mpathb` and so on. Each
  node picks the `mpathN` names in its own order, so one LUN can get a
  different name on each node. CSI drivers and workloads that move between
  nodes need the WWID name.
- **`find_multipaths yes`:** Builds a multipath device only for a disk that
  has more than one path, or whose WWID is already known. Local
  single-path disks, including the RHCOS boot disk, stay as they are.
- **`enable_foreign "^$"`:** Turns off the foreign multipath libraries,
  such as native NVMe multipath, so `multipath -ll` shows only DM Multipath
  devices.
- **`blacklist {}`:** Empty. With `find_multipaths yes`, you usually don't
  need to blacklist local disks.

This is a generic starting point. Most storage vendors publish their own
settings, such as a `devices {}` section or a different `find_multipaths`
value, and some CSI drivers require them. Check your array's and CSI
driver's documentation, and edit `MULTIPATH_CONF` in the script before you
run it.

## Run the script

You need `oc`, logged in as a user who can create MachineConfigs
(`cluster-admin`).

```sh
./enable-multipath.sh            # prompts for the pool (default: worker)
./enable-multipath.sh master     # uses master as the default answer
```

The script:

1. Shows the cluster you're logged in to (API server, user, context,
   version) and asks you to confirm it.
2. Lists the MachineConfigPools and asks which one to configure.
3. Warns you if `99-<ROLE>-multipath` already exists. Running the script
   again updates that MachineConfig.
4. Prints the MachineConfig and `multipath.conf`, then asks once more before
   it runs `oc apply`.

### Which pool to choose

- **Standard cluster:** `worker`. Add `master` only if the control plane
  nodes use the SAN too.
- **Compact (3-node) cluster and single-node OpenShift:** `master`. These
  nodes run workloads, but they're in the `master` pool, and a config for
  `worker` doesn't reach them.
- **Custom pools (such as `infra` or `storage`):** Custom pools inherit
  the `worker` MachineConfigs. A config for `worker` therefore also reaches
  those nodes. A config for a custom pool reaches only that pool.

## Rollout: nodes reboot

After you apply the MachineConfig, the MCO renders a new config for the pool
and updates the nodes one at a time (the pool's `maxUnavailable` sets how
many). For each node, the MCO:

1. Cordons the node and drains its pods. A PodDisruptionBudget can hold up
   the drain.
2. Writes `/etc/multipath.conf` and enables the services.
3. Reboots the node.
4. Uncordons the node and moves on to the next one.

Plan for a maintenance window. Watch the rollout:

```sh
oc get mcp <ROLE> -w     # UPDATED=True, UPDATING=False when finished
oc get nodes -w
```

To apply several MachineConfigs with one reboot per node, pause the pool
first and unpause it after the last one:

```sh
oc patch mcp <ROLE> --type merge -p '{"spec":{"paused":true}}'
# apply the MachineConfigs
oc patch mcp <ROLE> --type merge -p '{"spec":{"paused":false}}'
```

Don't leave a pool paused. A paused pool also holds back certificate
rotation and cluster upgrades.

## Verify

```sh
oc get mc 99-<ROLE>-multipath
oc get mcp <ROLE>

# On one node of the pool:
oc debug node/<node> -- chroot /host bash -c '
  cat /etc/multipath.conf
  systemctl is-active multipathd iscsid
  multipath -ll
'
```

`multipath -ll` lists one device per LUN, with every path `active ready`.
It's empty until LUNs are presented to the node, for example after a CSI
driver logs in to an iSCSI target.

## Troubleshooting

If the pool shows `DEGRADED=True` or doesn't progress:

```sh
oc describe mcp <ROLE>        # see Conditions for the reason
oc get nodes -o custom-columns='NAME:.metadata.name,STATE:.metadata.annotations.machineconfiguration\.openshift\.io/state,REASON:.metadata.annotations.machineconfiguration\.openshift\.io/reason'
oc -n openshift-machine-config-operator logs -l k8s-app=machine-config-daemon -c machine-config-daemon --field-selector spec.nodeName=<node>
```

Common causes:

- **A drain that doesn't finish:** Usually a PodDisruptionBudget or a pod
  that can't be evicted.
- **An unsupported Ignition version:** The MachineConfig uses Ignition spec
  `3.5.0`. If your OpenShift release doesn't accept it, lower
  `ignition.version` in the script (`3.2.0` works on all current releases).
- **A file the MCO no longer recognizes:** Someone changed
  `/etc/multipath.conf` on the node by hand. Change it in the MachineConfig
  instead.

## Roll back

```sh
oc delete mc 99-<ROLE>-multipath
```

The MCO renders the pool's config again without this MachineConfig and
reboots the nodes one at a time again. Before you remove multipath, move
any workload that uses multipath devices off those nodes.

## Not covered: multipath on the boot disk

This script is for data LUNs. Multipath for the RHCOS root disk, as when you
boot from SAN, is set up another way. It uses kernel arguments
(`rd.multipath=default`, `root=/dev/disk/by-label/dm-mpath-root`), which you
set when you install the cluster or through a MachineConfig's
`kernelArguments`. See the OpenShift documentation: "Enabling multipathing
with kernel arguments on RHCOS".
