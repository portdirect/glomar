
#!/usr/bin/env bash
mkdir -p /var/log/osh


echo "baremetal-0 10.24.50.8 623 00:01:DE:AD:BE:EF sdb" >  /etc/openstack/bm-hosts.txt
echo "baremetal-1 10.24.50.8 624 00:01:DE:FD:B3:FB sdc" >>  /etc/openstack/bm-hosts.txt
echo "baremetal-2 10.24.50.8 625 00:01:DE:B8:60:F2 sdd" >>  /etc/openstack/bm-hosts.txt
echo "baremetal-3 10.24.50.8 626 00:01:DE:DF:E8:8B sde" >>  /etc/openstack/bm-hosts.txt
echo "baremetal-4 10.24.50.8 627 00:01:DE:F5:28:8E sdf" >>  /etc/openstack/bm-hosts.txt
echo "baremetal-5 10.24.50.8 628 00:01:DE:92:B7:B4 sdg" >>  /etc/openstack/bm-hosts.txt
echo "baremetal-6 10.24.50.8 629 00:01:DE:14:EF:ED sdh" >>  /etc/openstack/bm-hosts.txt
echo "baremetal-7 10.24.50.8 630 00:01:DE:CE:DB:2A sdi" >>  /etc/openstack/bm-hosts.txt
echo "baremetal-8 10.24.50.8 631 00:01:DE:CF:FA:C1 sdj" >>  /etc/openstack/bm-hosts.txt
echo "baremetal-9 10.24.50.8 632 00:01:DE:63:0E:11 sdk" >>  /etc/openstack/bm-hosts.txt


sdb      8:16   0   1.1T  0 disk
sdc      8:32   0   1.1T  0 disk
sdd      8:48   0   1.1T  0 disk
sde      8:64   0   1.1T  0 disk
sdf      8:80   0   1.1T  0 disk
sdg      8:96   0   1.1T  0 disk

sdh      8:112  0   1.1T  0 disk
sdi      8:128  0   1.1T  0 disk
sdj      8:144  0   1.1T  0 disk
sdk      8:160  0   1.1T  0 disk
sdl      8:176  0   1.1T  0 disk
sdm      8:192  0   1.1T  0 disk
sdn      8:208  0   1.1T  0 disk
sdo      8:224  0   1.1T  0 disk


while read NODE_DETAIL_RAW; do
  NODE_DETAIL=($(echo ${NODE_DETAIL_RAW}))
  NODE_NAME=${NODE_DETAIL[0]}
  NODE_BMC_IP=${NODE_DETAIL[1]}
  NODE_BMC_PORT=${NODE_DETAIL[2]}
  NODE_MAC=${NODE_DETAIL[3]}
  echo "$NODE_NAME $NODE_BMC_IP $NODE_BMC_PORT $NODE_MAC"
  sudo virsh define /opt/glomar/assets/opt/fake-bm/libvirt/${NODE_NAME}.xml
  sudo vbmc add ${NODE_NAME} \
    --address ${NODE_BMC_IP} \
    --port ${NODE_BMC_PORT}
done < /etc/openstack/bm-hosts.txt


MACHINE="baremetal-0"


sudo systemctl restart virtualbmc@baremetal-1
vbmc show baremetal-1
ipmitool -I lanplus -U admin -P password -H 10.24.50.8 -p 623 power on
sudo virsh list --all
ipmitool -I lanplus -U admin -P password -H 10.24.50.8 -p 623 power status
ipmitool -I lanplus -U admin -P password -H 10.24.50.8 -p 623 power off

sudo virsh undefine baremetal-1 --all
