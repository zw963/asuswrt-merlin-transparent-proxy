#!/bin/sh

function deploy_start {
    local dir

    if [ "$*" ]; then
        dir=$*
    else
        dir="$0_deploy"
    fi

    if [[ "$target" =~ [-_.[:alnum:]]+@.+ ]]; then
        target=${BASH_REMATCH[0]}
    elif [[ "$target" =~ [a-zA-Z0-9_.]+ ]]; then
        # 域名
        target=${BASH_REMATCH[0]}
    elif [[ "$target" == localhost ]]; then
        target=$target
    else
        echo "\`\$target' variable must be provided in your's scripts before $FUNCNAME."
        echo 'e.g. target=localhost or target=root@123.123.123.123'
        exit
    fi

    local preinstall="$(cat $FUNCTION_PATH/$FUNCNAME.sh |sed -e "1,/^export -f $FUNCNAME/d")
$export_hooks
export target=$target
export targetip=$(echo $target |cut -d'@' -f2)
sudo=$sudo
_modifier=$USER
echo '***********************************************************'
echo Remote deploy scripts is started !!
echo '***********************************************************'
set -ue
"
    local deploy_script="$preinstall$(cat $0 |sed -e "1,/^\s*$FUNCNAME/d")"

    if ! [ "$SSH_CLIENT$SSH_TTY" ]; then
        set -u

        if [ "$target" == localhost ]; then
            # 本地部署
            command='bash -c'
            if [ $EUID == 0 ]; then
                sudo=''
            else
                sudo='sudo'
            fi
            target=''
        else
            # 远程部署使用 ssh 远程执行。
            command="ssh $target"
            target=$target:
            sudo=''
        fi

        # 仅当目录中存在文件时, 才拷贝文件。
        [ -d "$dir" ] &&
            find "$dir/" -type f ! -name '.gitkeep' &>/dev/null &&
            $sudo rsync --recursive --copy-links --perms --times --update \
                  --verbose --human-readable -P \
                  --exclude '.*.*~' --rsh=ssh "$dir/" $target/
        $command "$deploy_script"
        exit 0
    fi
}

export -f deploy_start

function append () {
    sed '$a'"$*"
}

function prepend () {
    sed "1i$*"
}

function rsync () {
    # -P 等价于: --partial --progress
    $sudo command rsync --recursive --copy-links --perms --times --update --verbose \
          --human-readable -P --rsh=ssh nano/nano \
          --exclude '.*~' \
          "$@"
}

function reboot_task () {
    local exist_crontab=$(/usr/bin/crontab -l)
    if ! echo "$exist_crontab" |fgrep -qs -e "$*"; then
        echo "$exist_crontab" |append "@reboot $*" |/usr/bin/crontab -
    fi
    $*
}

function daemon () {
    local name=$1
    local command=$2

    useradd $name -s /sbin/nologin
    cat <<HEREDOC > /etc/systemd/system/$name.service
     [Unit]
     Description=$name Service
     After=network.target

     [Service]
     Type=simple
     User=$name
     ExecStart=$command
     Restart=on-abort
     LimitNOFILE=51200
     LimitCORE=infinity
     LimitNPROC=51200

     [Install]
     WantedBy=multi-user.target
HEREDOC
    systemctl daemon-reload
    systemctl start $name
    systemctl enable $name
    systemctl status $name
    # 停止和关闭的命令如下:
    # systemctl stop shadowsocks
    # systemctl disable shadowsocks
}

function clone () {
    git clone --depth=5 "$@"
}

function wait () {
    echo "Waiting $* to exit ..."
    while pgrep "^$*\$" &>/dev/null; do
        echo -n '.'
        sleep 0.3
    done
    echo "$* is terminated."
}

function append_file () {
    local content regexp file
    file=$1

    if [ "$#" == 2 ]; then
        content=$2
    elif [ "$#" == 1 ]; then
        content=$(cat /dev/stdin) # 从管道内读取所有内容.
    fi
    regexp=$(echo "$content" |regexp_escape)


    # unless expected config exist, otherwise append config to last line.
    if ! grep "^\\s*${regexp}\\s*" "$file"; then
        # echo -e "\n#= Add by ${_modifier-$USER} =#" >> "$file"
        echo "$content" >> "$file"
        echo "[0m[33mAppend \`$content' into $file[0m"
    fi
}

function prepend_file () {
    local content regexp file
    file=$1

    if [ "$#" == 2 ]; then
        content=$2
    elif [ "$#" == 1 ]; then
        content=$(cat /dev/stdin) # 从管道内读取所有内容.
    fi
    regexp=$(echo "$content" |regexp_escape)
    content_escaped=$(echo "$content" |replace_escape)

    if ! grep "^\\s*${regexp}\\s*" "$file"; then
        $sudo sed -i 1i"$content_escaped" "$file"
        echo "[0m[33mPrepend \`$content' into $file[0m"
    fi
}

# 转义一个字符串中的所有 grep 元字符.
function regexp_escape () {
    sed -e 's/[]\/$*.^|[]/\\&/g'
}

# 这是支持 replace string 存在换行, 以及各种元字符的版本.
# 详细信息,  读这个答案: https://stackoverflow.com/a/29613573/749774
function replace_escape() {
    IFS= read -d '' -r < <(sed -e ':a' -e '$!{N;ba' -e '}' -e 's/[&/\]/\\&/g; s/\n/\\&/g')
    printf %s "${REPLY%$'\n'}"
}

function replace () {
    local regexp replace file content
    regexp=$1
    replace="$(echo "$2" |replace_escape)"
    file=$3

    if content=$(grep -o -e "$regexp" "$file"); then
        $sudo sed -i -e "s/$regexp/$replace/" "$file"
        echo "\`[0m[33m$content[0m' is replaced with \`[0m[33m$replace[0m' for $file"
    fi
}

function replace_regex () {
    local regexp=$1
    local replace=$2
    local config_file=$3

    replace "$regexp" "$replace" "$config_file"
}

function replace_string () {
    local string=$1
    local regexp="$(echo "$string" |regexp_escape)"
    local replace=$2
    local config_file=$3

    replace "$regexp" "$replace" "$config_file"

    # only matched string exist, replace with new string.
    # if matched_line=$(grep -s "$regexp" $config_file|tail -n1) && test -n "$matched_line"; then
    #     local matched_line_regexp=$(echo "$matched_line" |regexp_escape)
    #     local replaced_line=$(echo "$matched_line"|sed "s/$regexp/$replace_string/")

    #     # sed -i -e "s/^${matched_line_regexp}$/\n#= &\n#= Above config-default value is replaced by following config value. $(date '+%Y-%m-%d %H:%M:%S') by ${_modifier-$USER}\n$replaced_line/" $config_file
    #     sed -i -e "s/^${matched_line_regexp}$/$replaced_line/" $config_file

    #     echo "\`$old_string' is replaced in $config_file."
    # fi
}

function update_config () {
    local config_key=$1
    local config_value=$2
    local config_file=$3
    local delimiter=${4-=}
    local regexp="^\\s*$(echo "$config_key" |regexp_escape)\b"
    local matched_line matched_line_regexp old_value old_value_regexp replaced_line group

    # only if config key exist, update it.
    if matched_line=$(grep -s "$regexp" $config_file|tail -n1) && test -n "$matched_line"; then
        matched_line_regexp=$(echo "$matched_line" |regexp_escape)
        old_value=$(echo  "$matched_line" |tail -n1|cut -d"$delimiter" -f2)

        if [[ "$old_value" =~ \"(.*)\" ]]; then
            [ "${BASH_REMATCH[1]}" ] && group="${BASH_REMATCH[1]}"
            set +ue
            replaced_line=$(echo $matched_line |sed -e "s/${old_value}/\"${group}${group+ }$config_value\"/")
            set -ue
        else
            replaced_line=$(echo $matched_line |sed -e "s/${old_value}/& $config_value/")
        fi

        regexp="^${matched_line_regexp}$"
        replace="\n#= &\n#= Above config-default value is replaced by following config value. $(date '+%Y-%m-%d %H:%M:%S') by ${_modifier-$USER}\n$replaced_line"
        replace "$regexp" "$replace" "$config_file"
        # echo "Append \`$config_value' to \`$old_value' for $config_file $matched_line"
    fi
}

function configure () {
    set +u
    if [ ! "$1" ]; then
        echo 'Need one argument to sign this package. e.g. package name.'
        exit
    fi

    ./configure --build=x86_64-linux-gnu \
                --prefix=/usr \
                --exec-prefix=/usr \
                '--bindir=$(prefix)/bin' \
                '--sbindir=$(prefix)/sbin' \
                '--libdir=$(prefix)/lib64' \
                '--libexecdir=$(prefix)/lib64/$1' \
                '--includedir=$(prefix)/include' \
                '--datadir=$(prefix)/share/$1' \
                '--mandir=$(prefix)/share/man' \
                '--infodir=$(prefix)/share/info' \
                --localstatedir=/var \
                '--sysconfdir=/etc/$1' \
                ${@:2}
}

function wget () {
    local url=$1
    local file=$(basename $url)
    command wget --no-check-certificate -c $url -O $file
}
function download_and_extract () {
    local ext=$( basename "$*" |rev|cut -d'.' -f1|rev)
    local wget='wget --no-check-certificate -c'
    case $ext in
        gz)
            $wget -O - "$*" |tar zxvf -
            ;;
        bz2)
            $wget -O - "$*" |tar jxvf -
            ;;
        xz)
            $wget -O - "$*" |tar Jxvf -
            ;;
        lzma)
            $wget -O - "$*" |tar --lzma -xvf -
            ;;
        rar)
            $wget "$*" && unrar x "$*"
            ;;
        zip)
            $wget "$*" && unzip "$*"
    esac

}

function diff () {
    command diff -q "$@" >/dev/null
}

function sshkeygen () {
    ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ''
}

# function rc.local () {
#     local conf=/etc/rc.local

#     fgrep -qs "$*" $conf || echo "$*" >> $conf
#     chmod +x $conf
#     # $*
# }

function expose_port () {
    for port in "$@"; do
        if grep -qs 'Ubuntu\|Mint|Debian' /etc/issue; then
            rc.local "iptables -I INPUT -p tcp --dport $port -j ACCEPT"
            rc.local "iptables -I INPUT -p udp --dport $port -j ACCEPT"
        elif grep -qs CentOS /etc/redhat-release; then
            firewall-cmd --zone=public --add-port=$port/tcp --permanent
            firewall-cmd --zone=public --add-port=$port/udp --permanent
            firewall-cmd --reload   # 这个只在 --permanent 参数存在时, 才需要
            # firewall-cmd --zone=public --list-ports
        elif grep -qs openSUSE /etc/issue; then
            yast firewall services add tcpport=$port zone=EXT
        fi
    done
}

function package () {
    local install zlib pcre apache2_utils
    local compile_tools='gcc autoconf automake make libtool bzip2 unzip patch wget curl perl'
    local basic_tools='mlocate git tree'

    if grep -qs 'Ubuntu\|Mint|Debian' /etc/issue; then
        $sudo apt-get update
        install="$sudo apt-get install -y --no-install-recommends"
    elif grep -qs CentOS /etc/redhat-release; then
        # if Want get centos version, use `rpm -q centos-release'.
        install="$sudo yum install -y"
    elif grep -qs openSUSE /etc/issue; then
        install="$sudo zypper -n in --no-recommends"
    fi

    installed=
    for i in "$@"; do
        if grep -qs 'Ubuntu\|Mint|Debian' /etc/issue; then
            case "$i" in
                zlib-devel)
                    installed="$installed zlib1g-dev"
                    ;;
                pcre-devel)
                    installed="$installed libpcre3-dev"
                    ;;
                libsodium-devel)
                    installed="$installed libsodium-dev"
                    ;;
                udns-devel)
                    installed="$installed libudns-dev"
                    ;;
                libev-devel)
                    installed="$installed libev-dev"
                    ;;
                mbedtls-devel)
                    installed="$installed libmbedtls-dev"
                    ;;
                compile-tools)
                    installed="$installed $compile_tools libssl-dev g++ xz-utils"
                    ;;
                basic-tools)
                    installed="$installed $basic_tools"
                    ;;
                *)
                    installed="$installed $i"
            esac
        elif grep -qs CentOS /etc/redhat-release; then
            case "$i" in
                compile-tools)
                    installed="$installed $compile_tools openssl-devel gcc-c++ xz"
                    ;;
                basic-tools)
                    installed="$installed $basic_tools yum-cron yum-utils"
                    ;;
                apache2-utils)
                    installed="$installed httpd-tools"
                    ;;
                *)
                    installed="$installed $i"
            esac
        elif grep -qs openSUSE /etc/issue; then
            case "$i" in
                compile-tools)
                    installed="$installed $compile_tools openssl-devel gcc-c++ xz"
                    ;;
                basic-tools)
                    installed="$installed $basic_tools"
                    ;;
                *)
                    installed="$installed $i"
            esac
        fi
    done

    $install $installed
}

# only support define a bash variable, bash array variable not supported.
function __export () {
    local name=$(echo "$*" |cut -z -d'=' -f1)
    local value=$(echo "$*" |cut -z -d'=' -f2-)
    local escaped_value=$(echo "$value" |sed 's#\([\$"`]\)#\\\1#g')

    eval 'builtin export $name="$value"'
    export_hooks="$export_hooks builtin export $name=\"$escaped_value\""
}

alias export=__export
