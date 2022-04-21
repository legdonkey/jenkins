#!/bin/bash

docker build -t "yangguandao/jenkins:v2" .
docker push yangguandao/jenkins:v2

#/tmp/jenkins_buildenv作为所有jenkins构建job的共享构建目录
#如果/tmp/jenkins_buildenv不存在，docker会自动创建，然而用户权限是root，会造成jenkins无法写入，所以我们提前创建
sudo rm -rf /tmp/jenkins_buildenv
mkdir /tmp/jenkins_buildenv

#jenkins_home作为jenkins服务的主目录
#首次执行创建jenkins_home，原因同上
mkdir /home/ygd/jenkins_home

docker run -p 8081:8080 \
-p 50000:50000 \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /home/ygd/jenkins_home:/var/jenkins_home \
-v /tmp/jenkins_buildenv:/tmp/jenkins_buildenv \
--name jenkins \
yangguandao/jenkins:v2
