#!/bin/sh

if [ -f /opt/etc/iptables.rules ]; then
    iptables-restore < /opt/etc/iptables.rules
fi

ipset_protocal_version=$(ipset -v |grep -o 'version.*[0-9]' |head -n1 |cut -d' ' -f2)

if [ "$ipset_protocal_version" == 6 ]; then
    iptables='/usr/sbin/iptables'
else
    iptables='/opt/sbin/iptables'
fi

$iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS
$iptables -t nat -F SHADOWSOCKS             # flush
$iptables -t nat -X SHADOWSOCKS             # --delete-chain

if ! modprobe xt_TPROXY; then
    echo 'Kernel not support tproxy!'
    exit
fi

ip rule del fwmark 0x01/0x01 table 100
ip route del local 0.0.0.0/0 dev lo table 100

$iptables -t mangle -D PREROUTING -p udp -j SHADOWSOCKS
$iptables -t mangle -F SHADOWSOCKS             # flush
$iptables -t mangle -X SHADOWSOCKS             # --delete-chain
