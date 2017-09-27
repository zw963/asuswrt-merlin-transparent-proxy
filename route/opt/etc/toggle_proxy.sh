#!/bin/sh

resolv_file=$(cat /etc/dnsmasq.conf |grep 'resolv-file=' |tail -n1 |cut -d'=' -f2)
default_dns_ip=$(cat $resolv_file |head -n1 |cut -d' ' -f2)

if [ -x /opt/etc/iptables.sh ] || [ "$1" == 'disable' ]; then
    echo 'Disable proxy ...'

    [ -f /tmp/iptables.rules ] && iptables-restore < /tmp/iptables.rules
    chmod -x /opt/etc/iptables.sh

    ip route flush table 100
    ipset destroy CHINAIPS
    iptables -t nat -F SHADOWSOCKS_TCP          # flush
    iptables -t nat -X SHADOWSOCKS_TCP          # --delete-chain
    iptables -t mangle -F SHADOWSOCKS_UDP
    iptables -t mangle -X SHADOWSOCKS_UDP

    sed -i "s#server=/\#/.*#server=/\#/${default_dns_ip}#" /opt/etc/dnsmasq.d/foreign_domains.conf

    /opt/etc/restart_dnsmasq
else
    echo 'Enable proxy ...'

    chmod +x /opt/etc/iptables.sh && /opt/etc/iptables.sh
fi

# iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS
