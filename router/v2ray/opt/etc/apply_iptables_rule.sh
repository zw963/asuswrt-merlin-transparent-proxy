#!/bin/sh

/opt/etc/clean_iptables_rule.sh

echo '[0m[33mApply iptables rule ...[0m'

if iptables -t nat -C PREROUTING -p tcp -j PROXY_TCP 2>/dev/null; then
    exit 0
fi

ipset_protocal_version=$(ipset -v |grep -o 'version.*[0-9]' |head -n1 |cut -d' ' -f2)

if [ "$ipset_protocal_version" == 6 ]; then
    alias iptables='/usr/sbin/iptables'
else
    alias iptables='/opt/sbin/iptables'
fi

local_redir_port=$(cat /opt/etc/v2ray.json |grep '"inbounds"' -A10 |grep '"protocol" *: *"dokodemo-door"' -A10 |grep '"port"' |grep -o '[0-9]*')

# iptables 默认有四个表: raw, nat, mangle, filter, 每个表都有若干个不同的 chain.
# 例如: filter 表包含 INPUT, FORWARD, OUTPUT 三个链, 下面创建了一个自定义 chain.
iptables -t nat -N PROXY_TCP 2>/dev/null

# 两个 ipset 中的 ip 直接返回.
iptables -t nat -A PROXY_TCP -p tcp -m set --match-set CHINAIPS dst -j RETURN
iptables -t nat -A PROXY_TCP -p tcp -m set --match-set CHINAIP dst -j RETURN
# 否则, 重定向到 ss-redir
iptables -t nat -A PROXY_TCP -p tcp -j REDIRECT --to-ports $local_redir_port

# Apply tcp rule
iptables -t nat -A PREROUTING -p tcp -j PROXY_TCP
# 对路由器进行透明代理.
iptables -t nat -A OUTPUT -p tcp -j PROXY_TCP

# UDP rule
ip rule add fwmark 0x2333/0x2333 pref 100 table 100
ip route add local default dev lo table 100

iptables -t mangle -N PROXY_UDP
iptables -t mangle -A PROXY_UDP -p udp -m set --match-set CHINAIPS dst -j RETURN
iptables -t mangle -A PROXY_UDP -p udp -m set --match-set CHINAIP dst -j RETURN
iptables -t mangle -A PROXY_UDP -p udp -j TPROXY --on-port 1080 --tproxy-mark 0x2333/0x2333
iptables -t mangle -A PREROUTING -p udp -j PROXY_UDP

echo '[0m[33mApply iptables rule done.[0m'
