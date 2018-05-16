

#NOTE: Validate Deployment info
export OS_CLOUD=openstack_helm

export OSH_VM_KEY_STACK="heat-vm-key"
# Setup SSH Keypair in Nova
mkdir -p ${HOME}/.ssh
openstack keypair create --private-key ${HOME}/.ssh/osh_key ${OSH_VM_KEY_STACK}
chmod 600 ${HOME}/.ssh/osh_key

# Deploy heat stack to provision node
openstack stack create --wait --timeout 15 \
    -t ./tools/gate/files/heat-basic-bm-deployment.yaml \
    heat-basic-bm-deployment

FLOATING_IP=$(openstack stack output show \
    heat-basic-bm-deployment \
    ip \
    -f value -c output_value)

    sde      8:64   0  1.1T  0 disk
    sdf      8:80   0  1.1T  0 disk
    sdg      8:96   0  1.1T  0 disk
    sdh      8:112  0  1.1T  0 disk
    sdi      8:128  0  1.1T  0 disk
    sdj      8:144  0  1.1T  0 disk
    sdk      8:160  0  1.1T  0 disk 5
    sdl      8:176  0  1.1T  0 disk 6
    sdm      8:192  0  1.1T  0 disk 7
    sdn      8:208  0  1.1T  0 disk 8
    sdo      8:224  0  1.1T  0 disk 9
