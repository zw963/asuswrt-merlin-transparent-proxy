#!/bin/sh

ROOT=${0%/*}

cd $ROOT
ss_config_files=$(ls -1t shadowsocks.* |grep -v shadowsocks.json)

echo 'select one number:'
echo "$ss_config_files" |grep -n '.*'

while read 'selected_number'; do
    selected_config=$(echo "$ss_config_files" |sed -n "${selected_number}p")
    if [ -e "$selected_config" ]; then
        echo "Using config [0m[33m${selected_config}[0m."
        ln -sf "$selected_config" shadowsocks.json
        ./patch_router
        exit
    else
        echo 'config not exist.'
    fi
done
