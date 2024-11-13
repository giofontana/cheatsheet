

1. Enable rook-ceph toolbox

```bash
oc patch OCSInitialization ocsinit -n openshift-storage --type json --patch  '[{ "op": "replace", "path": "/spec/enableCephTools", "value": true }]'
```

2. SSH into the pod:

```bash
oc -n openshift-storage rsh $(oc get pods -n openshift-storage -l app=rook-ceph-tools -o name)
```

3. Troubleshooting util commands:

```bash
ceph -s

# to solve issue "N pgs not deep-scrubbed in time"
ceph config set global osd_deep_scrub_interval 3628800
```

4. Fixing pg inconsistent:

```bash
$ ceph health detail
HEALTH_ERR 1 scrub errors; Possible data damage: 1 pg inconsistent
[ERR] OSD_SCRUB_ERRORS: 1 scrub errors
[ERR] PG_DAMAGED: Possible data damage: 1 pg inconsistent
    pg 2.6 is active+clean+scrubbing+deep+inconsistent+repair, acting [0,1,2]

sh-5.1$ ceph pg repair 2.6
instructing pg 2.6 on osd.0 to repair

# WAIT A FEW MINUTES TO BE RECOVERED
```
