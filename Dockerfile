FROM ubuntu:latest

MAINTAINER quadstingray@siedler.com.de

ENV MONGO_DATA_DIR=/var/lib/mongodb \
    MONGO_ROOT_USERNAME=root \
    MONGO_ROOT_PWD=NONE \
    MONGO_EXTRA_ARGS= \
    MONGO_USE_SYSLOG=false \
    MONGO_MAX_CONNECTIONS=NONE \
    MONGO_STORAGEENGINE=wiredTiger \
    MONGO_WIREDTIGER_CACHE_SIZE_GB=NONE

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6 \
 && echo "deb [ arch=amd64 ] http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y mongodb-org-server mongodb-org-shell \
 && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
 && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y \
 && rm -rf /etc/mongod.conf \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

EXPOSE 27017/tcp
VOLUME ["${MONGO_DATA_DIR}"]
ENTRYPOINT ["/sbin/entrypoint.sh"]
CMD ["/usr/bin/mongod"]