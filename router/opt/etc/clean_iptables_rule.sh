#!/bin/sh

echo '[0m[33mClean iptables rule ...[0m'

ipset_protocal_version=$(ipset -v |grep -o 'version.*[0-9]' |head -n1 |cut -d' ' -f2)

if [ "$ipset_protocal_version" == 6 ]; then
    alias iptables='/usr/sbin/iptables'
else
    alias iptables='/opt/sbin/iptables'
fi

while iptables -t nat -C PREROUTING -p tcp -j PROXY_TCP 2>/dev/null; do
    iptables -t nat -D PREROUTING -p tcp -j PROXY_TCP
    iptables -t nat -D OUTPUT -p tcp -j PROXY_TCP
done
iptables -t nat -F PROXY_TCP 2>/dev/null          # flush
iptables -t nat -X PROXY_TCP 2>/dev/null          # --delete-chain

while iptables -t mangle -C PREROUTING -p udp -j PROXY_UDP 2>/dev/null; do
    iptables -t mangle -D PREROUTING -p udp -j PROXY_UDP
done
iptables -t mangle -F PROXY_UDP 2>/dev/null          # flush
iptables -t mangle -X PROXY_UDP 2>/dev/null          # --delete-chain

echo '[0m[33mClean iptables rule done.[0m'
