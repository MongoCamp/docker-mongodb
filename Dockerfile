FROM debian:10-slim

MAINTAINER QuadStingray <docker-mongodb@quadstingray.com>

ENV MONGO_DATA_DIR=/var/lib/mongodb \
    MONGO_EXTRA_ARGS="" \
    MONGO_ROOT_USERNAME=root \
    MONGO_PORT=27017 \
    MONGO_ROOT_PWD=NONE \
    MONGO_USE_SYSLOG=true \
    MONGO_LOG_PATH=/var/log/mongodb \
    MONGO_MAX_CONNECTIONS=NONE \
    MONGO_STORAGEENGINE=wiredTiger \
    MONGO_WIREDTIGER_CACHE_SIZE_GB=NONE \
    MONGO_BINDING=--bind_ip_all \
    MONGO_REPLICA_SET_NAME=NONE

ARG MONGODB_VERSION="5.0.1"

EXPOSE 27017/tcp

RUN apt-get update  \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y wget gnupg procps apt-utils \
    && wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | apt-key add - \
    && echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/5.0 main" | tee /etc/apt/sources.list.d/mongodb-org-5.0.list \
    && apt-get update \
    && apt-get install gnupg \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && ln -s /bin/true /bin/systemctl \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y mongodb-org-server=${MONGODB_VERSION} mongodb-org-shell=${MONGODB_VERSION} mongodb-org-mongos=${MONGODB_VERSION} mongodb-org=${MONGODB_VERSION} \
    && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y \
    && rm -rf /etc/mongod.conf \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /bin/systemctl

COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

VOLUME ["${MONGO_DATA_DIR}"]
ENTRYPOINT ["/sbin/entrypoint.sh"]
CMD ["/usr/bin/mongod"]
