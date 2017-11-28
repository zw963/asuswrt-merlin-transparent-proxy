#!/bin/sh

# iptables 默认有四个表: raw, nat, mangle, filter, 每个表都有若干个不同的 chain.
# 例如: filter 表包含 INPUT, FORWARD, OUTPUT 三个链, 下面创建了一个自定义 chain.
if ! iptables -t nat -N SHADOWSOCKS_TCP; then
    # 如果不成功, 表示已经执行过了, 直接退出.
    # 经过测试, 梅林还是会经常删除自定义 iptables, 所以, 还是需要反复执行这个文件来确保有效.
    exit
fi

echo '[0m[33mApplying iptables rule, it may take several minute to finish ...[0m'

[ -f /tmp/iptables.rules ] || iptables-save > /tmp/iptables.rules

ipset_protocal_version=$(ipset -v |grep -o 'version.*[0-9]' |head -n1 |cut -d' ' -f2)

if [ "$ipset_protocal_version" == 6 ]; then
    alias iptables='/usr/sbin/iptables'
    modprobe ip_set
    modprobe ip_set_hash_net
    modprobe ip_set_hash_ip
    modprobe xt_set
    # 默认值 hashsize 1024 maxelem 65536, 已经足够了.
    ipset -N CHINAIPS hash:net
    alias ipset_add='ipset add CHINAIPS'
else
    alias iptables='/opt/sbin/iptables'
    modprobe ip_set
    modprobe ip_set_nethash
    modprobe ip_set_iphash
    modprobe ipt_set
    ipset -N CHINAIPS nethash
    alias ipset_add='ipset -q -A CHINAIPS'
fi

localips=$(cat /opt/etc/localips)

OLDIFS="$IFS" && IFS=$'\n'
if ipset -L CHINAIPS; then
    # 将国内的 ip 全部加入 ipset CHINAIPS, 近 8000 条, 这个过程可能需要近一分钟时间.
    for ip in $(cat /opt/etc/chinadns_chnroute.txt); do
        ipset_add $ip
    done

    # 应用 ip 白名单.
    # 格式示例:
    # 81.4.123.217 # entware 的地址 (注释可选)

    if [ -e /opt/etc/user_ip_whitelist.txt ]; then
        for ip in $(cat /opt/etc/user_ip_whitelist.txt); do
            ipset_add $ip
        done
    fi
fi


# 为 SHADOWSOCKS_TCP chain 插入 rule.
for i in $localips; do
    iptables -t nat -A SHADOWSOCKS_TCP -d $i -j RETURN
done

IFS=$OLDIFS

remote_server_ip=$(cat /opt/etc/shadowsocks.json |grep 'server"' |cut -d':' -f2|cut -d'"' -f2)
local_redir_ip=$(cat /opt/etc/shadowsocks.json |grep 'local_address"' |cut -d':' -f2|cut -d'"' -f2)
local_redir_port=$(cat /opt/etc/shadowsocks.json |grep 'local_port' |cut -d':' -f2 |grep -o '[0-9]*')

# ====================== tcp rule =======================

# 如果访问 VPS 地址, 无需跳转, 直接返回, 否则会形成死循环.
iptables -t nat -A SHADOWSOCKS_TCP -d $remote_server_ip -j RETURN
# 访问来自中国的 ip, 直接返回.
iptables -t nat -A SHADOWSOCKS_TCP -p tcp -m set --match-set CHINAIPS dst -j RETURN
# 否则, 重定向到 ss-redir
iptables -t nat -A SHADOWSOCKS_TCP -p tcp -j REDIRECT --to-ports $local_redir_port

# Apply tcp rule
iptables -t nat -I PREROUTING 1 -p tcp -j SHADOWSOCKS_TCP
# 从路由器内访问时, 也是用这个 rule.
iptables -t nat -I OUTPUT 1 -p tcp -j SHADOWSOCKS_TCP

# ====================== udp rule =======================

# 只有满足下面两个条件, 才需要 udp rule

if ! modprobe xt_TPROXY; then
    echo 'Kernel not support tproxy!'
    exit 0
fi

if ! cat /opt/etc/init.d/S22shadowsocks |grep '^ARGS=' |grep -qs -e '-u'; then
    echo 'ss-redir not enable udp redir, skip UDP rule.'
    exit 0
fi

iptables -t mangle -N SHADOWSOCKS_UDP
iptables -t mangle -N SHADOWSOCKS_MARK

ip rule add fwmark 1 lookup 100
ip route add local default dev lo table 100

for i in $localips; do
    iptables -t mangle -A SHADOWSOCKS_MARK -d "$i" -j RETURN
    iptables -t mangle -A SHADOWSOCKS_UDP -d "$i" -j RETURN
done

iptables -t mangle -A SHADOWSOCKS_MARK -d $remote_server_ip -j RETURN

# 猜测:
# 1. 这一步执行真正的 set-mark 操作.
# 2. 所有目的地 ip 为 8.8.8.8, 端口为 53 的数据包都将会 setmark 1.
# 3. 这意味着所有的 DNS 数据包都被发往 ss-redir 端口 在 VPS 使用 8.8.8.8 来解析.
iptables -t mangle -A SHADOWSOCKS_MARK -p udp -d 8.8.8.8 --dport 53 -j MARK --set-mark 1

# 几个需要澄清的地方:
# 1. --dport 53 -d 8.8.8.8 这些是相对于宿主机来说的, 即: client.
# 2. TPROXY only works in iptables PREROUTING-chain, 即: 在数据包进入路由器时, 使用 tproxy 进行代理.

# 猜测:
# 1. 这条规则, 在数据包进入路由器时被应用.
# 2. --dport 53, 表示进入的包, 目标端口是 53, 也就是 DNS 包.
# 3. --on-ip 192.168.50.1, 表示进入的包, 目标 ip 就是路由器的地址, 即: 192.168.50.1
# 4. --on-port 是 tproxy 模块要代理到的目标, 这里是 1080, 没错了, 它和 --tproxy-mark 0x01/0x01
#    一起配合工作, 表示, 如果有数据包被 mark 为 0x01/0x01, 就转发到 1080 端口
#    这一步, 只是完成了 tproxy 代理的策略, 并没有任何 set mark 操作发生.
iptables -t mangle -A SHADOWSOCKS_UDP -p udp --dport 53 -j TPROXY --on-port 1080 --on-ip $local_redir_ip --tproxy-mark 0x01/0x01

# apply udp rule

# -A 链名 表示新增(append)一条规则到该链, 该规则增加在原本存在规则的最后面.
# 换成 -I 链名 1, 则新插入的规则变为第一条规则.
iptables -t mangle -A PREROUTING -p udp -j SHADOWSOCKS_UDP
iptables -t mangle -A OUTPUT -p udp -j SHADOWSOCKS_MARK
