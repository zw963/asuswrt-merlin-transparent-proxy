#!/bin/sh

[ -f /tmp/iptables.rules ] && iptables-restore < /tmp/iptables.rules

ip route flush table 100
ipset destroy CHINAIPS

echo '你可能还需要以下两步才可以生效:'

echo '1. 检查 dnsmasq 中相关配置.'
echo '2. chmod -x /opt/etc/iptables.sh, 避免被再次自动运行'

# iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS
# iptables -t nat -F SHADOWSOCKS             # flush
# iptables -t nat -X SHADOWSOCKS             # --delete-chain
