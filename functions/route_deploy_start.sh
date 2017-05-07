function deploy_start {
    if [ -z "$target" ]; then
        echo "请指定你的路由器 IP 地址作为参数, 例如: ./$(basename $0) admin@192.168.1.1"
        exit
    fi

    local preinstall="$(cat ${0%/*}/functions/$FUNCNAME.sh |sed -e "1,/^export -f $FUNCNAME/d")
$export_hooks
export target=$target
export targetip=$(echo $target |cut -d'@' -f2)
echo '***********************************************************'
echo Remote deploy scripts is started !!
echo '***********************************************************'
set -ue
"
    local deploy_script="$preinstall$(cat $0 |sed -e "1,/^\s*$FUNCNAME/d")"

    if ! [ "$SSH_CLIENT$SSH_TTY" ]; then
        set -ue
        scp -r route/* $target:/
        ssh $target 'opkg install bash'
        ssh $target /opt/bin/bash <<< "$deploy_script"
        exit 0
    fi
}

export -f deploy_start

function add_service {
    [ -e /jffs/scripts/$1 ] || echo '#!/bin/sh' > /jffs/scripts/$1
    chmod +x /jffs/scripts/$1
    fgrep -qs -e "$2" /jffs/scripts/$1 || echo "$2" >> /jffs/scripts/$1
}

function regexp_escape () {
    sed -e 's/[]\/$*.^|[]/\\&/g'
}

function replace_escape () {
    sed -e 's/[\/&]/\\&/g'
}

function replace_string () {
    local regexp="$(echo "$1" |regexp_escape)"
    local replace="$(echo "$2" |replace_escape)"
    local config_file=$3

    sed -i -e "s/$regexp/$replace/" "$config_file"
}

function replace_regex () {
    local regexp=$1
    local replace="$(echo "$2" |replace_escape)"
    local config_file=$3

    sed -i -e "s/$regexp/$replace/" "$config_file"
}

function __export () {
    export_hooks="$export_hooks $@"
    builtin export "$@"
}
alias export=__export
