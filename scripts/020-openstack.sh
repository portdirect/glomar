
tools/deployment/baremetal/010-setup-client.sh
tools/deployment/developer/common/030-ingress.sh
export OSH_EXTRA_HELM_ARGS="--values=./tools/overrides/releases/queens/loci.yaml"


#NOTE: Deploy command
[ -s /etc/openstack/ceph-fs-uuid.txt ] || uuidgen > /etc/openstack/ceph-fs-uuid.txt
CEPH_PUBLIC_NETWORK="$(./tools/deployment/multinode/kube-node-subnet.sh)"
CEPH_CLUSTER_NETWORK="$(./tools/deployment/multinode/kube-node-subnet.sh)"
CEPH_FS_ID="$(cat /etc/openstack/ceph-fs-uuid.txt)"

tee /tmp/ceph.yaml << EOF
pod:
  replicas:
    mds: 1
    mgr: 1
    rgw: 1
endpoints:
  identity:
    namespace: openstack
  object_store:
    namespace: ceph
  ceph_mon:
    namespace: ceph
network:
  public: ${CEPH_PUBLIC_NETWORK}
  cluster: ${CEPH_CLUSTER_NETWORK}
deployment:
  storage_secrets: true
  ceph: true
  rbd_provisioner: true
  cephfs_provisioner: true
  client_secrets: false
  rgw_keystone_user_and_endpoints: false
bootstrap:
  enabled: true
conf:
  ceph:
    global:
      fsid: ${CEPH_FS_ID}
  rgw_ks:
    enabled: true
  pool:
    crush:
      tunables: null
    target:
      osd: 3
      pg_per_osd: 100
    default:
      crush_rule: same_host
  storage:
    osd:
      - data:
         type: block-logical
         location: /dev/sdb
        journal:
          type: directory
          location: /var/lib/openstack-helm/ceph/osd/journal-sdb
      - data:
          type: block-logical
          location: /dev/sdc
        journal:
          type: directory
          location: /var/lib/openstack-helm/ceph/osd/journal-sdc
      - data:
          type: block-logical
          location: /dev/sdd
        journal:
          type: directory
          location: /var/lib/openstack-helm/ceph/osd/journal-sdd
EOF

for CHART in ceph-mon ceph-osd ceph-client; do
  helm upgrade --install ${CHART} ./${CHART} \
    --namespace=ceph \
    --values=/tmp/ceph.yaml \
    ${OSH_EXTRA_HELM_ARGS} \
    ${OSH_EXTRA_HELM_ARGS_CEPH_DEPLOY}

  #NOTE: Wait for deploy
  ./tools/deployment/common/wait-for-pods.sh ceph 1200

  #NOTE: Validate deploy
  MON_POD=$(kubectl get pods \
    --namespace=ceph \
    --selector="application=ceph" \
    --selector="component=mon" \
    --no-headers | awk '{ print $1; exit }')
  kubectl exec -n ceph ${MON_POD} -- ceph -s
done


tools/deployment/baremetal/035-ceph-ns-activate.sh
tools/deployment/baremetal/040-mariadb.sh
tools/deployment/multinode/060-rabbitmq.sh
tools/deployment/baremetal/060-memcached.sh
tools/deployment/multinode/080-keystone.sh
tools/deployment/multinode/090-ceph-radosgateway.sh
tools/deployment/baremetal/090-glance.sh
tools/deployment/baremetal/100-heat.sh
tools/deployment/developer/nfs/100-horizon.sh


#NOTE: Deploy OvS to connect nodes to the deployment host
helm install ./openvswitch \
  --namespace=openstack \
  --name=openvswitch

#NOTE: Wait for deploy
./tools/deployment/common/wait-for-pods.sh openstack

#NOTE: Validate Deployment info
helm status openvswitch

#NOTE: Lint and package chart
make neutron
make ironic
make nova

#NOTE: Deploy neutron
#NOTE(portdirect): for simplicity we will assume the default route device
# should be used for tunnels
NETWORK_TUNNEL_DEV="$(sudo ip -4 route list 0/0 | awk '{ print $5; exit }')"
OSH_IRONIC_PXE_DEV="ironic-pxe"
OSH_IRONIC_PXE_PYSNET="ironic"
tee /tmp/neutron.yaml << EOF
network:
  interface:
    tunnel: "${NETWORK_TUNNEL_DEV}"
  auto_bridge_add:
    ${OSH_IRONIC_PXE_DEV}: null
    br-ex: null
labels:
  ovs:
      node_selector_key: openstack-helm-node-class
      node_selector_value: primary
  agent:
    dhcp:
      node_selector_key: openstack-helm-node-class
      node_selector_value: primary
    l3:
      node_selector_key: openstack-helm-node-class
      node_selector_value: primary
    metadata:
      node_selector_key: openstack-helm-node-class
      node_selector_value: primary
pod:
  replicas:
    server: 1
conf:
  neutron:
    DEFAULT:
      l3_ha: False
      min_l3_agents_per_router: 1
      max_l3_agents_per_router: 1
      l3_ha_network_type: vxlan
      dhcp_agents_per_network: 1
  plugins:
    ml2_conf:
      ml2_type_flat:
        flat_networks: public,${OSH_IRONIC_PXE_PYSNET}
    openvswitch_agent:
      agent:
        tunnel_types: vxlan
      ovs:
        bridge_mappings: "external:br-ex,${OSH_IRONIC_PXE_PYSNET}:${OSH_IRONIC_PXE_DEV}"
EOF
helm install ./neutron \
    --namespace=openstack \
    --name=neutron \
    --values=/tmp/neutron.yaml \
    ${OSH_EXTRA_HELM_ARGS} \
    ${OSH_EXTRA_HELM_ARGS_NEUTRON}


OSH_IRONIC_PXE_DEV="${OSH_IRONIC_PXE_DEV:="ironic-pxe"}"
OSH_IRONIC_PXE_ADDR="${OSH_IRONIC_PXE_ADDR:="172.24.6.1/24"}"

sudo ip addr add "${OSH_IRONIC_PXE_ADDR}" dev "${OSH_IRONIC_PXE_DEV}"
sudo ip link set "${OSH_IRONIC_PXE_DEV}" up



tee /tmp/ironic.yaml << EOF
labels:
  node_selector_key: openstack-helm-node-class
  node_selector_value: primary
network:
  pxe:
    device: "${OSH_IRONIC_PXE_DEV}"
    neutron_provider_network: "${OSH_IRONIC_PXE_PYSNET}"
conf:
  ironic:
    DEFAULT:
      debug: true
    conductor:
      automated_clean: "false"
    deploy:
      shred_final_overwrite_with_zeros: "false"
EOF
helm install ./ironic \
    --namespace=openstack \
    --name=ironic \
    --values=/tmp/ironic.yaml \
    ${OSH_EXTRA_HELM_ARGS} \
    ${OSH_EXTRA_HELM_ARGS_IRONIC}

tee /tmp/nova.yaml << EOF
labels:
  agent:
    compute_ironic:
      node_selector_key: openstack-helm-node-class
      node_selector_value: primary
conf:
  nova:
    DEFAULT:
      debug: true
      #force_config_drive: false
      scheduler_host_manager: ironic_host_manager
      compute_driver: ironic.IronicDriver
      firewall_driver: nova.virt.firewall.NoopFirewallDriver
      #ram_allocation_ratio: 1.0
      reserved_host_memory_mb: 0
      scheduler_use_baremetal_filters: true
      baremetal_scheduler_default_filters: "RetryFilter,AvailabilityZoneFilter,ComputeFilter,ComputeCapabilitiesFilter"
    filter_scheduler:
      scheduler_tracks_instance_changes: false
      #scheduler_host_subset_size: 9999
    scheduler:
      discover_hosts_in_cells_interval: 120
manifests:
  cron_job_cell_setup: true
  daemonset_compute: false
  daemonset_libvirt: false
  statefulset_compute_ironic: true
  job_cell_setup: true
EOF
# Deploy Nova and enable the neutron agents
helm install ./nova \
    --namespace=openstack \
    --name=nova \
    --values=/tmp/nova.yaml \
    ${OSH_EXTRA_HELM_ARGS} \
    ${OSH_EXTRA_HELM_ARGS_NOVA}

#NOTE: Wait for deploy
./tools/deployment/common/wait-for-pods.sh openstack

#NOTE: Validate Deployment info
export OS_CLOUD=openstack_helm
openstack service list
sleep 30
openstack network agent list
openstack baremetal driver list
openstack compute service list

tools/deployment/baremetal/800-create-baremetal-host-aggregate.sh
