#!/bin/bash

# 压测机数量
j=20

# 上传测试工具
for ((i=1; i<=j; i++))
do
  x=$[(i-1) * 50000]
  sed "s/UserStartIndex/${x}/" config.toml > config.toml.bak
  ssh -o "StrictHostKeyChecking no" test${i} "sysctl -w net.ipv4.tcp_tw_reuse=1 ; sysctl -w net.ipv4.tcp_tw_recycle=1 ; sysctl -w net.ipv4.ip_local_port_range='1024 65535'"
  scp config.toml.bak test${i}:~/config.toml
  scp wfcstress test${i}:~/
  rm -rf scp config.toml.bak
done

#同时开始
for ((i=1; i<=j; i++))
do
  x=$[(i-1) * 50000]
  ssh -o ServerAliveInterval=10 test${i} "nohup ./wfcstress > console.log 2>&1 &"
done
