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



