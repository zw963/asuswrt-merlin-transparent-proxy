#!/bin/sh

echo '[0m[33mClean iptables rule ...[0m'

ipset_protocal_version=$(ipset -v |grep -o 'version.*[0-9]' |head -n1 |cut -d' ' -f2)

if [ "$ipset_protocal_version" == 6 ]; then
    alias iptables='/usr/sbin/iptables'
else
    alias iptables='/opt/sbin/iptables'
fi

while iptables -t nat -C PREROUTING -p tcp -j SHADOWSOCKS_TCP 2>/dev/null; do
    iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS_TCP
done

iptables -t nat -F SHADOWSOCKS_TCP 2>/dev/null          # flush
iptables -t nat -X SHADOWSOCKS_TCP 2>/dev/null          # --delete-chain

while iptables -t mangle -C PREROUTING -p udp -j SHADOWSOCKS_UDP 2>/dev/null; do
    iptables -t mangle -D PREROUTING -p udp -j SHADOWSOCKS_UDP
done

iptables -t mangle -F SHADOWSOCKS_UDP 2>/dev/null
iptables -t mangle -X SHADOWSOCKS_UDP 2>/dev/null

iptables -t mangle -F SHADOWSOCKS_MARK 2>/dev/null
iptables -t mangle -X SHADOWSOCKS_MARK 2>/dev/null

echo '[0m[33mClean iptables rule done.[0m'
