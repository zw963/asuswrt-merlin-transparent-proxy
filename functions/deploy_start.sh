function deploy_start {
    if [ -z "$target" ]; then
        echo '请指定 $target 变量为路由器的 ip 地址'
        exit
    fi
    
    local preinstall
    read -r -d '' preinstall <<-'HERE'
function add_service {
    [ -e /jffs/scripts/$1 ] || echo '#!/bin/sh' > /jffs/scripts/$1
    chmod +x /jffs/scripts/$1
    fgrep -qs -e "$2" /jffs/scripts/$1 || echo "$2" >> /jffs/scripts/$1
    /jffs/scripts/$1
}

function regexp_escape () {
    sed -e 's/[]\/$*.^|[]/\\&/g'
}

function replace_escape () {
    sed -e 's/[\/&]/\\&/g'
}

function replace_string () {
    local regexp="$(echo "$1" |regexp_escape)"
    local replace="$(echo "$2"|replace_escape)"
    local config_file=$3

    sed -i -e "s/$regexp/$replace/" $config_file
}

function replace_regex () {
    local regexp=$1
    local replace="$(echo "$2"|replace_escape)"
    local config_file=$3

    sed -i -e "s/$regexp/$replace/" $config_file
}
HERE

    preinstall=$'\n'$preinstall$'\n'"
export target=$target
export targetip=$(echo $target |cut -d'@' -f2)
set -ue
"
    deploy_script="$preinstall$(cat $0 |sed -e "1,/^$FUNCNAME/d")"
    
    if ! [ "$SSH_CLIENT$SSH_TTY" ]; then
        set -ue
        ssh $target 'opkg install bash'
        ssh $target /opt/bin/bash <<< "$deploy_script"
        scp -r route/* $target:/
        exit 0
    fi
}

export -f deploy_start
