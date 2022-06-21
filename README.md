# 野火IM单机百万连接测试
单机C1000K测试是服务性能良好的一个标志性指标。野火IM成功通过了单机百万长链接的测试。专业版的用户都可以按照这个过程来验证单机百万连接能力。

## 硬件资源准备
一台16C32G云服务器作为IM服务器。一台4C8G的云MySQL服务。另外准备20台2C4G的云服务器作为压测机，每台压测机建立5万的长链接（有一些特殊的技巧可以让一台压测机压测百万连接，但都比较复杂，而且效果不直观，这里还是采用最简单直接的办法，用20台来压测）。操作系统统一使用CentOS7.6。此外由于需要运行脚本，本地电脑需要用mac或者linux，还没有在windows下的linux子系统中验证过。

| 用途 | 配置 | 数量 |
| ------ | ------ | ------ |
| IM服务 | 16C32G | 1 |
| 数据库 | 4C8G | 1 |
| 压测机 | 2C4G | 20 |


测试一次的资源要求还是挺多的，可以按小时购买云服务器资源，测试一天花费的时间也是比较少的。野火做一次测试的成本在100元以内。

注意购买云服务器时先检查同一区是否同时有16C32G的服务器和2C4G的服务器，先购买2C4G的云服务器22台，购买成功后再购买IM服务器和mysql数据库。野火就遇到先购买IM服务器成功后，再购买压测机时遇到库存数量不足的尴尬局面。

为什么要购买22台云服务器，因为野火在测试中遇到偶尔有一两台服务器的网络有问题（压测程序如果遇到连接断开会立即结束，没有做重试。野火在腾讯云服务器上遇到过部分服务有很低的网络错误率，导致测试到一半异常结束），无法保持长链接，需要有备用替换。

购买服务器时注意配置免密登陆证书，这样后面可以用脚本免密登陆批量处理。

为了避免网络因素影响，测试使用内网网络。购买成功后就可以把IM服务的内网IP告诉野火来打包对应的专业版IM服务。

## IM服务器安装Java
IM服务唯一需要安装的组件就是Java了，登陆后命令行执行：
```
yum install java-1.8.0-openjdk-headless.x86_64
```

## 优化IM服务器配置
默认的配置是不能支持百万连接的，需要优化系统配置。在命令行执行：
```
ulimit -n 1048576

sysctl -w fs.file-max=2000000
sysctl -w fs.nr_open=2000000

sysctl -w net.core.somaxconn=10240
sysctl -w net.ipv4.tcp_max_syn_backlog=16384
sysctl -w net.ipv4.tcp_syncookies=0

sysctl -w net.core.netdev_max_backlog=16384

sysctl -w net.ipv4.tcp_max_tw_buckets=1048576

sysctl -w net.ipv4.tcp_tw_reuse=1
sysctl -w net.ipv4.tcp_tw_recycle=1

sysctl -w net.ipv4.tcp_keepalive_intvl=30
sysctl -w net.ipv4.tcp_keepalive_time=900
sysctl -w net.ipv4.tcp_keepalive_probes=3

sysctl -w net.ipv4.tcp_fin_timeout=15

sysctl -w net.ipv4.tcp_max_orphans=131072

sysctl -w net.netfilter.nf_conntrack_max=1000000
sysctl -w net.netfilter.nf_conntrack_tcp_timeout_time_wait=30

sysctl -w net.core.optmem_max=819200

sysctl -w net.core.rmem_default=262144
sysctl -w net.core.wmem_default=262144
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216


sysctl -w net.ipv4.tcp_mem='786432 4194304 8388608'
sysctl -w net.ipv4.tcp_rmem='768 1024 4206592'
sysctl -w net.ipv4.tcp_wmem='768 1024 4206592'
```
另外修改```/etc/security/limits.conf```文件，把```nofile```设置为1048576，如下所示：
```
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
```

## 配置压测机免密登陆
因为压测机的数量太多，需要配置免密登陆，然后用脚本批量操作。把测试机的命名从test1到test22。配置免密的方法请自行百度解决。

## 优化MySQL
购买的云服务MySQL基本上已经优化过了，只有一个参数需要再优化，```innodb_buffer_pool_size```设置为系统的70%大小，也就是5.6G

## 部署IM服务
购买完IM服务知道IM服务的内网IP后，就可以找野火索要专业版IM服务。野火会邮件把专业版IM服务包发给您，在软件包中还包括压测工具。先部署IM服务。在IM服务器上解压，然后配置```config/wildfirechat.conf```
```
server.ip ip地址为IM服务的内网IP
#使用mysql数据库
embed.db 0
## 各种限频的大小改为1000000
http.admin.rate_limit 1000000
http.robot.rate_limit 1000000
http.channel.rate_limit 1000000
client.request_rate_limit 1000000
## 下面这个配置是关掉的，要打开
netty.epoll true
```
配置```config/c3p0.xml```，把MySQL的信息填进去。

配置```bin/wildfirechat.sh```，修改最大内存和最小内存为48G
```
JAVA_OPTS="$JAVA_OPTS -Xmx24G"
JAVA_OPTS="$JAVA_OPTS -Xms24G"
```
修改完这些之后，进入bin目录执行 ```nohup ./wildfirechat.sh 2>&1 &```，这样IM服务就部署完成了。

## 配置测试工具
把此工程下载到本地电脑上，工程中有一个脚本```startTest.sh```和测试配置文件```config.toml```。测试程序在IM服务的软件包内，在IM服务软件包目录下测试工具目录（stress_tools）里面有个amd64架构和arm64架构的，选择压测机的架构解压，有一个可执行程序```wfcstress```，把可执行程序```wfcstress```放置到当前项目目录下。不要拷贝配置文件了，用当前项目目录下的配置文件。


## 开始测试
在项目目录，执行脚本```startTest.sh```。脚本会自动配置压测程序并上传到这22台服务器上，前20台服务器并发开始测试。可以登陆上这20台服务器（使用命令```ssh -o ServerAliveInterval=10 test1```，可以防止ssh超时退出 ），执行命令```tail -f nohup.out```查看连接情况，如果有连接失败的，手动登陆到test21/test22这两台服务器启动测试程序。
```
ssh -o ServerAliveInterval=10 test21
nohup ./wfcstress > console.log 2>&1 &
tail -f console.log
```

连接需要一定的时间，需要耐心等待，等待所有压测机都完成连接后，等待一个小时能够保持长链接就成功完成了百万连接的测试。

## 测试结果
在建立连接时，MySQL的CPU利用率是400%，IM服务的CPU利用率从700%增长到1000%。当所有连接建立之后，MySQL的CPU利用率将为0；IM服务的CPU利用率在800%，内存利用率是88%，网络连接在1000033；压测工具的CPU利用率在5%，内存利用率是60%。
