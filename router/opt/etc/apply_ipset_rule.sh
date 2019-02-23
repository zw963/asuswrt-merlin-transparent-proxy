#!/bin/sh

echo '[0m[33mApply ipset rule ...[0m'

if [ "$ipset_protocal_version" == 6 ]; then
    modprobe ip_set
    modprobe ip_set_hash_net
    modprobe ip_set_hash_ip
    modprobe xt_set
    # 默认值 hashsize 1024 maxelem 65536, 已经足够了.
    ipset -N CHINAIPS hash:net
    ipset -N CHINAIP hash:ip
    alias ipset_add_chinaip='ipset add CHINAIP'
    alias ipset_add_chinaips='ipset add CHINAIPS'
else
    modprobe ip_set
    modprobe ip_set_nethash
    modprobe ip_set_iphash
    modprobe ipt_set
    # v4 document: https://people.netfilter.org/kadlec/ipset/ipset.man.html
    ipset -N CHINAIPS nethash
    ipset -N CHINAIP iphash
    alias ipset_add_chinaip='ipset -q -A CHINAIP'
    alias ipset_add_chinaips='ipset -q -A CHINAIPS'
fi

OLDIFS="$IFS" && IFS=$'\n'
if ipset -L CHINAIPS &>/dev/null; then
    # 将国内的 ip 全部加入 ipset CHINAIPS, 近 8000 条, 这个过程可能需要近一分钟时间.
    count=$(ipset -L CHINAIPS |wc -l)

    if [ "$count" -lt "8000" ]; then
        echo '[0m[33mApplying China ipset rule, it maybe take several minute to finish ...[0m'

        for ip in $(cat /opt/etc/chinadns_chnroute.txt |grep -v '^#'); do
            ipset_add_chinaips $ip
        done

        for ip in $(cat /opt/etc/localips|grep -v '^#'); do
            ipset_add_chinaips $ip
        done
    fi
fi

remote_server_ip=$(cat /opt/etc/shadowsocks.json |grep 'server"' |cut -d':' -f2|cut -d'"' -f2)

if ipset -L CHINAIP; then
    ipset_add_chinaip 202.12.29.205 # ftp.apnic.net
    ipset_add_chinaip 81.4.123.217 # entware
    ipset_add_chinaip 151.101.76.133 # raw.githubusercontent.com
    ipset_add_chinaip 151.101.40.133 # raw.githubusercontent.com
    ipset_add_chinaip $remote_server_ip # vps ip address, 如果访问 VPS 地址, 无需跳转, 直接返回, 否则会形成死循环.

    # user_ip_whitelist.txt 格式示例:
    # 81.4.123.217 # entware 的地址 (注释可选)
    if [ -e /opt/etc/user_ip_whitelist.txt ]; then
        for ip in $(cat /opt/etc/user_ip_whitelist.txt|grep -v '^#'); do
            ipset_add_chinaip $ip
        done
    fi
fi
IFS=$OLDIFS

echo '[0m[33mApply ipset rule done.[0m'
