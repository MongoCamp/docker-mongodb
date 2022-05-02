FROM debian:11-slim

MAINTAINER MongoCamp Team <docker-mongodb@mongocamp.dev>

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

ARG MONGODB_VERSION="4.4.13"

EXPOSE 27017/tcp

RUN MONGODB_SHORT=${MONGODB_VERSION}; MONGODB_SHORT=$(echo $MONGODB_SHORT | while IFS=. read a b c; do echo "$a.$b"; done;); \ 
    echo $MONGODB_SHORT > mongoshort.txt; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl gnupg procps gnupg; \
    curl -sSL https://www.mongodb.org/static/pgp/server-4.4.asc  -o mongoserver.asc;  \
    gpg --no-default-keyring --keyring ./mongo_key_temp.gpg --import ./mongoserver.asc; \
    gpg --no-default-keyring --keyring ./mongo_key_temp.gpg --export > ./mongoserver_key.gpg; \
    mv mongoserver_key.gpg /etc/apt/trusted.gpg.d/; \
    echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/${MONGODB_SHORT} main" | tee /etc/apt/sources.list.d/mongodb-org-$MONGODB_SHORT.list;  \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y; \
    ln -s /bin/true /bin/systemctl; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y mongodb-org-server=${MONGODB_VERSION} mongodb-org-shell=${MONGODB_VERSION} mongodb-org-mongos=${MONGODB_VERSION} mongodb-org=${MONGODB_VERSION}; \
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y; \
    rm -rf /etc/mongod.conf; \
    rm -rf /var/lib/apt/lists/*; \
    rm -rf /bin/systemctl; \ 
    rm -rf mongo_key_temp.gpg \
    rm -rf mongo_key_temp.gpg~ \
    rm -rf mongoserver.asc

COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

VOLUME ["${MONGO_DATA_DIR}"]
ENTRYPOINT ["/sbin/entrypoint.sh"]
CMD ["/usr/bin/mongod"]