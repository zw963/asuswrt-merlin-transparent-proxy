#!/bin/sh

if ([ -x /opt/etc/iptables.sh ] && [ -f /opt/etc/dnsmasq.d/foreign_domains.conf ]) || [ "$1" ]; then
    echo '当前开启模式, 正在关闭'
    [ -f /tmp/iptables.rules ] && iptables-restore < /tmp/iptables.rules

    ip route flush table 100
    ipset destroy CHINAIPS
    mv /opt/etc/dnsmasq.d/foreign_domains.conf /opt/etc/dnsmasq.d/foreign_domains.bak
else
    echo '当前关闭模式，正在开启'
    mv /opt/etc/dnsmasq.d/foreign_domains.bak /opt/etc/dnsmasq.d/foreign_domains.conf
    chmod +x /opt/etc/iptables.sh && /opt/etc/iptables.sh
    /opt/etc/restart_dnsmasq
fi

# iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS
# iptables -t nat -F SHADOWSOCKS             # flush
# iptables -t nat -X SHADOWSOCKS             # --delete-chain
