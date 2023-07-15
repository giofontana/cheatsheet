
# Configure OADP

On Cluster A:

1. Create DPA object
2. Create a sample app
3. Generate data:

```bash
oc -n test-oadp exec $(oc get pod -n test-oadp -o jsonpath='{.items[*].metadata.name}') -- bash -c 'echo "gen data 1" > /volume/file1'
oc -n test-oadp exec $(oc get pod -n test-oadp -o jsonpath='{.items[*].metadata.name}') -- bash -c 'echo "gen data 2" > /volume/file2'
oc -n test-oadp exec $(oc get pod -n test-oadp -o jsonpath='{.items[*].metadata.name}') -- bash -c 'echo "gen data 3" > /volume/file3'
oc -n test-oadp exec $(oc get pod -n test-oadp -o jsonpath='{.items[*].metadata.name}') -- bash -c 'echo "gen data 4" > /volume/file4'
oc -n test-oadp exec $(oc get pod -n test-oadp -o jsonpath='{.items[*].metadata.name}') -- bash -c 'echo "gen data 5" > /volume/file5'
oc -n test-oadp exec $(oc get pod -n test-oadp -o jsonpath='{.items[*].metadata.name}') -- bash -c 'ls -lhs /volume'
```

4. Create Backup

On Cluster B:
1. Create DPA object
2. Wait for backups to appear
3. Restore backup



# Useful links:

* Volume Backup/restore with restic via OADP operator v1.0 does not preserve data: https://access.redhat.com/solutions/6946011
* OpenShift APIs for Data Protection (OADP) FAQ: https://access.redhat.com/articles/5456281
* How to Backup and Restore Stateful Applications on OpenShift using OADP and ODF: https://cloud.redhat.com/blog/how-to-backup-and-restore-stateful-applications-on-openshift-using-oadp-and-odf
* Backup and Recovery with OpenShift APIs for Data Protection (OADP): https://www.opensourcerers.org/2021/05/10/backup-and-recovery-with-openshift-apis-for-data-protection-oadp/

# To check S3:

```
S3_ENDPOINT=https://s3-openshift-storage.apps.cluster-kqpxf.kqpxf.sandbox1728.opentlc.com
AWS_ACCESS_KEY_ID=*****
AWS_SECRET_ACCESS_KEY=******
aws --endpoint $S3_ENDPOINT --no-verify-ssl s3 ls

aws --endpoint $S3_ENDPOINT --no-verify-ssl s3 sync s3://oadp-bucket-e654141c-5c92-4d91-94c2-e377c87307fd/velero/ inspect-backup/
tree inspect-backup/
```