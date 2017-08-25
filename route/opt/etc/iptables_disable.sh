#!/bin/sh

ipset_protocal_version=$(ipset -v |grep -o 'version.*[0-9]' |head -n1 |cut -d' ' -f2)

if [ "$ipset_protocal_version" == 6 ]; then
    iptables='/usr/sbin/iptables'
else
    iptables='/opt/sbin/iptables'
fi

localips=$(cat /opt/etc/localips)

ipt="$iptables -t nat"

for i in $localips; do
    $ipt -D SHADOWSOCKS -d "$i" -j RETURN
done
$ipt -D SHADOWSOCKS -d SS_SERVER_IP -j RETURN
$ipt -D SHADOWSOCKS -p tcp -m set --match-set FREEWEB dst -j RETURN
$ipt -D SHADOWSOCKS -p tcp -j REDIRECT --to-ports SS_LOCAL_PORT
$ipt -D PREROUTING -p tcp -j SHADOWSOCKS
# $ipt -F SHADOWSOCKS             # flush
# $ipt -X SHADOWSOCKS             # --delete-chain
# $ipt -Z SHADOWSOCKS             # --zero


if ! modprobe xt_TPROXY; then
    echo 'Kernel not support tproxy!'
    exit
fi

ip rule del fwmark 0x01/0x01 table 100
ip route del local 0.0.0.0/0 dev lo table 100

ipt="$iptables -t mangle"

for i in $localips; do
    $ipt -D SHADOWSOCKS -d "$i" -j RETURN
done
$ipt -D SHADOWSOCKS -p udp -m set --match-set FREEWEB dst -j RETURN
$ipt -D SHADOWSOCKS -p udp -j TPROXY --on-port 1082 --tproxy-mark 0x01/0x01
$ipt -D PREROUTING -p udp -j SHADOWSOCKS
# $ipt -F SHADOWSOCKS             # flush
# $ipt -X SHADOWSOCKS             # --delete-chain
# $ipt -Z SHADOWSOCKS             # --zero
