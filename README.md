# 使用华硕 merlin 架设透明代理

Billy.Zheng 2016/07/24

(2017/02/18 再次编辑)

本文基于网络上大量资料整理，恕在此不一一列举，没有大量网友的无私分享，就不会有这个文章。

本部署脚本原始基于华硕(ASUS) RT-AC66U MIPS 架构的路由器编写, 也在 RT-AC87U ARM 架构上实测成功.
本文章的部署策略通过修改应该也适用于 OpenWRT 及其他系统, 思路是一样的。

注意:

1. 本文完全基于命令行操作，无任何 GUI 支持, 你需要具备一定的 CLI 操作能力，以及开启 SSH 自动登陆 (见下述)
2. 请刷官方版的 [asuswrt-merlin](https://asuswrt.lostrealm.ca), 原始开发基于的版本为 Firmware:380.59, 请不要低于这个版本.
3. 自动安装脚本需要 ssh 支持，如果你的操作主机是 Linux 或 Mac，应该完全没问题, 如果是 Windows，请百度自行解决。

## 目的
使用目前最流行的白名单方式，通过维护一份国内网站域名列表[dnsmasq-china-list](https://github.com/felixonmars/dnsmasq-china-list),
实现国内域名跳过, 国外域名自动翻墙的代理


## 使用本脚本部署的前置条件
### 升级你的路由器最新版本的 [asuswrt-merlin](https://asuswrt.lostrealm.ca)

### 寻找一个 U 盘, 容量不限, 格式化这个 U 盘到 ext3 分区.
具体操作, Window 下请百度自行解决.

Linux 下, 假设你的 U 盘驱动器设备为 /dev/sdd1

# mkfs.ext3 /dev/sdd1

__注意!! 以上操作需谨慎, 盘符一定搞对, 等价于 Window 下的格式化操作, 本文不对因用户不了解造成的任何数据丢失, 承担责任!__

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

此时选择 1 即可, 等待 opkg 包管理安装完成后, `exit` 退出路由器.


## 使用本脚本一键部署

__请注意: 下面的步骤是在你的本地主机上操作, 而不是在你的路由器上.__ 

### clone 项目到你的本地

这里以克隆项目到你的 $HOME 下为例:

```sh
$ git clone https://github.com/zw963/asuswrt-merlin-transparent-proxy ~/
```

### 新增你的 shadowsocks.json 配置脚本

首先进入项目目录

```sh
$ cd ~/asuswrt-merlin-transparent-proxy
```

创建连接到墙外的跳板服务器的 shadowsocks.json 脚本. (可能是自己的 VPS 或 第三方收费 VPN)

```sh
$ touch route/opt/etc/shadowsocks.json
```

使用编辑器打开 shadowsocks.json, 内容示例如下, 具体内容请自行百度解决或向你的 VPN 提供商咨询.
如何在自己的 VPS 上部署 SS, 请参阅相关文章, 在此不再赘述.

```json
{
  "server":"123.123.123.123",     // 这是你国外服务器地址(服务器上应该运行一个 shadowsocks server)
  "server_port": 12345,           // ss-server 监听的端口
  "local_address":"192.168.1.1",  // 确保这个地址设为你的路由器 ip 地址
  "local_port": 1080,             // 无需更改
  "password": "yours_password",   // ss-server 上设定的密码.
  "timeout":600,                  // 不用改
  "method":"rc4-md5"              // ss-server 上设定的加密方式.
}
```

### 运行一键部署脚本自动部署. 

此时，在你的电脑上应该已经可以自动 ssh 登陆到你的路由器, 假设路由器 ip 地址是 192.168.1.1.

则在你的 `宿主电脑上` 执行以下命令.

```sh
$ ./ss+dnsmasq admin@192.168.1.1
```

或

```sh
$ ./ss+dnsmasq+chinadns admin@192.168.1.1
```

后者使用了 chinadns, 前者没用, 感觉不用 chinadns 速度更快一些, 推荐 `ss+dnsmasq` 方案.

脚本如果如果未出错，最后会看到 ``Rebooting, please wait ...`` 字样, 路由器会自动重启, 基本上就成功了.

部署成功后, 请耐心等待重启, 部署后比未部署时, 启动时间要长很久(重启大概需要两分钟), 这是正常的, 请耐心等待.

你可以尝试去体验下自由世界的乐趣了!!

## 手动部署

如果你不想配置 SSH 自动登录, 又对这个脚本做了什么不太放心, 你可以选择手动部署.

1. 请首先尝试读懂 [部署脚本](https://github.com/zw963/asuswrt-merlin-transparent-proxy/blob/master/ss+dnsmasq) 中的命令在干什么.
2. 将 route/ 目录下的文件, 就按照同样的目录结构, 使用 scp 复制到你的路由器.
3. [部署脚本](https://github.com/zw963/asuswrt-merlin-transparent-proxy/blob/master/ss+dnsmasq) 中, ``deploy_start`` 这行之后的内容
其实都在路由器中执行, 你可以研究下该命令在做什么, 然后自己通过 `ssh admin@192.168.1.1` 输入密码登录, 自己来完成它.

警告: __如果重启后出现任何部署问题，请拔掉 U 盘, 再重新启动，待启动正常后，再插入 U 盘，修复问题后再重启即可。
如果还不行, 只能初始化路由器为出厂设置. 具体操作为: 首先关闭路由开关, 然后按下蓝色网线口旁边的那个小洞中的初始化按钮,
保持不放(你可能需要借助于牙签之类的物件来操作), 打开开关, 待闪烁稳定下来后, 重新连接路由器即可.___

## 基本思路

1. 路由器启动 ss-redir, 连接远程 ss-server, 并监听 1080 端口.
2. 路由器启动 ChinaDNS, 监听 5356 端口. (可选)
3. 使用 [dnsmasq-china-list](https://github.com/felixonmars/dnsmasq-china-list) 项目中提供的(accelerated-domains.china.conf) 作为 DNS 白名单。
   所有在白名单中的域名, 跳过代理, 剩下的通过代理访问, 可参阅 foreign_domains.conf.
4. 对 accelerated-domains.china.conf 进行批量替换，生成和白名单条目一一对应的 accelerated-domains-ipset.china.conf 文件.
5. 访问一个网址时, 如果域名在这个白名单中，dnsmasq 会将这些国内的域名 IP 加入一个叫做 FREEWEB 的 ipset, 这些是我们可以自由访问的 IP.
6. iptables 中指定，如果访问的 IP 属于 FREEWEB , 则跳过代理直接放行，否则，将流量转发到 ss-redir.(1080端口)
6. iptables 中指定，如果访问的 IP 是本地 IP, 也是直接放行.

一些更加具体的设定问题，请查看这个 issue 中的讨论. https://github.com/onlyice/asus-merlin-cross-the-gfw/issues/5#issuecomment-234708422

## 相比较其他方案的优缺点

### 优点
1. 采用 ``域名白名单`` 机制，相比较黑名单机制来说, 周期性变动不大，并且由 [dnsmasq-china-list](https://github.com/felixonmars/dnsmasq-china-list) 维护，方便更新。
2. 省略了在 iptables 中加入大量国内的 IP 段，常常难以维护, 因为我们已经有域名白名单了，当访问白名单中的网站时，dnsmasq 会帮我们维护这个列表。

### 缺点
dnsmasq-china-list 的白名单已经有 3W 多条了，因为 ipset 缘故，又加了 3W 多条 ipset 策略, 总共 7W 条规则让 dnsmasq 负载变重。
因此路由器启动时, 会稍稍变慢, 不过在使用时, 在我的 rt-ac66u 之上，看起来完全没有影响, 看 youtube, cpu 基本上小于 4%, 内存稳定在 10m 左右,
没什么瓶颈，就是不知道 dnsmasq 支持的条数是否存在上限 ...

## 感谢
本文受到了大量网友文章的启发，并综合了各种信息，加以整理而成，无法一一感谢，仅列取最近部分的一些连接。

[使用 Asus Merlin 实现路由器翻墙](https://github.com/onlyice/asus-merlin-cross-the-gfw/blob/master/README.md)

[使用ipset让openwrt上的shadowsocks更智能的重定向流量](https://hong.im/2014/07/08/use-ipset-with-shadowsocks-on-openwrt/)

[利用ipset进行选择性的翻墙](https://opensiglud.blogspot.hk/2014/10/ipset.html)

[shadowsocks-libev README 文档](https://github.com/shadowsocks/shadowsocks-libev)

[如何在路由器中实现透明代理？](https://gist.github.com/snakevil/8a34d6fbdf2a64f2c753)

[ss-redir 的 iptables 配置(透明代理)](https://gist.github.com/wen-long/8644243)

[搭建智能翻墙路由器](http://hbprotoss.github.io/posts/da-jian-zhi-neng-fan-qiang-lu-you-qi.html)

感谢以下 Wonderful 项目的不断努力，才让我们探索自由，科学上网的愿望变为现实。

[Shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)

[ChinaDNS](https://github.com/shadowsocks/ChinaDNS)

[dnsmasq-china-list](https://github.com/felixonmars/dnsmasq-china-list)

[asuswrt-merlin](https://github.com/RMerl/asuswrt-merlin)

[Entware-ng](https://github.com/Entware-ng/Entware-ng)

## 其他

[使用华硕 merlin 架设离线下载服务器](https://github.com/zw963/asuswrt-merlin-offline-download)
