

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
