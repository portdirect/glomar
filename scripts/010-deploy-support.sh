#!/usr/bin/env bash

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5EDB1B62EC4926EA
echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu bionic-updates/rocky main" | sudo tee /etc/apt/sources.list.d/cloud-archive.list
sudo -H apt-get update
sudo -H apt-get install --no-install-recommends -y \
  ipmitool \
  libvirt-bin \
  qemu \
  libvirt-dev \
  pkg-config
git clone https://github.com/openstack/virtualbmc /opt/virtualbmc ;\
sudo -H pip install --upgrade /opt/virtualbmc

sudo tee /etc/systemd/system/virtualbmc.service <<EOF
[Unit]
Description=VirtualBMC Daemon
After=network.target

[Service]
ExecStart=/usr/local/bin/vbmcd --foreground
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl start virtualbmc
sudo systemctl enable virtualbmc

sudo mkdir -p /var/log/osh /etc/openstack /etc/openstack/nodes
sudo chown -R $(whoami): /etc/openstack /etc/openstack/nodes

sudo tee -a /etc/netplan/01-netcfg.yaml <<EOF
  bridges:
    ironic-pxe:
      dhcp4: false
EOF
sudo netplan apply

tee /etc/openstack/bm-hosts.txt <<EOF
baremetal-00 10.24.50.8 623 00:01:DE:AD:BE:EF sdb
baremetal-01 10.24.50.8 624 00:01:DE:FD:B3:FB sdc
baremetal-02 10.24.50.8 625 00:01:DE:B8:60:F2 sdd
baremetal-03 10.24.50.8 626 00:01:DE:DF:E8:8B sde
baremetal-04 10.24.50.8 627 00:01:DE:F5:28:8E sdf
baremetal-05 10.24.50.8 628 00:01:DE:92:B7:B4 sdg
baremetal-06 10.24.50.8 629 00:01:DE:14:EF:ED sdh
baremetal-07 10.24.50.8 630 00:01:DE:CE:DB:2A sdi
baremetal-08 10.24.50.8 631 00:01:DE:CF:FA:C1 sdj
baremetal-09 10.24.50.8 632 00:01:DE:63:0E:11 sdk
baremetal-10 10.24.50.8 633 00:01:DE:23:16:75 sdl
baremetal-11 10.24.50.8 634 00:01:DE:99:90:2D sdm
baremetal-12 10.24.50.8 635 00:01:DE:F4:94:FF sdn
baremetal-13 10.24.50.8 636 00:01:DE:07:0A:80 sd0
EOF

#14VM, 768GB ram on host so why not randomly pick 48GB ram per node...
tee /etc/openstack/bm-template.txt <<EOF
<domain type='kvm'>
  <name>{{ NODE_NAME }}</name>
  <memory unit='MB'>49152</memory>
  <vcpu placement='static'>4</vcpu>
  <resource>
    <partition>/machine</partition>
  </resource>
  <os>
    <type arch='x86_64' machine='pc'>hvm</type>
    <boot dev='network'/>
    <boot dev='hd'/>
    <bootmenu enable='no'/>
    <bios useserial='yes'/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='host-model'>
    <topology sockets='1' cores='4' threads='1'/>
  </cpu>
  <clock offset='localtime'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>restart</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw'/>
      <source dev='/dev/{{ NODE_DRIVE }}'/>
      <target dev='vda' bus='virtio'/>
      <alias name='virtio-disk0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
    </disk>
    <controller type='usb' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x2'/>
    </controller>
    <controller type='ide' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x1'/>
    </controller>
    <controller type='pci' index='0' model='pci-root'/>
    <interface type='bridge'>
      <mac address='{{ NODE_MAC }}'/>
      <source bridge='ironic-pxe'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </interface>
    <serial type='file'>
      <source path='/var/log/osh/{{ NODE_NAME }}.log' append='on'/>
      <target port='0'/>
    </serial>
    <serial type='pty'>
      <target port='1'/>
    </serial>
    <console type='file'>
      <source path='/var/log/osh/{{ NODE_NAME }}.log' append='on'/>
      <target type='serial' port='0'/>
    </console>
    <input type='tablet' bus='usb'>
      <address type='usb' bus='0' port='1'/>
    </input>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <memballoon model='virtio'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </memballoon>
  </devices>
</domain>
EOF

while read NODE_DETAIL_RAW; do
  NODE_DETAIL=($(echo ${NODE_DETAIL_RAW}))
  NODE_NAME=${NODE_DETAIL[0]}
  NODE_BMC_IP=${NODE_DETAIL[1]}
  NODE_BMC_PORT=${NODE_DETAIL[2]}
  NODE_MAC=${NODE_DETAIL[3]}
  NODE_DRIVE=${NODE_DETAIL[4]}
  echo "$NODE_NAME $NODE_BMC_IP $NODE_BMC_PORT $NODE_MAC $NODE_DRIVE"
  sed "s|{{ NODE_NAME }}|${NODE_NAME}|g" /etc/openstack/bm-template.txt | \
    sed "s|{{ NODE_MAC }}|${NODE_MAC}|g" | \
    sed "s|{{ NODE_DRIVE }}|${NODE_DRIVE}|g" > /etc/openstack/nodes/${NODE_NAME}.xml
  sudo virsh define /etc/openstack/nodes/${NODE_NAME}.xml
  sudo vbmc --no-daemon add ${NODE_NAME} --address ${NODE_BMC_IP} --port ${NODE_BMC_PORT}
  sudo vbmc --no-daemon start ${NODE_NAME}
done < /etc/openstack/bm-hosts.txt


while read NODE_DETAIL_RAW; do
  NODE_DETAIL=($(echo ${NODE_DETAIL_RAW}))
  NODE_NAME=${NODE_DETAIL[0]}
  NODE_BMC_IP=${NODE_DETAIL[1]}
  NODE_BMC_PORT=${NODE_DETAIL[2]}
  NODE_MAC=${NODE_DETAIL[3]}
  NODE_DRIVE=${NODE_DETAIL[4]}
  sudo vbmc --no-daemon show ${NODE_NAME}
  sudo ipmitool -I lanplus -U admin -P password -H ${NODE_BMC_IP} -p ${NODE_BMC_PORT} power status
done < /etc/openstack/bm-hosts.txt
