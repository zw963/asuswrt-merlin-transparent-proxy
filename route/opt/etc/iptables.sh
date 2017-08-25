#!/bin/sh

# 添加 AC87U 的 ipset protocal version 6 的 iptables/ipset 支持.
# See Following issue for detail:
# https://github.com/zw963/asuswrt-merlin-transparent-proxy/issues/4
# https://github.com/RMerl/asuswrt-merlin/issues/1062

# IF 条件确保只有在 SHADOWSOCKS chain 被清空后，才重新执行下面的 rule.
# 建立一个叫做 SHADOWSOCKS 的新的 chain
if ! iptables -t nat -N SHADOWSOCKS; then
    # 如果创建不成功, 表示已经存在.
    echo 'SHADOWSOCKS chain was exist!'
    # ipset -L FREEWEB
    exit
fi

ipset_protocal_version=$(ipset -v |grep -o 'version.*[0-9]' |head -n1 |cut -d' ' -f2)

if [ "$ipset_protocal_version" == 6 ]; then
    iptables='/usr/sbin/iptables'
    insmod ip_set
    insmod ip_set_hash_net
    insmod ip_set_hash_ip
    insmod xt_set
else
    iptables='/opt/sbin/iptables'
    insmod ip_set
    insmod ip_set_nethash
    insmod ip_set_iphash
    insmod ipt_set
fi

localips='
0.0.0.0/8
10.0.0.0/8
127.0.0.0/8
169.254.0.0/16
172.16.0.0/12
192.168.0.0/16
224.0.0.0/4
240.0.0.0/4
'

ipset -N FREEWEB iphash

# =================== tcp rule =================

# iptables 默认有四个表: raw, nat, mangle, filter, 每个表都有若干个不同的 chain.
# 例如: filter 表包含 INPUT, FORWARD, OUTPUT 三个链.

# -A 链名 表示新增(append)一条规则到该链, 该规则增加在原本存在规则的最后面.
# 换成 -I 链名, 则新插入的规则变为第一条规则.

# 插入本地地址直接返回的 rule 到 SHADOWSOCKS chain

ipt="$iptables -t nat"

for i in $localips; do
    $ipt -A SHADOWSOCKS -d "$i" -j RETURN
done

# 如果访问 VPS 地址, 直接返回.
$ipt -A SHADOWSOCKS -d SS_SERVER_IP -j RETURN

# 如果访问的域名在 FREEWEB 中, 直接返回.
$ipt -A SHADOWSOCKS -p tcp -m set --match-set FREEWEB dst -j RETURN

# 如果没有在之前的 rule 中 RETURN, 将执行下面的 rule.
# 这个 rule 将转发所有的 tcp 请求到 ss-redir 的本地端口.
$ipt -A SHADOWSOCKS -p tcp -j REDIRECT --to-ports SS_LOCAL_PORT

# 在 NAT 的初期阶段 (prerouting 阶段) 将发送到 80, 443 的所有请求, 应用 SHADOWSOCKS chain 中的规则.
# $ipt -A PREROUTING -p tcp -m multiport --dports 80,443 -j SHADOWSOCKS
$ipt -I PREROUTING 1 -p tcp -j SHADOWSOCKS
# $ipt -A SHADOWSOCKS -p tcp --syn -m connlimit --connlimit-above 32 -j RETURN

# ====================== udp rule =======================

if ! modprobe xt_TPROXY; then
    echo 'Kernel not support tproxy!'
    exit
fi

ip rule add fwmark 0x01/0x01 table 100
ip route add local 0.0.0.0/0 dev lo table 100

ipt="$iptables -t mangle"

$ipt -N SHADOWSOCKS

# 下面基于 udp 的规则, 类似于 tcp.
for i in $localips; do
    $ipt -A SHADOWSOCKS -d "$i" -j RETURN
done
$ipt -A SHADOWSOCKS -p udp -m set --match-set FREEWEB dst -j RETURN
$ipt -A SHADOWSOCKS -p udp -j TPROXY --on-port 1082 --tproxy-mark 0x01/0x01
# 这里可以 -i interface 来手动指定仅仅路由指定的接口.
$ipt -I PREROUTING 1 -p udp -j SHADOWSOCKS
