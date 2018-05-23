#!/bin/sh

if [ -x /opt/etc/iptables.sh ] || [ "$1" == 'disable' ]; then
    echo 'Disable proxy ...'

    ipset_protocal_version=$(ipset -v |grep -o 'version.*[0-9]' |head -n1 |cut -d' ' -f2)

    [ -e /tmp/iptables.rules ] && iptables-restore < /tmp/iptables.rules
    chmod -x /opt/etc/iptables.sh
    chmod -x /opt/etc/patch_router

    ip route flush table 100

    if [ "$ipset_protocal_version" == 6 ]; then
        alias iptables='/usr/sbin/iptables'
        ipset destroy CHINAIP
        ipset destroy CHINAIPS
    else
        alias iptables='/opt/sbin/iptables'
        ipset -X CHINAIP
        ipset -X CHINAIPS
    fi

    iptables -t nat -F SHADOWSOCKS_TCP          # flush
    iptables -t nat -X SHADOWSOCKS_TCP          # --delete-chain
    iptables -t mangle -F SHADOWSOCKS_UDP 2>/dev/null
    iptables -t mangle -X SHADOWSOCKS_UDP 2>/dev/null
    iptables -t mangle -F SHADOWSOCKS_MARK 2>/dev/null
    iptables -t mangle -X SHADOWSOCKS_MARK 2>/dev/null

    sed -i "s#conf-dir=/opt/etc/dnsmasq.d/,\*\.conf#\# &#" /etc/dnsmasq.conf
    /opt/etc/restart_dnsmasq
else
    echo 'Enable proxy ...'
    chmod +x /opt/etc/iptables.sh
    chmod +x /opt/etc/patch_router && /opt/etc/patch_router
fi

echo 'Done.'

# iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS
