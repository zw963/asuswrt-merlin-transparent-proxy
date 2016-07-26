#!/bin/sh

if /opt/sbin/ipset -N FREEWEB iphash; then
    if /opt/sbin/iptables -t nat -N SHADOWSOCKS; then
        /opt/sbin/iptables -t nat -A SHADOWSOCKS -d 0.0.0.0/8 -j RETURN
        /opt/sbin/iptables -t nat -A SHADOWSOCKS -d 10.0.0.0/8 -j RETURN
        /opt/sbin/iptables -t nat -A SHADOWSOCKS -d 127.0.0.0/8 -j RETURN
        /opt/sbin/iptables -t nat -A SHADOWSOCKS -d 169.254.0.0/16 -j RETURN
        /opt/sbin/iptables -t nat -A SHADOWSOCKS -d 172.16.0.0/12 -j RETURN
        /opt/sbin/iptables -t nat -A SHADOWSOCKS -d 192.168.0.0/16 -j RETURN
        /opt/sbin/iptables -t nat -A SHADOWSOCKS -d 224.0.0.0/4 -j RETURN
        /opt/sbin/iptables -t nat -A SHADOWSOCKS -d 240.0.0.0/4 -j RETURN

        # 如果有很多服务器，并且所有目标服务器都是同样的端口, 用法如下
        # /opt/sbin/iptables -t nat -A SHADOWSOCKS --dport 22334 -j RETURN
        /opt/sbin/iptables -t nat -A SHADOWSOCKS -d SS_SERVER_IP -j RETURN

        /opt/sbin/iptables -t nat -A SHADOWSOCKS -m set --match-set FREEWEB dst -j RETURN

        /opt/sbin/iptables -t nat -A SHADOWSOCKS -p tcp -j REDIRECT --to-ports SS_LOCAL_PORT

        /opt/sbin/iptables -t nat -I PREROUTING -p tcp -m multiport --dports 80,443 -j SHADOWSOCKS
        /opt/sbin/iptables -t nat -I OUTPUT -p tcp -j SHADOWSOCKS
        # /opt/sbin/iptables -t nat -A SHADOWSOCKS -p tcp --syn -m connlimit --connlimit-above 32 -j RETURN
    fi
fi

# 查看 ipset
/opt/sbin/ipset -L FREEWEB
