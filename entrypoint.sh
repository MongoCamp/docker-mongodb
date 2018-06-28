#!/bin/bash
set -e

create_data_dir() {
  echo "Create Mongo Data Dir <${MONGO_DATA_DIR}>"
  mkdir -p ${MONGO_DATA_DIR}
  chmod -R 0755 ${MONGO_DATA_DIR}
}

create_data_dir

# allow arguments to be passed to mongod
if [[ ${1:0:1} = '-' ]]; then
  EXTRA_ARGS="$@"
  set --
elif [[ ${1} == mongod || ${1} == $(which mongod) ]]; then
  EXTRA_ARGS="${@:2}"
  set --
fi


if [[ ${MONGO_WIREDTIGER_CACHE_SIZE_GB} != 'NONE' ]]; then
   echo "Added wiredTigerMaxMemory to ${MONGO_WIREDTIGER_CACHE_SIZE_GB}"
   MONGO_EXTRA_ARGS="${MONGO_EXTRA_ARGS} --wiredTigerCacheSizeGB ${MONGO_WIREDTIGER_CACHE_SIZE_GB}"
fi

echo "Set StorageEngine to <${MONGO_STORAGEENGINE}>"
MONGO_EXTRA_ARGS="${MONGO_EXTRA_ARGS} --storageEngine ${MONGO_STORAGEENGINE}"

echo "Set IpBinding to <${MONGO_BINDING}>"
MONGO_EXTRA_ARGS="${MONGO_EXTRA_ARGS} ${MONGO_BINDING}"

if [[ ${MONGO_MAX_CONNECTIONS} != 'NONE' ]]; then
  echo "Set Max Connections to <${MONGO_MAX_CONNECTIONS}>"
  MONGO_MAX_CONNECTIONS="${MONGO_EXTRA_ARGS} --maxConns ${MONGO_MAX_CONNECTIONS}"
fi

# default behaviour is to launch mongod
if [[ -z ${1} ]]; then

  echo "Upgrade MongoDb stored files if needed"
  mongod --port ${MONGO_PORT} --upgrade --dbpath ${MONGO_DATA_DIR} ${MONGO_EXTRA_ARGS}

  echo "Starting mongod for upgrade Informations"
  mongod --port ${MONGO_PORT}  --fork --syslog --dbpath ${MONGO_DATA_DIR} 2>&1

  echo "Set Version to 4.0"
  mongo admin --port ${MONGO_PORT}  --eval "db.adminCommand( { setFeatureCompatibilityVersion: "4.0" } ); db.adminCommand( { getParameter: 1, featureCompatibilityVersion: 1 } );"

  if [[ ${MONGO_ROOT_PWD} != 'NONE' && ${MONGO_ROOT_PWD} != '' ]]; then

    echo "Admin User to Database"
    mongo admin --port ${MONGO_PORT}  --eval "db.dropUser('${MONGO_ROOT_USERNAME}'); db.createUser({'user': '${MONGO_ROOT_USERNAME}','pwd': '${MONGO_ROOT_PWD}','roles': [ 'root' ]});"

  fi

  echo "Stop mongod for insert USER or Update Feature Version ..."
  pkill -f mongo
  pkill -f mongod

  if [[ ${MONGO_ROOT_PWD} != 'NONE' ]]; then
    MONGO_EXTRA_ARGS="${MONGO_EXTRA_ARGS} --auth"
  fi

  if [[ ${MONGO_USE_SYSLOG} == 'true' || ${MONGO_USE_SYSLOG} == 'TRUE' ]]; then
     echo "use syslog"
     MONGO_EXTRA_ARGS="${MONGO_EXTRA_ARGS} --syslog"
  fi

  if [[ ${MONGO_REPLICA_SET_NAME} != 'NONE' && ${MONGO_REPLICA_SET_NAME} != '' ]]; then
     echo "use syslog"
     MONGO_EXTRA_ARGS="${MONGO_EXTRA_ARGS} --replSet ${MONGO_REPLICA_SET_NAME}"
  fi

  echo "Starting mongod..."
  sleep 15
  mongod --port ${MONGO_PORT}  --dbpath ${MONGO_DATA_DIR} ${MONGO_EXTRA_ARGS}

else
  exec "$@"
fi