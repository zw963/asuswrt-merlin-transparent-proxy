#!/bin/sh

iptables_bak=/tmp/iptables.rules

if [ ! -f $iptables_bak -o ! -f /tmp/patch_router_is_run ]; then
    # 如果不存在 iptables 备份文件, 表示未部署过, 无需 toggle proxy.
    exit
fi

if [ "$1" == 'disable' ] || [ -x /opt/etc/iptables.sh ]; then
    echo 'Disable proxy ...'
    
    ipset_protocal_version=$(ipset -v |grep -o 'version.*[0-9]' |head -n1 |cut -d' ' -f2)

    ip route flush table 100

    if [ "$ipset_protocal_version" == 6 ]; then
        alias iptables='/usr/sbin/iptables'
        ipset destroy CHINAIP 2>/dev/null
        ipset destroy CHINAIPS 2>/dev/null
        iptables-restore < $iptables_bak
    else
        alias iptables='/opt/sbin/iptables'
        ipset -X CHINAIP 2>/dev/null
        ipset -X CHINAIPS 2>/dev/null
        /usr/sbin/iptables-restore < $iptables_bak
    fi

    chmod -x /opt/etc/iptables.sh
    chmod -x /opt/etc/patch_router

    iptables -t nat -F SHADOWSOCKS_TCP 2>/dev/null          # flush
    iptables -t nat -X SHADOWSOCKS_TCP 2>/dev/null          # --delete-chain
    iptables -t mangle -F SHADOWSOCKS_UDP 2>/dev/null
    iptables -t mangle -X SHADOWSOCKS_UDP 2>/dev/null
    iptables -t mangle -F SHADOWSOCKS_MARK 2>/dev/null
    iptables -t mangle -X SHADOWSOCKS_MARK 2>/dev/null

    sed -i "s#conf-dir=/opt/etc/dnsmasq.d/,\*\.conf#\# &#" /etc/dnsmasq.conf
    /opt/etc/restart_dnsmasq
    echo 'Proxy is disabled.'
else
    echo 'Enable proxy ...'
    chmod +x /opt/etc/iptables.sh
    chmod +x /opt/etc/patch_router && /opt/etc/patch_router
    echo 'Proxy is enabled.'
fi

# iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS
