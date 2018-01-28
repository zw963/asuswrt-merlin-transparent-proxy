#!/bin/sh

resolv_file=$(cat /etc/dnsmasq.conf |grep 'resolv-file=' |tail -n1 |cut -d'=' -f2)
default_dns_ip=$(cat $resolv_file |head -n1 |cut -d' ' -f2)

if [ -x /opt/etc/iptables.sh ] || [ "$1" == 'disable' ]; then
    echo 'Disable proxy ...'

    ipset_protocal_version=$(ipset -v |grep -o 'version.*[0-9]' |head -n1 |cut -d' ' -f2)

    [ -f /tmp/iptables.rules ] && iptables-restore < /tmp/iptables.rules
    chmod -x /opt/etc/iptables.sh

    ip route flush table 100

    if [ "$ipset_protocal_version" == 6 ]; then
        alias iptables='/usr/sbin/iptables'
        ipset destroy CHINAIPS
    else
        alias iptables='/opt/sbin/iptables'
        ipset -X CHINAIPS
    fi

    iptables -t nat -F SHADOWSOCKS_TCP          # flush
    iptables -t nat -X SHADOWSOCKS_TCP          # --delete-chain
    iptables -t mangle -F SHADOWSOCKS_UDP 2>/dev/null
    iptables -t mangle -X SHADOWSOCKS_UDP 2>/dev/null

    sed -i "s#server=/\#/.*#server=/\#/${default_dns_ip}#" /opt/etc/dnsmasq.d/foreign_domains.conf

    /opt/etc/restart_dnsmasq
else
    echo 'Enable proxy ...'

    chmod +x /opt/etc/patch_router && /opt/etc/patch_router
fi

echo 'Done.'

# iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS
