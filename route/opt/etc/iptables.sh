#!/bin/sh

# 添加 AC87U 的 ipset protocal version 6 的 iptables/ipset 支持.
# See Following issue for detail:
# https://github.com/zw963/asuswrt-merlin-transparent-proxy/issues/4
# https://github.com/RMerl/asuswrt-merlin/issues/1062

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

# IF 条件确保只有在这个表被清空后，才重新执行 iptables.
if $iptables -t nat -N SHADOWSOCKS; then
    ipset -N FREEWEB iphash
    $iptables -t nat -A SHADOWSOCKS -d 0.0.0.0/8 -j RETURN
    $iptables -t nat -A SHADOWSOCKS -d 10.0.0.0/8 -j RETURN
    $iptables -t nat -A SHADOWSOCKS -d 127.0.0.0/8 -j RETURN
    $iptables -t nat -A SHADOWSOCKS -d 169.254.0.0/16 -j RETURN
    $iptables -t nat -A SHADOWSOCKS -d 172.16.0.0/12 -j RETURN
    $iptables -t nat -A SHADOWSOCKS -d 192.168.0.0/16 -j RETURN
    $iptables -t nat -A SHADOWSOCKS -d 224.0.0.0/4 -j RETURN
    $iptables -t nat -A SHADOWSOCKS -d 240.0.0.0/4 -j RETURN

    sh /opt/etc/iptables.china

    # 如果有很多 ss-server，并且所有的 server 都是同样的端口 22334, 用法如下
    # $iptables -t nat -A SHADOWSOCKS -p tcp --dport 22334 -j RETURN

    $iptables -t nat -A SHADOWSOCKS -d SS_SERVER_IP -j RETURN

    $iptables -t nat -A SHADOWSOCKS -m set --match-set FREEWEB dst -j RETURN

    $iptables -t nat -A SHADOWSOCKS -p tcp -j REDIRECT --to-ports SS_LOCAL_PORT
    $iptables -t nat -A SHADOWSOCKS -p udp -j REDIRECT --to-ports SS_LOCAL_PORT

    $iptables -t nat -I PREROUTING -p tcp -m multiport --dports 80,443 -j SHADOWSOCKS
    # $iptables -t nat -A SHADOWSOCKS -p tcp --syn -m connlimit --connlimit-above 32 -j RETURN
fi

# 查看 ipset
ipset -L FREEWEB
