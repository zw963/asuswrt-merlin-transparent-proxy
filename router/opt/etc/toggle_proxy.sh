#!/bin/sh

function disable_proxy () {
    echo '[0m[33mDisable proxy ...[0m'

    /opt/etc/clean_iptables_rule.sh
    chmod -x /opt/etc/apply_iptables_rule.sh

    sed -i "s#conf-dir=/opt/etc/dnsmasq.d/,\*\.conf#\# &#" /etc/dnsmasq.conf
    /opt/etc/restart_dnsmasq

    echo '[0m[33mProxy is disabled.[0m'
}

function enable_proxy () {
    echo '[0m[33mEnable proxy ...[0m'

    chmod +x /opt/etc/apply_iptables_rule.sh && /opt/etc/apply_iptables_rule.sh

    sed -i "s#\# \(conf-dir=/opt/etc/dnsmasq.d/,\*\.conf\)#\\1#" /etc/dnsmasq.conf
    /opt/etc/restart_dnsmasq

    echo '[0m[33mProxy is enabled.[0m'
}

if [ "$1" == 'disable' ]; then
    disable_proxy
elif [ "$1" == 'enable' ]; then
    enable_proxy
elif [ -x /opt/etc/apply_iptables_rule.sh ]; then
    disable_proxy
else
    enable_proxy
fi
