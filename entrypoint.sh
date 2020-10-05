#!/bin/bash
set -e

function setup_signals {
  echo "[entrypoint.sh] Setup shoutdown signals"
  cid="$1"; shift
  handler="$1"; shift
  for sig; do
    trap "$handler '$cid' '$sig'" "$sig"
  done
}

function handle_signal {
  case "$2" in
    SIGINT)
      stop_mongod
      ;;
    SIGTERM)
      stop_mongod
      ;;
    SIGHUP)
      stop_mongod
      ;;
  esac
}

setup_signals "$1" "handle_signal" SIGINT SIGTERM SIGHUP

create_data_dir() {
  echo "[entrypoint.sh] Create Mongo Data Dir <${MONGO_DATA_DIR}>"
  mkdir -p ${MONGO_DATA_DIR}
  chmod -R 0755 ${MONGO_DATA_DIR}
}

stop_mongod() {
  echo "[entrypoint.sh] Stop mongod"
  PID=`pgrep mongod`
  if [[ ${MONGO_REPLICA_SET_NAME} != 'NONE' && ${MONGO_REPLICA_SET_NAME} != '' ]]; then
      mongo admin --port ${MONGO_PORT} --eval 'db.adminCommand( { replSetStepDown: 120, secondaryCatchUpPeriodSecs: 0, force: true } );'
  fi
  mongo admin --port ${MONGO_PORT} --eval 'db.shutdownServer();'
  while ps -p $PID &>/dev/null; do
      sleep 1
  done
  echo "[entrypoint.sh] MongoDB stoped"
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
   echo "[entrypoint.sh] Added wiredTigerMaxMemory to ${MONGO_WIREDTIGER_CACHE_SIZE_GB}"
   MONGO_EXTRA_ARGS="${MONGO_EXTRA_ARGS} --wiredTigerCacheSizeGB ${MONGO_WIREDTIGER_CACHE_SIZE_GB}"
fi

echo "[entrypoint.sh] Set StorageEngine to <${MONGO_STORAGEENGINE}>"
MONGO_EXTRA_ARGS="${MONGO_EXTRA_ARGS} --storageEngine ${MONGO_STORAGEENGINE}"

echo "[entrypoint.sh] Set IpBinding to <${MONGO_BINDING}>"
MONGO_EXTRA_ARGS="${MONGO_EXTRA_ARGS} ${MONGO_BINDING}"

if [[ ${MONGO_MAX_CONNECTIONS} != 'NONE' ]]; then
  echo "[entrypoint.sh] Set Max Connections to <${MONGO_MAX_CONNECTIONS}>"
  MONGO_MAX_CONNECTIONS="${MONGO_EXTRA_ARGS} --maxConns ${MONGO_MAX_CONNECTIONS}"
fi

# default behaviour is to launch mongod
if [[ -z ${1} ]]; then

  echo "[entrypoint.sh] Upgrade MongoDb stored files if needed"
  mongod --port ${MONGO_PORT} --upgrade --dbpath ${MONGO_DATA_DIR} ${MONGO_EXTRA_ARGS}

  echo "[entrypoint.sh] Starting mongod for upgrade Informations"
  mongod --port ${MONGO_PORT} --fork --syslog --dbpath ${MONGO_DATA_DIR} 2>&1

  echo "[entrypoint.sh] Set Version to 4.2"
  mongo admin --port ${MONGO_PORT}  --eval 'db.adminCommand( { setFeatureCompatibilityVersion: "4.2" } ); db.adminCommand( { getParameter: 1, featureCompatibilityVersion: 1 } );'

  if [[ ${MONGO_ROOT_PWD} != 'NONE' && ${MONGO_ROOT_PWD} != '' ]]; then
    echo "[entrypoint.sh] Admin User to Database"
    mongo admin --port ${MONGO_PORT}  --eval "db.dropUser('${MONGO_ROOT_USERNAME}'); db.createUser({'user': '${MONGO_ROOT_USERNAME}','pwd': '${MONGO_ROOT_PWD}','roles': [ 'root' ]});"
  fi

  if [[ ${MONGO_REPLICA_SET_NAME} == 'Standalone0' ]]; then
    echo "[entrypoint.sh] remove replicaSet definition for 'Standalone0' replicaSet"
    mongo local --port ${MONGO_PORT}  --eval "db.dropDatabase();"
  fi

  echo "[entrypoint.sh] Stop mongod for insert USER or Update Feature Version ..."
  stop_mongod

  if [[ ${MONGO_REPLICA_SET_NAME} != 'NONE' && ${MONGO_REPLICA_SET_NAME} != '' ]]; then
     echo "[entrypoint.sh] use ReplicaSet defintion"
     MONGO_EXTRA_ARGS="${MONGO_EXTRA_ARGS} --replSet ${MONGO_REPLICA_SET_NAME}"

     echo "[entrypoint.sh] Starting mongod for checking and initiate ReplicaSet"
     mongod --port ${MONGO_PORT} --fork --syslog --dbpath ${MONGO_DATA_DIR} ${MONGO_EXTRA_ARGS} 2>&1

     echo "[entrypoint.sh] initiate ReplicaSet"
     mongo admin --port ${MONGO_PORT} --eval "rs.initiate()"
     echo "[entrypoint.sh] Stop mongod for initiate ReplicaSet"
     stop_mongod
  fi

  if [[ ${MONGO_ROOT_PWD} != 'NONE' ]]; then
    MONGO_EXTRA_ARGS="${MONGO_EXTRA_ARGS} --auth"
  fi

  if [[ ${MONGO_USE_SYSLOG} == 'true' || ${MONGO_USE_SYSLOG} == 'TRUE' ]]; then
     echo "[entrypoint.sh] use syslog"
     MONGO_EXTRA_ARGS="${MONGO_EXTRA_ARGS} --syslog"
  elif [ ${MONGO_LOG_PATH} != 'NONE' && ${MONGO_LOG_PATH} != '' ]]; then
     echo "[entrypoint.sh] set logpath"
     MONGO_EXTRA_ARGS="${MONGO_EXTRA_ARGS} --logpath ${MONGO_LOG_PATH}"
  fi

  echo "[entrypoint.sh] Starting mongod..."
  mongod --port ${MONGO_PORT} --dbpath ${MONGO_DATA_DIR} ${MONGO_EXTRA_ARGS} --fork 2>&1

  PID=`pgrep mongod`
  while ps -p $PID &>/dev/null; do
      sleep 10
  done

else
  exec "$@"
fi
