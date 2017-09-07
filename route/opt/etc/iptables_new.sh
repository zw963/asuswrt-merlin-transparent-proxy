#!/bin/sh

localips=$(cat /opt/etc/localips)

# ====================== tcp rule =======================

# tcp rule is worked, great!
# when `w3m www.baidu.com', use direct connect,  when `w3m www.google.com', use ss-redir.
iptables -t nat -N SHADOWSOCKS
ipset -N FREEWEB iphash

for i in $localips; do
    iptables -t nat -A SHADOWSOCKS -d "$i" -j RETURN
done

iptables -t nat -A SHADOWSOCKS -d REMOTE_SERVER_IP -j RETURN
iptables -t nat -A SHADOWSOCKS -p tcp -m set --match-set FREEWEB dst -j RETURN
iptables -t nat -A SHADOWSOCKS -p tcp -j REDIRECT --to-ports LOCAL_REDIR_PORT
iptables -t nat -I PREROUTING 1 -p tcp -j SHADOWSOCKS

# ====================== udp rule =======================

ip rule add fwmark 1 lookup 100
ip route add local 0.0.0.0/0 dev lo table 100

iptables -t mangle -N SHADOWSOCKS
iptables -t mangle -N SHADOWSOCKS_MARK

for i in $localips; do
    iptables -t mangle -A SHADOWSOCKS_MARK -d "$i" -j RETURN
    iptables -t mangle -A SHADOWSOCKS -d "$i" -j RETURN
done

iptables -t mangle -A SHADOWSOCKS_MARK -d REMOTE_SERVER_IP -j RETURN
iptables -t mangle -A SHADOWSOCKS_MARK -d 8.8.8.8 -p udp --dport 53 -j MARK --set-mark 1

# next line rule not worked. `w3m www.baidu.com', DNS forward to ss-redir, but what we expect is direct conn.
iptables -t mangle -A SHADOWSOCKS -p udp -m set --match-set FREEWEB dst -j RETURN

iptables -t mangle -A SHADOWSOCKS -p udp --dport 53 -j TPROXY -d 8.8.8.8  --on-port LOCAL_REDIR_PORT --tproxy-mark 0x01/0x01

iptables -t mangle -A PREROUTING -p udp -j SHADOWSOCKS
iptables -t mangle -A OUTPUT -p udp -j SHADOWSOCKS_MARK
