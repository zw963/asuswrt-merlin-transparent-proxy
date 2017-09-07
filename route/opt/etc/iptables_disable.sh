#!/bin/sh

[ -f /opt/etc/iptables.rules ] && iptables-restore < /opt/etc/iptables.rules
ip rule del fwmark 1 lookup 100
ip route del local 0.0.0.0/0 dev lo table 100
ipset destroy FREEWEB

# iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS
# iptables -t nat -F SHADOWSOCKS             # flush
# iptables -t nat -X SHADOWSOCKS             # --delete-chain
