# Deploying multiple VLANs on top of a single Bond using ovs-bridges

These files will configure an OpenShift cluster with the following configuration:

<div style="text-align: center;">
  <img src="imgs/vm-network.png" alt="VM Network" width="1000">
</div>

## Procedure

**1. Apply the NNCP files (`vlanXXX-nncp.yaml`) and make sure it got created. Important: Set node selectors if you don't want to apply it in the entire cluster.**

![NNCP working](imgs/nncp.png)

**2. Apply the NAD files (`ovs-bridge-vlanXXX-nad.yaml`):**

![NAP](imgs/nad.png)

**3. Deploy your VMs with interfaces using the NAD and validate the network:**

![VMs Net Conf](imgs/vms1.png)

*VM Network Configuration*

![VMs IPs](imgs/vms2.png)

*Note VMs got IPs from each different VLAN*

![VMs Net Test](imgs/vms3.png)

*Simple connectivity test*

