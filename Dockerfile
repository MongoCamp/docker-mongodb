FROM debian:jessie-slim

MAINTAINER QuadStingray <docker-mongodb@quadstingray.com>

ENV MONGO_DATA_DIR=/var/lib/mongodb \
    MONGO_EXTRA_ARGS="" \
    MONGO_ROOT_USERNAME=root \
    MONGO_PORT=27017 \
    MONGO_ROOT_PWD=NONE \
    MONGO_USE_SYSLOG=false \
    MONGO_MAX_CONNECTIONS=NONE \
    MONGO_STORAGEENGINE=wiredTiger \
    MONGO_WIREDTIGER_CACHE_SIZE_GB=NONE \
    MONGO_BINDING=--bind_ip_all \
    MONGO_REPLICA_SET_NAME=NONE

ARG MONGODB_VERSION="4.0.7"

EXPOSE 27017/tcp

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4 \
    && echo "deb http://repo.mongodb.org/apt/debian jessie/mongodb-org/4.0 main" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y mongodb-org-server=${MONGODB_VERSION} mongodb-org-shell=${MONGODB_VERSION} mongodb-org-mongos=${MONGODB_VERSION} \
    && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y \
    && rm -rf /etc/mongod.conf \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

VOLUME ["${MONGO_DATA_DIR}"]
ENTRYPOINT ["/sbin/entrypoint.sh"]
CMD ["/usr/bin/mongod"]
