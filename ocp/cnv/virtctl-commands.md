
oc project sample

virtctl create vm \
    --name rhel9-instancetype \
    --instancetype u1.medium \
    --infer-preference \
    --volume-datasource name:root,src:openshift-virtualization-os-images/rhel9,size:30Gi \
    | tee rhel9-instancetype.yaml

oc apply -f rhel9-instancetype.yaml
    
oc get vm -w

virtctl pause vm rhel9-instancetype

virtctl unpause vm rhel9-instancetype

virtctl stop rhel9-instancetype

virtctl stop rhel9-instancetype --force --grace-period=0

oc delete vm rhel9-instancetype