
export OS_CLOUD=openstack_helm
export OSH_IRONIC_NODE_DISC="65536"
export OSH_IRONIC_NODE_RAM="4096"
export OSH_IRONIC_NODE_CPU="4"
export OSH_IRONIC_NODE_ARCH="x86_64"

#NOTE: Register the baremetal nodes with ironic
DEPLOY_VMLINUZ_UUID=$(openstack image show ironic-agent.kernel -f value -c id)
DEPLOY_INITRD_UUID=$(openstack image show ironic-agent.initramfs -f value -c id)
MASTER_IP=$(kubectl get node $(hostname -f) -o json |  jq -r '.status.addresses[] | select(.type=="InternalIP").address')
while read NODE_DETAIL_RAW; do
  NODE_DETAIL=($(echo ${NODE_DETAIL_RAW}))
  NODE_NAME=${NODE_DETAIL[0]}
  NODE_BMC_IP=${NODE_DETAIL[1]}
  NODE_BMC_PORT=${NODE_DETAIL[2]}
  NODE_MAC=${NODE_DETAIL[3]}
  BM_NODE=$(openstack baremetal node create \
            --name="${NODE_NAME}" \
            --driver agent_ipmitool \
            --driver-info ipmi_username=admin \
            --driver-info ipmi_password=password \
            --driver-info ipmi_address="${NODE_BMC_IP}" \
            --driver-info ipmi_port="${NODE_BMC_PORT}" \
            --driver-info deploy_kernel=${DEPLOY_VMLINUZ_UUID} \
            --driver-info deploy_ramdisk=${DEPLOY_INITRD_UUID} \
            --property local_gb=${OSH_IRONIC_NODE_DISC} \
            --property memory_mb=${OSH_IRONIC_NODE_RAM} \
            --property cpus=${OSH_IRONIC_NODE_CPU} \
            --property cpu_arch=${OSH_IRONIC_NODE_ARCH} \
            -f value -c uuid)
    openstack baremetal node manage "${BM_NODE}"
    openstack baremetal port create --node ${BM_NODE} "${NODE_MAC}"
    openstack baremetal node validate "${BM_NODE}"
    openstack baremetal node provide "${BM_NODE}"
    openstack baremetal node show "${BM_NODE}"
done < /etc/openstack/bm-hosts.txt

export OS_CLOUD=openstack_helm
export OSH_IRONIC_NODE_DISC="65536"
export OSH_IRONIC_NODE_RAM="4096"
export OSH_IRONIC_NODE_CPU="4"
export OSH_IRONIC_NODE_ARCH="x86_64"

#NOTE: Create a flavor assocated with our baremetal nodes
openstack flavor create \
  --disk ${OSH_IRONIC_NODE_DISC} \
  --ram ${OSH_IRONIC_NODE_RAM} \
  --vcpus ${OSH_IRONIC_NODE_CPU} \
  --property cpu_arch=${OSH_IRONIC_NODE_ARCH} \
  --property baremetal=true \
  baremetal
