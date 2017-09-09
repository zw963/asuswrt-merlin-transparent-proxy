# 使用华硕 merlin 架设透明代理

__Updated on 2017/09/08__

## 目的
使用目前流行的 IP白名单 方式，通过维护一份国内 IP 的列表, 实现自动翻墙的透明代理, 为合理的科学上网提供便利.

本文基于网络上大量资料整理，恕在此不一一列举，没有大量网友的无私分享，就不会有这个文章。

本部署脚本原始基于华硕(ASUS) RT-AC66U, RT-AC87U, RT-5300 架构上实测成功, 应该适合于任何支持 Entware 包管理的
Merlin 或 OpenWRT 系统, 思路是一样的。

## 需求
- 使用 ss+udprelay 部署, 要求梅林固件版本不低于: 380.68+, (需要 tproxy 支持)
- opkg 路由器包管理系统, [Entware-ng](https://github.com/Entware-ng/Entware-ng)
- ss-redir
- 一台能够使用 ssh 登陆梅林的 Linux 宿主机(母鸡), Window 下请首先安装虚拟机.
- 一定的 CLI 操作能力.

## 启用路由器的包管理系统 Entware-ng

### 寻找一个 U 盘, 容量不限, 格式化这个 U 盘到 ext3 分区.

假设你的 U 盘驱动器在 Linux 的设备为 /dev/sdd1

```sh
# mkfs.ext3 /dev/sdd1
```

__注意!! 以上操作需谨慎, 设备一定搞对, 因为这是格式化操作, 本文不对因用户不了解, 造成的任何数据丢失, 承担责任!__

### 初始化 jffs.

将 U 盘插入到路由器 U 口上, 然后登陆路由器, 按照以下提示操作:

1. 系统管理 => 系统设置
2. ``Format JFFS partition at next boot` 选择 `是`。
2. ``Enable JFFS custom scripts and configs`` 选择 `是`。
3. ``Enable SSH`` 选择 `LAN+WAN`, 或者 `LAN` 如果你只想通过网线联网时, 才登录 ssh.
4. ``SSH Authentication key``, 将你的 ``ssh公钥`` 粘帖到这里, 不懂啥是公钥, 请自行百度.
5. 最后, 点击 ``应用本页面设置``，等待提示完成后, __务必重新启动路由器__, 确保再次进来时, ``Format JFFS partition at next boot`` 选项已经恢复成 `否`.
6. 测试 ssh 登录是否成功, 假设 192.168.1.1 是你的路由器 IP:
        ```sh
        $ ssh admin@192.168.1.1
        ```
        如果出现了如下提示符, 进入下一步.
        
        ASUSWRT-Merlin RT-AC87U 380.65-0 Fri Feb  3 05:19:42 UTC 2017
        admin@RT-AC87U-4A68:/tmp/home/root# 
        admin@RT-AC87U-4A68:/tmp/home/root#
7. 键入命令 `entware-setup.sh`, 来初始化包管理系统 opkg.
```sh
admin@RT-AC66U-20F0:/tmp/home/root# entware-setup.sh
```

如果你的 U 盘分区格式没问题，这个脚本会出现类似如下提示让你选择:

```sh
admin@RT-AC66U-20F0:/tmp/mnt/sda/asusware/etc# entware-setup.sh
 Info:  This script will guide you through the Entware installation.
 Info:  Script modifies "entware" folder only on the chosen drive,
 Info:  no other data will be changed. Existing installation will be
 Info:  replaced with this one. Also some start scripts will be installed,
 Info:  the old ones will be saved on Entware partition with name
 Info:  like /tmp/mnt/sda1/jffs_scripts_backup.tgz

 Info:  Looking for available partitions...
[1] --> /tmp/mnt/sda
 =>  Please enter partition number or 0 to exit
[0-1]: 
```

此时选择 1 即可, 等待安装完成.

如果运行 `opkg --version`, 返回对应的版本信息, 表示安装成功, `exit` 退出路由器.

## 开始一键部署.

__请注意: 下面的步骤是在你的宿主机( Linux 工作电脑上)上操作, 而不是在你的路由器上.__ 

### 下载本项目到你的工作电脑上

下载 [链接](https://github.com/zw963/asuswrt-merlin-transparent-proxy/archive/master.zip).
如果你使用 mac 或 linux, 使用下面的 curl 命令就足够了.

```sh
$: curl -L https://github.com/zw963/asuswrt-merlin-transparent-proxy/archive/master.zip > transparent-proxy.zip
$: unzip transparent-proxy.zip

Archive:  transparent-proxy.zip
ee43fd6ad2aa2e890b7f792c309fa5e270442676
   creating: asuswrt-merlin-transparent-proxy-master/
  inflating: asuswrt-merlin-transparent-proxy-master/.gitignore  
  inflating: asuswrt-merlin-transparent-proxy-master/LICENSE  
  inflating: asuswrt-merlin-transparent-proxy-master/README.md  
   creating: asuswrt-merlin-transparent-proxy-master/functions/
  inflating: asuswrt-merlin-transparent-proxy-master/functions/deploy_start.sh  
  inflating: asuswrt-merlin-transparent-proxy-master/generate_dns  
   creating: asuswrt-merlin-transparent-proxy-master/route/
   creating: asuswrt-merlin-transparent-proxy-master/route/opt/
   creating: asuswrt-merlin-transparent-proxy-master/route/opt/etc/
   creating: asuswrt-merlin-transparent-proxy-master/route/opt/etc/dnsmasq.d/
 extracting: asuswrt-merlin-transparent-proxy-master/route/opt/etc/dnsmasq.d/foreign_domains.conf  
   creating: asuswrt-merlin-transparent-proxy-master/route/opt/etc/init.d/
  inflating: asuswrt-merlin-transparent-proxy-master/route/opt/etc/init.d/S22ss-tunnel  
  inflating: asuswrt-merlin-transparent-proxy-master/route/opt/etc/iptables.sh  
  inflating: asuswrt-merlin-transparent-proxy-master/route/opt/etc/patch_dnsmasq  
  inflating: asuswrt-merlin-transparent-proxy-master/route/opt/etc/restart_dnsmasq  
  inflating: asuswrt-merlin-transparent-proxy-master/ss+dnsmasq  
  inflating: asuswrt-merlin-transparent-proxy-master/ss+dnsmasq+chinadns  

```

### 新增你的 shadowsocks.json 配置脚本

首先进入项目目录

```sh
$ cd ~/asuswrt-merlin-transparent-proxy-master
```

创建 shadowsocks 配置文件 route/opt/etc/shadowsocks.json 脚本.

```sh
$ touch route/opt/etc/shadowsocks.json
```

使用编辑器打开 shadowsocks.json, 内容示例如下.

```json
// 这只是一个例子, 如果你要复制修改, 麻烦先手动删除所有 // 开头的注释!
{
  "server":"123.123.123.123",     // 这是你国外服务器地址(服务器上应该运行一个 shadowsocks server)
  "server_port": 12345,           // ss-server 监听的端口
  "local_address":"192.168.1.1",  // 确保这个地址设为你的路由器 ip 地址
  "local_port": 1080,             // 无需更改
  "password": "yours_password",   // ss-server 上设定的密码.
  "timeout":600,                  // 不用改
  "method":"aes-256-cfb"          // ss-server 上设定的加密方式
}
```

### 运行一键部署脚本自动部署.

此时有两个选择:

- ss+chinadns, 较好的兼容国内网站, 省流量, 但是某些运营商线路, 访问某些国外网站可能会比较慢,
  这是因为大部分没有被墙的网站走的是直连, 首选, 老的 MIPS 架构路由器也可用.
- ss+udprelay (仅 ARM 架构支持), 只需要 ss-redir 一个命令自己全部搞定, 如果你有很好的国外线路, 可以尝试这个. 

此时，在你的电脑上应该已经可以自动 ssh 登陆到你的路由器,
假设路由器 ip 地址是 192.168.50.1 (或域名 router.asus.com), 则在你的 `宿主电脑上` 执行以下命令.

```sh
$ ./ss+chinadns admin@192.168.50.1
```

或

```sh
$ ./ss+udprelay admin@192.168.50.1
```

等待完成, 如果无法翻墙, 按照以下方式尝试

- 断掉 WiFi 尝试再连接, 试试
- 如果 VPS 线路比较差, 等几分钟再试下, 是一个不错的建议.
- 重启路由器, 等启动完成后, 再试试.

如果还上不了, 可能部署或配置文件出了问题.

下面是 ss+chinadns 安装成功输出示例:

```
╰─ $ ./ss+chinadns admin@192.168.50.1
rsync is not installed in remote host, fallback to use scp command.
foreign_domains.conf                                                                                                                                        100%   34    13.8KB/s   00:00    
iptables.sh                                                                                                                                                 100% 4496     1.5MB/s   00:00    
iptables_disable.sh                                                                                                                                         100%  358   147.3KB/s   00:00    
patch_dnsmasq                                                                                                                                               100%  389   161.4KB/s   00:00    
restart_dnsmasq                                                                                                                                             100%   84    21.8KB/s   00:00    
shadowsocks.json                                                                                                                                            100%  195    80.3KB/s   00:00    
S22ss-tunnel                                                                                                                                                100%  261   100.0KB/s   00:00    
localips                                                                                                                                                    100%  265   114.4KB/s   00:00    
update_ip_whitelist                                                                                                                                         100%  488   191.0KB/s   00:00    
chinadns_chnroute.txt                                                                                                                                       100%  121KB   3.6MB/s   00:00    
remote host missing bash, try to install it...
Installing bash (4.3.42-1a) to root...
Downloading http://pkg.entware.net/binaries/armv7/bash_4.3.42-1a_armv7soft.ipk
Installing libncurses (6.0-1c) to root...
Downloading http://pkg.entware.net/binaries/armv7/libncurses_6.0-1c_armv7soft.ipk
Installing libncursesw (6.0-1c) to root...
Downloading http://pkg.entware.net/binaries/armv7/libncursesw_6.0-1c_armv7soft.ipk
Configuring libncursesw.
Configuring libncurses.
Configuring bash.
***********************************************************
Remote deploy scripts is started !!
***********************************************************
Downloading http://pkg.entware.net/binaries/armv7/Packages.gz
Updated list of available packages in /opt/var/opkg-lists/packages
Package libc (2.23-6) installed in root is up to date.
Package libssp (6.3.0-6) installed in root is up to date.
Installing libev (4.22-1) to root...
Downloading http://pkg.entware.net/binaries/armv7/libev_4.22-1_armv7soft.ipk
Installing libmbedtls (2.4.2-1) to root...
Downloading http://pkg.entware.net/binaries/armv7/libmbedtls_2.4.2-1_armv7soft.ipk
Installing libpcre (8.40-2) to root...
Downloading http://pkg.entware.net/binaries/armv7/libpcre_8.40-2_armv7soft.ipk
Package libpthread (2.23-6) installed in root is up to date.
Installing libsodium (1.0.12-1) to root...
Downloading http://pkg.entware.net/binaries/armv7/libsodium_1.0.12-1_armv7soft.ipk
Installing haveged (1.9.1-5) to root...
Downloading http://pkg.entware.net/binaries/armv7/haveged_1.9.1-5_armv7soft.ipk
Installing libhavege (1.9.1-5) to root...
Downloading http://pkg.entware.net/binaries/armv7/libhavege_1.9.1-5_armv7soft.ipk
Installing zlib (1.2.11-1) to root...
Downloading http://pkg.entware.net/binaries/armv7/zlib_1.2.11-1_armv7soft.ipk
Installing libopenssl (1.0.2k-1) to root...
Downloading http://pkg.entware.net/binaries/armv7/libopenssl_1.0.2k-1_armv7soft.ipk
Configuring libev.
Configuring libpcre.
Configuring libmbedtls.
Configuring libsodium.
Configuring libhavege.
Configuring haveged.
Configuring zlib.
Configuring libopenssl.
Installing shadowsocks-libev (3.0.6-1) to root...
Downloading http://pkg.entware.net/binaries/armv7/shadowsocks-libev_3.0.6-1_armv7soft.ipk
Installing libudns (0.4-1) to root...
Downloading http://pkg.entware.net/binaries/armv7/libudns_0.4-1_armv7soft.ipk
Collected errors:
 * resolve_conffiles: Existing conffile /opt/etc/shadowsocks.json is different from the conffile in the new package. The new conffile will be placed at /opt/etc/shadowsocks.json-opkg.
Configuring libudns.
Configuring shadowsocks-libev.
Installing chinadns (1.3.2-20150812-1) to root...
Downloading http://pkg.entware.net/binaries/armv7/chinadns_1.3.2-20150812-1_armv7soft.ipk
Collected errors:
 * resolve_conffiles: Existing conffile /opt/etc/chinadns_chnroute.txt is different from the conffile in the new package. The new conffile will be placed at /opt/etc/chinadns_chnroute.txt-opkg.
Configuring chinadns.
skip install iptables
`"local_address":"192.168.50.1",' is replaced with `"local_address":"192.168.50.1",' for /opt/etc/shadowsocks.json
`UPSTREAM_PORT' is replaced with `5356' for /opt/etc/dnsmasq.d/foreign_domains.conf
`5353' is replaced with `5356 -b 127.0.0.1 -s 114.114.114.114,127.0.0.1:1082,8.8.4.4' for /opt/etc/init.d/S56chinadns
`ss-local' is replaced with `ss-redir' for /opt/etc/init.d/S22shadowsocks
 Checking chinadns...              dead. 
 Checking ss-tunnel...              dead. 
 Checking ss-redir...              dead. 
 Checking haveged...              dead. 
 Starting haveged...              done. 
 Starting ss-redir...              done. 
 Starting ss-tunnel...              done. 
 Starting chinadns...              done. 
dnsmasq: syntax check OK.
Applying iptables rule ...
ss-redir not enable udp redir!
```

下面是 ss+udprelay 安装成功示例:

```
╰─ $ ./ss+udprelay admin@192.168.50.1
rsync is not installed in remote host, fallback to use scp command.
foreign_domains.conf                                                                                                                                        100%   34    13.9KB/s   00:00    
iptables.sh                                                                                                                                                 100% 4534     1.3MB/s   00:00    
iptables_disable.sh                                                                                                                                         100%  358   141.2KB/s   00:00    
patch_dnsmasq                                                                                                                                               100%  389   155.5KB/s   00:00    
restart_dnsmasq                                                                                                                                             100%   84    36.6KB/s   00:00    
shadowsocks.json                                                                                                                                            100%  195    68.1KB/s   00:00    
localips                                                                                                                                                    100%  265   109.0KB/s   00:00    
update_ip_whitelist                                                                                                                                         100%  488   179.2KB/s   00:00    
chinadns_chnroute.txt                                                                                                                                       100%  121KB 923.1KB/s   00:00    
remote host missing bash, try to install it...
Installing bash (4.3.42-1a) to root...
Downloading http://pkg.entware.net/binaries/armv7/bash_4.3.42-1a_armv7soft.ipk
Installing libncurses (6.0-1c) to root...
Downloading http://pkg.entware.net/binaries/armv7/libncurses_6.0-1c_armv7soft.ipk
Installing libncursesw (6.0-1c) to root...
Downloading http://pkg.entware.net/binaries/armv7/libncursesw_6.0-1c_armv7soft.ipk
Configuring libncursesw.
Configuring libncurses.
Configuring bash.
***********************************************************
Remote deploy scripts is started !!
***********************************************************
Downloading http://pkg.entware.net/binaries/armv7/Packages.gz
Updated list of available packages in /opt/var/opkg-lists/packages
Package libc (2.23-6) installed in root is up to date.
Package libssp (6.3.0-6) installed in root is up to date.
Installing libev (4.22-1) to root...
Downloading http://pkg.entware.net/binaries/armv7/libev_4.22-1_armv7soft.ipk
Installing libmbedtls (2.4.2-1) to root...
Downloading http://pkg.entware.net/binaries/armv7/libmbedtls_2.4.2-1_armv7soft.ipk
Installing libpcre (8.40-2) to root...
Downloading http://pkg.entware.net/binaries/armv7/libpcre_8.40-2_armv7soft.ipk
Package libpthread (2.23-6) installed in root is up to date.
Installing libsodium (1.0.12-1) to root...
Downloading http://pkg.entware.net/binaries/armv7/libsodium_1.0.12-1_armv7soft.ipk
Installing haveged (1.9.1-5) to root...
Downloading http://pkg.entware.net/binaries/armv7/haveged_1.9.1-5_armv7soft.ipk
Installing libhavege (1.9.1-5) to root...
Downloading http://pkg.entware.net/binaries/armv7/libhavege_1.9.1-5_armv7soft.ipk
Installing zlib (1.2.11-1) to root...
Downloading http://pkg.entware.net/binaries/armv7/zlib_1.2.11-1_armv7soft.ipk
Installing libopenssl (1.0.2k-1) to root...
Downloading http://pkg.entware.net/binaries/armv7/libopenssl_1.0.2k-1_armv7soft.ipk
Configuring libev.
Configuring libpcre.
Configuring libmbedtls.
Configuring libsodium.
Configuring libhavege.
Configuring haveged.
Configuring zlib.
Configuring libopenssl.
Installing shadowsocks-libev (3.0.6-1) to root...
Downloading http://pkg.entware.net/binaries/armv7/shadowsocks-libev_3.0.6-1_armv7soft.ipk
Installing libudns (0.4-1) to root...
Downloading http://pkg.entware.net/binaries/armv7/libudns_0.4-1_armv7soft.ipk
Collected errors:
 * resolve_conffiles: Existing conffile /opt/etc/shadowsocks.json is different from the conffile in the new package. The new conffile will be placed at /opt/etc/shadowsocks.json-opkg.
Configuring libudns.
Configuring shadowsocks-libev.
skip install iptables
`"local_address":"192.168.50.1",' is replaced with `"local_address":"192.168.50.1",' for /opt/etc/shadowsocks.json
`127.0.0.1#UPSTREAM_PORT' is replaced with `8.8.8.8#53' for /opt/etc/dnsmasq.d/foreign_domains.conf
`ARGS="-c /opt/etc/shadowsocks.json"' is replaced with `ARGS="-u -c \/opt\/etc\/shadowsocks.json"' for /opt/etc/init.d/S22shadowsocks
`ss-local' is replaced with `ss-redir' for /opt/etc/init.d/S22shadowsocks
 Checking ss-redir...              dead. 
 Checking haveged...              dead. 
 Starting haveged...              done. 
 Starting ss-redir...              done. 
dnsmasq: syntax check OK.
Applying iptables rule, it may take several minute to finish ...
```


## 手动部署

如果你不想配置 SSH 自动登录, 又对这个脚本做了什么不太放心, 你可以选择手动部署.

1. 请首先尝试读懂部署脚本中的命令在干什么.
2. 使用 ssh 登录路由器.
2. 自己手动在路由器的命令行下键入命令. (脚本中, ``deploy_start`` 之后的命令, 都是在路由器上执行.)

## 如何知道我部署成功了?

第一步: 访问 http://ip138.com, 你会看到如下提示:

```sh
您的IP是：[***.***.***.*** ] 来自：上海市浦东新区 电信
```

这证明此时, 访问国内的网站 (例如 ip138.com ), 直接走的运营商线路.

第二步. 访问万能的谷歌!! 搜索框中, 输入: ``my ip``, 如果能出结果 ......

恭喜你, 你的各种手机, 电脑, 平板, 可以尝试去体验下无缝的浏览自由世界的乐趣了!!

__如果部署出现问题，可以选择以下步骤进行恢复:__

1. 请拔掉 U 盘后, 重启路由器, 如果可以进入管理界面, 格式化 jffs 分区重来.
2. 点按路由器的重置按钮(按住不放几秒钟), 重置整个路由器.

## 基本思路

看 [这个](https://github.com/shadowsocks/shadowsocks-libev/issues/1666) issue.

## 感谢

感谢以下项目的不断努力，才让我们探索自由，科学上网的愿望变为现实。

[Shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)

[ChinaDNS](https://github.com/shadowsocks/ChinaDNS)

[dnsmasq-china-list](https://github.com/felixonmars/dnsmasq-china-list)

[asuswrt-merlin](https://github.com/RMerl/asuswrt-merlin)

[Entware-ng](https://github.com/Entware-ng/Entware-ng)

## 其他

新增最新版(v3.0.6)的 shadowsocks-libev 服务器端部署脚本, 方便不会在服务器上配置 ss 的朋友.

应该在 Centos 7 与 Ubuntu 16.04 下完美工作.
这个版本的 shadowsocks-libev 依赖 mbedtls, Ubuntu 14.04 没有提供这个包, 因此不再考虑之列.

操作步骤如下:

1. 购买一台可以连接外网的 VPS.
2. 确保可以 root 登录.
3. 参照部署脚本中的注释, 修改 `你的密码` 为 ss-server 所需真实密码, 稍后路由器连接需要这个密码.
4. 假设你的 VPS IP 地址是: 123.123.123.123, 运行: ``./ss-server_install root@123.123.123.123`` 等待完成.

补充:

基于你选择的服务商, 如果是 Centos 7 可能需要手动添加 ``epel`` 的 source 进来, 否则找不到 ``mbedtls-devel`` 这个包.

```sh
$: rpm -ivh http://download.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
```

然后重新运行部署脚本.

有问题, 提 issue, 会不定期解决.
