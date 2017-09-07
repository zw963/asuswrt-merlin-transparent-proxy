#!/bin/sh

# use /opt/etc/iptables_disable.sh to restore iptables
[ -f /opt/etc/iptables.rules ] || iptables-save > /opt/etc/iptables.rules

ipset_protocal_version=$(ipset -v |grep -o 'version.*[0-9]' |head -n1 |cut -d' ' -f2)

if [ "$ipset_protocal_version" == 6 ]; then
    alias iptables='/usr/sbin/iptables'
    modprobe ip_set
    modprobe ip_set_hash_net
    modprobe ip_set_hash_ip
    modprobe xt_set
else
    alias iptables='/opt/sbin/iptables'
    modprobe ip_set
    modprobe ip_set_nethash
    modprobe ip_set_iphash
    modprobe ipt_set
fi

localips=$(cat /opt/etc/localips)
ipset -N FREEWEB iphash

# ====================== tcp rule =======================

# tcp rule is worked, great!
# when `w3m www.baidu.com', use direct connect,  when `w3m www.google.com', use ss-redir.
iptables -t nat -N SHADOWSOCKS_TCP

for i in $localips; do
    iptables -t nat -A SHADOWSOCKS_TCP -d "$i" -j RETURN
done

iptables -t nat -A SHADOWSOCKS_TCP -d REMOTE_SERVER_IP -j RETURN
iptables -t nat -A SHADOWSOCKS_TCP -p tcp -m set --match-set FREEWEB dst -j RETURN
iptables -t nat -A SHADOWSOCKS_TCP -p tcp -j REDIRECT --to-ports LOCAL_REDIR_PORT

# Apply tcp rule
iptables -t nat -I PREROUTING 1 -p tcp -j SHADOWSOCKS_TCP

# ====================== udp rule =======================

if ! modprobe xt_TPROXY; then
    echo 'Kernel not support tproxy!'
    exit
fi

if ! cat /opt/etc/init.d/S22shadowsocks |grep '^ARGS=' |grep -qs -e '-u'; then
    echo 'ss-redir not enable udp redir!'
    exit
fi

iptables -t mangle -N SHADOWSOCKS_UDP
iptables -t mangle -N SHADOWSOCKS_MARK

ip rule add fwmark 1 lookup 100
ip route add local default dev lo table 100

for i in $localips; do
    iptables -t mangle -A SHADOWSOCKS_MARK -d "$i" -j RETURN
    iptables -t mangle -A SHADOWSOCKS_UDP -d "$i" -j RETURN
done

iptables -t mangle -A SHADOWSOCKS_MARK -d REMOTE_SERVER_IP -j RETURN
iptables -t mangle -A SHADOWSOCKS_MARK -p udp -d 8.8.8.8 --dport 53 -j MARK --set-mark 1

# iptables -t mangle -A SHADOWSOCKS_UDP -p udp -m set --match-set FREEWEB dst -j RETURN
iptables -t mangle -A SHADOWSOCKS_UDP -p udp --dport 53 -j TPROXY -d 8.8.8.8 --on-port 1080 --on-ip 192.168.50.1 --tproxy-mark 0x01/0x01

# apply udp rule
iptables -t mangle -A PREROUTING -p udp -j SHADOWSOCKS_UDP
iptables -t mangle -A OUTPUT -p udp -j SHADOWSOCKS_MARK
