#!/bin/sh

/opt/etc/clean_iptables_rule.sh

echo '[0m[33mApply iptables rule ...[0m'

if iptables -t nat -C PREROUTING -p tcp -j SHADOWSOCKS_TCP 2>/dev/null; then
    exit 0
fi

ipset_protocal_version=$(ipset -v |grep -o 'version.*[0-9]' |head -n1 |cut -d' ' -f2)

if [ "$ipset_protocal_version" == 6 ]; then
    alias iptables='/usr/sbin/iptables'
else
    alias iptables='/opt/sbin/iptables'
fi

local_redir_port=$(cat /opt/etc/shadowsocks.json |grep 'local_port' |cut -d':' -f2 |grep -o '[0-9]*')

# iptables 默认有四个表: raw, nat, mangle, filter, 每个表都有若干个不同的 chain.
# 例如: filter 表包含 INPUT, FORWARD, OUTPUT 三个链, 下面创建了一个自定义 chain.
iptables -t nat -N SHADOWSOCKS_TCP 2>/dev/null

# 两个 ipset 中的 ip 直接返回.
iptables -t nat -A SHADOWSOCKS_TCP -p tcp -m set --match-set CHINAIPS dst -j RETURN
iptables -t nat -A SHADOWSOCKS_TCP -p tcp -m set --match-set CHINAIP dst -j RETURN
# 否则, 重定向到 ss-redir
iptables -t nat -A SHADOWSOCKS_TCP -p tcp -j REDIRECT --to-ports $local_redir_port

# Apply tcp rule
iptables -t nat -A PREROUTING -p tcp -j SHADOWSOCKS_TCP
# 从路由器内访问时, 也是用这个 rule.
# iptables -t nat -A OUTPUT -p tcp -j SHADOWSOCKS_TCP

echo '[0m[33mApply iptables rule done.[0m'
