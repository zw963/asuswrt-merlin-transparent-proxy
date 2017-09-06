#!/bin/sh

# use iptables-restore < /opt/etc/iptables.rules 恢复原始的 iptables
[ -f /opt/etc/iptables.rules ] || iptables-save > /opt/etc/iptables.rules

# 建立一个叫做 SHADOWSOCKS 的新的 chain
iptables -t nat -N SHADOWSOCKS
ipset -N FREEWEB iphash

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

localips=$(cat /opt/etc/localips)

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

# 在 NAT 的初期阶段 (prerouting 阶段) 应用 SHADOWSOCKS chain 中的 tcp 规则.
# 应用规则, 注释这行代码, 重启后会让 TCP rules 失效.
$ipt -I PREROUTING 1 -p tcp -j SHADOWSOCKS

# 这行代码为什么要开启?
# $ipt -I OUTPUT 1 -p tcp -j SHADOWSOCKS

# ====================== udp rule =======================

if ! modprobe xt_TPROXY; then
    echo 'Kernel not support tproxy!'
    exit
fi

ip rule add fwmark 0x01/0x01 table 100
ip route add local 0.0.0.0/0 dev lo table 100

ipt="$iptables -t mangle"

$ipt -N SHADOWSOCKS

for i in $localips; do
    $ipt -A SHADOWSOCKS -d "$i" -j RETURN
done

# 这里的 FREEWEB 是在 dnsmasq 里面添加的白名单域名, 也就是国内可以直接访问的域名列表.
# 我期望的目的是:
# - 使用单个的 ss-redir 就可以实现透明代理. (无需 ss-tunnel), 好吧, 这是第一步, 先解决这个.
# - dnsmasq 中有大量的类似于下面的 ipset 规则(全都是国内域名)

# ipset=/0-6.com/FREEWEB
# ipset=/0-gold.net/FREEWEB
# ipset=/00.net/FREEWEB
# ipset=/0000738.com/FREEWEB
# ipset=/0001688.com/FREEWEB
# ipset=/000219.com/FREEWEB
# ipset=/0007.net/FREEWEB
# ipset=/000dn.com/FREEWEB

# ...

# ipset=/zzz4.com/FREEWEB
# ipset=/zzzj.com/FREEWEB
# ipset=/zzzmode.com/FREEWEB
# ipset=/zzzyb.com/FREEWEB
# ipset=/zzzyit.com/FREEWEB
# ipset=/zzyjs.com/FREEWEB
# ipset=/zzyzphoto.com/FREEWEB
# ipset=/zzz4.com/FREEWEB
# ipset=/zzzj.com/FREEWEB
# ipset=/zzzmode.com/FREE
#
# server=/#/8.8.8.8#53   # 这里应该怎么设定? 写 ss-redir(1080)端口, 还是 8.8.8.8(53) ??
#
# 我希望可以利用这些规则, 实现国内域名用默认, 国外走 redir 的 udp 接口差 DNS

# 下面是我的实现, 很显然, 目前不工作! 而且这里的 --on-port ???? 到底该是什么端口? 晕了.
$ipt -A SHADOWSOCKS -p udp -m set --match-set FREEWEB dst -j RETURN
$ipt -A SHADOWSOCKS -p udp --dport 53 -j TPROXY --on-port 1082 --tproxy-mark 0x01/0x01

# 应用规则, 注释这行代码, 重启后会让 UDP rules 失效.
$ipt -I PREROUTING 1 -p udp -j SHADOWSOCKS
