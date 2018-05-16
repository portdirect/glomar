#!/usr/bin/env bash

sudo -H dnf -y install \
  ipmitool \
  libguestfs \
  libvirt \
  libvirt-daemon \
  libvirt-daemon-config-nwfilter \
  libvirt-daemon-driver-lxc \
  libvirt-daemon-driver-nwfilter \
  libvirt-devel \
  openvswitch \
  qemu-kvm ;\
sudo -H dnf -y group install \
  "Development Tools" ;\
sudo -H dnf clean all ;\
git clone https://github.com/openstack/virtualbmc /tmp/virtualbmc ;\
sudo -H pip install -U /tmp/virtualbmc

systemctl stop ovsdb-server.service ovs-vswitchd.service openvswitch.service
systemctl discard ovsdb-server.service ovs-vswitchd.service openvswitch.service
systemctl mask ovsdb-server.service ovs-vswitchd.service openvswitch.service
