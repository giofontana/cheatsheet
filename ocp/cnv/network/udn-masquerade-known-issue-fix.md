
Link (Seach for "169.254.169.0/29"): https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/release_notes/ocp-4-18-release-notes#ocp-4-18-known-issues_release-notes

# Verification
oc get pods -n openshift-ovn-kubernetes -o wide # Some pods will be crashloopback or running but 7/8 (container failing)

# To fix

## 1. Remove all VMs that use udn
oc delete vm --all -n <namespace>

## 2. Remova all udns
oc delete userdefinednetwork primary-udn -n <namespace>

## 3. Delete a ovnkube pod to check if it fixed it
oc get pods -n openshift-ovn-kubernetes -o wide
oc delete pod <pod> -n openshift-ovn-kubernetes

## 4. Ovnkube should be restarted and healthy (ovnkube pod = Running and 8/8)

## 5. Reboot the node if it is NotReady

## 6. When cluster is healthy again, run the following to fix masquerade subnet:
oc patch networks.operator.openshift.io cluster --type=merge -p '{"spec":{"defaultNetwork":{"ovnKubernetesConfig":{"gatewayConfig":{"ipv4":{"internalMasqueradeSubnet": "169.254.0.0/17"}}}}}}'

## 7. Wait for net operator to rollout it:
watch "oc get nodes -o yaml | grep masquerade"

# Fix validation

## 1. Recreate the UDN primary network
## 2. Provision VMs using the primary network
## 3. Restart a ovnkube pod
oc get pods -n openshift-ovn-kubernetes -o wide
oc delete pod <pod> -n openshift-ovn-kubernetes
## 4. Ovnkube should be restarted and healthy (ovnkube pod = Running and 8/8)
## 5. You may also reboot one node to make sure fix is persistent.