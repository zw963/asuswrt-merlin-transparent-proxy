# 使用华硕 merlin 架设透明代理

Billy.Zheng 2016/07/24

本文基于网络上大量资料整理，恕在此不一一列举，没有大量网友的无私分享，就不会有这个文章。

本文是基于华硕(ASUS) RT-AC66U MIPS 架构的路由器, 同样适用于 ARM 架构的 RT-AC68U 及更高级版本。
本教程使用的 asuswrt-merlin 版本为 Firmware:380.59，请不要低于这个版本, 

本文章的部署策略稍作修改，应该也适用于 OpenWRT 及其他系统, 因为思路是一样的。

警告:

1. 本文完全基于命令行操作，无任何 GUI 支持, 你需要一定的 CLI 操作能力，以及配置 SSH 登陆的能力 (见下述)
2. 请刷官方版的 asuswrt-merlin, 版本不早于 Firmware:380.59，否则 dnsmasq 可能无法支持 ipset, 你需要自己度娘搞定。
   并且开启远程 SSH 登陆。
3. 自动安装脚本需要 ssh, scp 命令支持，这在 Linux 下完全不是问题，如果是 Windows 下，请参考一键部署脚本自行解决。

## 部署
本项目的目的，是使用目前流行的白名单方式，仅仅需要维护一份国内网站的域名列表[dnsmasq-china-list](https://github.com/felixonmars/dnsmasq-china-list),
即可实现完美的透明 FQ，实现针对 G!!!F!!!W 的自动穿越。

### 初始化 jffs.

插入一个 U 盘到路由器，自己想办法确保这个 U 盘是 ext3 分区格式，在此不详述，自行度娘解决。

登陆路由器 => 系统管理 => 系统设置 => Format JFFS partition at next boot 点 `是`。
登陆路由器 => 系统管理 => 系统设置 => Enable JFFS custom scripts and configs 点 `是`。
登陆路由器 => 系统管理 => 系统设置 =>  Enable SSH 选择 `LAN+WAN`。
登陆路由器 => 系统管理 => 系统设置 =>  SSH Authentication key, 加入你的 public key, 请自行度娘解决。

应用本页面设置，等待结束后, 务必重新启动路由器。

重启后，尝试访问路由器： (假设 192.168.1.1 是你的路由 IP)

```sh
$ ssh admin@192.168.1.1
```

如果登陆成功，出现命令提示符, 键入 `entware-setup.sh` 来初始化包管理系统 opkg.

```sh
admin@RT-AC66U-20F0:/tmp/home/root# entware-setup.sh
```

如果你的 U 盘分区格式没问题，这个脚本会出现类似如下提示： 选择 1 即可。

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

请务必确保 opkg 工具可用的情况下再进入下一步，如果出现问题，重启后再次执行 entware-setup.sh.

### clone 项目到本地，并新增 shadowsocks.json 配置脚本

首先克隆项目到本地.

```sh
$ git clone https://github.com/zw963/asuswrt-merlin-transparent-proxy ~/
```

然后，进入项目内的 route/opt/etc/ 目录, 创建一个 shadowsocks.json 脚本.

```sh
$ cd ~/asuswrt-merlin-transparent-proxy/route/opt/etc/
$ touch shadowsocks.json
```

内容示例如下, 具体含义请自行度娘解决。

```json
{
  "server":"123.123.123.123",
  "server_port": 12345,
  "local_address":"192.168.1.1",
  "local_port": 1080,
  "password": "yours_password",
  "timeout":600,
  "method":"aes-128-cfb"
}
```

注意：确保 local_address 设定为你的路由器 ip 地址。
创建 ss 配置文件完毕后，进入下一步。

### 运行一键部署脚本进行部署. 

请尽量采用 public key 免密码方式通过访问你的路由器, 否则这个脚本会停下来多次让你输入 ssh 密码，不胜其烦。
即：网页中，SSH Authentication key 部分加入你的 public key, 具体使用请自行度娘解决。

当然，如果你不放心，完全可以选择照着[部署脚本](https://github.com/zw963/asuswrt-merlin-transparent-proxy/blob/master/routeinit)逐条自行复制粘帖即可。
相信我，部署脚本真的很简单，而且添加了大量的注释，配合 route 目录下的文件，看看就应该懂。

假设我的路由器 ip 地址是 192.168.1.1, 并且开放了 22 的 ssh 端口, 则运行以下命令即可。

```ssh 
./routeinit admin@192.168.1.1
```

脚本如果如果未出错，执行完后，路由器会重启, 重启后，稍等一分钟左右，尝试去体验下自由世界的乐趣吧。

警告: __如果重启后出现任何部署问题，请拔掉 U 盘, 再重新启动，待启动正常后，再插入 U 盘，修复问题后再重启即可。__

## 基本思路

1. 路由器启动 ss-redir, 连接远程 ss-server, 并监听 1080 端口.
2. 路由器启动 ChinaDNS, 监听 5356 端口.
3. 使用 [dnsmasq-china-list](https://github.com/felixonmars/dnsmasq-china-list) 项目中提供的(accelerated-domains.china.conf) 作为 DNS 白名单。
   所有在这个文件中指定的域名，将使用本地运营商 DNS 服务器进行解析, 剩下的转到本地的 ChinaDNS 服务器, 见 foreign_domains.conf.
4. 使用 accelerated-domains.china.conf 进行批量替换，生成和白名单条目一一对应的 accelerated-domains-ipset.china.conf 文件, 
5. 执行 DNS 查询时如果发现域名在这个名单中，   dnsmasq 会将访问过的这些国内网站域名对应的 IP 加入一个 ipset, 我们这里名字叫做 FREEWEB.
6. 使用 iptables 策略，如果访问的 ip 属于 FREEWEB 这个 ipset(国内域名解析出来的IP), 直接放行，否则，将流量转发到 ss-redir.(1080端口)

一些更加具体的设定问题，请查看这个 issue 中的讨论. https://github.com/onlyice/asus-merlin-cross-the-gfw/issues/5#issuecomment-234708422

## 相比较其他方案的优缺点

### 优点
1. 采用白名单机制，周期性变动不大，并且由 [dnsmasq-china-list](https://github.com/felixonmars/dnsmasq-china-list) 维护，方便更新。
2. 无需在 iptables 中加入大量国内的 IP 段，并常常难以维护, 因为我们已经有域名白名单了，当访问白名单中的网站时，dnsmasq 会帮我们维护这个列表。

### 缺点
dnsmasq-china-list 的白名单已经有 3W 多条了，因为 ipset 缘故，又加了 3W 多条 ipset 策略, 总共 7W 条规则让 dnsmasq 负载变重。
不过，在我的 RT-AC66U 之上，看起来完全没有影响, 看 Youtube, CPU 基本上小于 4%, 内存稳定在 10M 左右, 没什么瓶颈，就是不知道 dnsmasq 支持的条数是否存在上限 ...

## 感谢
本文受到了大量网友文章的启发，并综合了各种信息，加以整理而成，无法一一感谢，仅列取最近部分的一些连接。

[使用 Asus Merlin 实现路由器翻墙](https://github.com/onlyice/asus-merlin-cross-the-gfw/blob/master/README.md)

[使用ipset让openwrt上的shadowsocks更智能的重定向流量](https://hong.im/2014/07/08/use-ipset-with-shadowsocks-on-openwrt/)

[利用ipset进行选择性的翻墙](https://opensiglud.blogspot.hk/2014/10/ipset.html)

[shadowsocks-libev README 文档](https://github.com/shadowsocks/shadowsocks-libev)

[如何在路由器中实现透明代理？](https://gist.github.com/snakevil/8a34d6fbdf2a64f2c753)

感谢以下 Wonderful 项目的不断努力，才让我们探索自由，科学上网的愿望变为现实。

[Shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)

[ChinaDNS](https://github.com/shadowsocks/ChinaDNS)

[dnsmasq-china-list](https://github.com/felixonmars/dnsmasq-china-list)

[asuswrt-merlin](https://github.com/RMerl/asuswrt-merlin)

[Entware-ng](https://github.com/Entware-ng/Entware-ng)

