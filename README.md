# 记一次jenkins docker部署，并且用jenkins构建测试docker
- [记一次jenkins docker部署，并且用jenkins构建测试docker](#记一次jenkins-docker部署并且用jenkins构建测试docker)
- [源起](#源起)
- [具体过程](#具体过程)
  - [一.在官方jenkins/jenkins:lts-jdk11的基础上，创建我的Jenkins镜像](#一在官方jenkinsjenkinslts-jdk11的基础上创建我的jenkins镜像)
    - [这段Dockerfile我们要注意以下几点：](#这段dockerfile我们要注意以下几点)
- [二.这个Jenkins镜像的运行脚本有讲究](#二这个jenkins镜像的运行脚本有讲究)
- [三.Jenkins镜像运行脚本](#三jenkins镜像运行脚本)
  
# 源起

最近需要部署jenkins做CI，首先想到的是试用jenkins的官方docker，docker hub有收录。

我们需要在jenkins里面自动构建的，除了普通代码，也可能docker项目。

这就意味着要支持在jenkins这个容器里面跑docker。

然而，docker官方不建议在docker in docker，会引发许多混乱，详情见

[Using Docker-in-Docker for your CI or testing environment? Think twice. (jpetazzo.github.io)](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/)


作者给出的解决方案是——内外两个docker cli共享/var/run/docker.socket，从而达到共享相同docker engine的目的。这样本质上就不算是docker in docker了，而是docker beside docker.


```bash
docker run -v /var/run/docker.sock:/var/run/docker.sock ...
```

听着就靠谱，立马执行起来

# 具体过程

## 一.在官方jenkins/jenkins:lts-jdk11的基础上，创建我的Jenkins镜像

```docker
FROM jenkins/jenkins:lts-jdk11

#在docker中install docker
USER root

RUN apt-get update
RUN apt-get -y install apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common 
RUN curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg > /tmp/dkey
RUN apt-key add /tmp/dkey
RUN add-apt-repository \
    "deb [arch=amd64] \
    https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
    $(lsb_release -cs) \
    stable"
RUN apt-get update
RUN apt-get -y install docker-ce

#设置自己宿主机的docker的gid,将docker内的jenkins（uid1000)加入docker组
ARG HOST_DOCKER_UID=998
RUN groupmod -g $HOST_DOCKER_UID docker 
RUN usermod -aG docker jenkins

#install plugins
USER jenkins

#COPY plugins.txt /usr/share/jenkins/plugins.txt
#RUN jenkins-plugin-cli -f /usr/share/jenkins/plugins.txt
#RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/plugins.txt
```

有了这个Dockerfile，我们就在可以host上面，创建一个container-A（jenkins），后面我们还会通过jenkins构建container-B（我们的程序）

### 这段Dockerfile我们要注意以下几点：

1. 执行apt-get要使用root用户，然后切回jenkins用户（jenkins官方镜像的默认用户，id=1000）
2. 我这里host的用户也是1000，属于host的docker组（id=998）
3. container-A安装了docker，所以也会创建container-A的docker组，id=999。并且998不在container-A的/etc/group中
4. 如果不做任何处理，在container-A中执行id jenkins，会看到jenkins属于组jenkins(1000)，998
5. 所以我这里直接把container-A中的docker组id改成了998，这样jenkins就有执行docker的权限了

# 二.这个Jenkins镜像的运行脚本有讲究

有了Dockerfile，下一步就是运行镜像启动jenkins，再下一步就是构建一个job了。

我的job从github上下载代码,放到WORKSPACE,我的WORKSPACE路径是
```
/tmp/jenkins_buildenv/${JOB_NAME}/workspace
```


然后执行一段有docker run的shell脚本，这是《第一本docker书》里面的一个例子:

```bash
IMAGE=$(docker build . | tail -1 | awk '{print $NF}')

MNT="$WORKSPACE/.."

CONTAINER=$(docker run -d -u 1000 -v "$MNT:/opt/project" $IMAGE /bin/bash -c 'cd /opt/project/workspace && rake spec')

docker attach $CONTAINER

RC=$(docker wait $CONTAINER)

docker rm $CONTAINER

exit $RC
```

注意，这里的`$MNT:/opt/project`企图把container-A中的目录挂载到container-B中，如果不做任何处理，是行不通的。

因为，docker engine是在host中，它收到这条docker run的指令后，并不知道该指令是从container-A里面发来的，它会以为这是host给他的指令。于是docker engine会在host的目录中创建一个目录。

解决办法——既然是docker beside docker，我们就为所Jenkins jobs创建一个共享的目录

# 三.Jenkins镜像运行脚本

```docker
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
```

至此，我们可以开心的用Jenkins docker了。