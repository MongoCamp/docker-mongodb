#!/bin/bash
set -euo pipefail

echo "[entrypoint.sh] Starting entrypoint.sh"
echo "[entrypoint.sh] Running as $(whoami) with UID $(id -u) and GID $(id -g)"

function setup_signals {
  echo "[entrypoint.sh] Setup shutdown signals"
  cid="$1"; shift
  handler="$1"; shift
  for sig; do
    # shellcheck disable=SC2064
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
  mkdir -p "${MONGO_DATA_DIR}"
  chmod -R 0755 "${MONGO_DATA_DIR}"
}

setup_mongosh_home() {
  # Setup mongosh home to avoid permission issues when running as non-root user
  echo "[entrypoint.sh] Setup mongosh home"
  local mongosh_runtime_home="/tmp/mongosh-home"

  rm -rf "${mongosh_runtime_home}"
  mkdir -p "${mongosh_runtime_home}/.config"

  export HOME="${mongosh_runtime_home}"
  export XDG_CONFIG_HOME="${mongosh_runtime_home}/.config"
}

stop_mongod() {
  local auth_args=()

  echo "[entrypoint.sh] Stop MongoDb"
  PID=$(pgrep mongod)
  if [ -z "$PID" ]; then
    echo "[entrypoint.sh] No mongod process found"
    return
  fi

  if [[ ${MONGO_ROOT_PWD} != 'NONE' && ${MONGO_ROOT_PWD} != '' ]]; then
    auth_args+=(--username "${MONGO_ROOT_USERNAME}" --password "${MONGO_ROOT_PWD}")
  fi

  if grep -qa -- "--replSet" "/proc/$PID/cmdline"; then
    echo "[entrypoint.sh] Stop MongoDb with replSet"
    mongosh --quiet --norc admin "${auth_args[@]}" --port "${MONGO_PORT}" --eval 'db.adminCommand( { replSetStepDown: 120, secondaryCatchUpPeriodSecs: 0, force: true } );' || true
  else
    echo "[entrypoint.sh] Stop MongoDb"
  fi
  
  mongosh --quiet --norc admin "${auth_args[@]}" --port "${MONGO_PORT}" --eval 'db.shutdownServer();' || true
  while ps -p "${PID}" &>/dev/null; do
      sleep 1
  done
  echo "[entrypoint.sh] MongoDB stopped"
}

create_data_dir
setup_mongosh_home

declare -a mongo_extra_args=()

if [[ -n "${MONGO_EXTRA_ARGS:-}" ]]; then
  read -r -a initial_extra_args <<< "${MONGO_EXTRA_ARGS}"
  mongo_extra_args+=("${initial_extra_args[@]}")
fi

print_mongod_args() {
  printf '[entrypoint.sh] Arguments on mongod startup'
  printf ' %q' "${mongo_extra_args[@]}"
  printf '\n'
}

if [[ ${MONGO_WIREDTIGER_CACHE_SIZE_GB} != 'NONE' ]]; then
   echo "[entrypoint.sh] Added wiredTigerMaxMemory to ${MONGO_WIREDTIGER_CACHE_SIZE_GB}"
   mongo_extra_args+=(--wiredTigerCacheSizeGB "${MONGO_WIREDTIGER_CACHE_SIZE_GB}")
fi

echo "[entrypoint.sh] Set StorageEngine to <${MONGO_STORAGEENGINE}>"
mongo_extra_args+=(--storageEngine "${MONGO_STORAGEENGINE}")

echo "[entrypoint.sh] Set IpBinding to <${MONGO_BINDING}>"
read -r -a binding_args <<< "${MONGO_BINDING}"
mongo_extra_args+=("${binding_args[@]}")

if [[ ${MONGO_MAX_CONNECTIONS} != 'NONE' ]]; then
  echo "[entrypoint.sh] Set Max Connections to <${MONGO_MAX_CONNECTIONS}>"
  mongo_extra_args+=(--maxConns "${MONGO_MAX_CONNECTIONS}")
fi

echo "[entrypoint.sh] Upgrade MongoDb stored files if needed"
mongod --port "${MONGO_PORT}" --upgrade --dbpath "${MONGO_DATA_DIR}" "${mongo_extra_args[@]}"

echo "[entrypoint.sh] Starting MongoDb for upgrade Information"
mongod --port "${MONGO_PORT}" --fork --syslog --dbpath "${MONGO_DATA_DIR}" 2>&1

MONGODB_SHORT=$(cat mongoshort.txt)

echo "[entrypoint.sh] Set Version to ${MONGODB_SHORT}"
mongosh --quiet --norc admin --port "${MONGO_PORT}" --eval "db.adminCommand( { setFeatureCompatibilityVersion: '${MONGODB_SHORT}', confirm: true } );"
mongosh --quiet --norc admin --port "${MONGO_PORT}" --eval "db.adminCommand( { getParameter: 1, featureCompatibilityVersion: 1 } );"

if [[ ${MONGO_ROOT_PWD} != 'NONE' && ${MONGO_ROOT_PWD} != '' ]]; then
  echo "[entrypoint.sh] Admin User to Database"
  mongosh --quiet --norc admin --port "${MONGO_PORT}"  --eval "db.dropUser('${MONGO_ROOT_USERNAME}');" || true
  mongosh --quiet --norc admin --port "${MONGO_PORT}"  --eval "db.createUser({'user': '${MONGO_ROOT_USERNAME}','pwd': '${MONGO_ROOT_PWD}','roles': [ 'root' ]});"
fi

if [[ ${MONGO_REPLICA_SET_NAME} == 'Standalone0' ]]; then
  echo "[entrypoint.sh] remove replicaSet definition for 'Standalone0' replicaSet"
  mongosh --quiet --norc local --port "${MONGO_PORT}"  --eval "db.dropDatabase();"
fi

echo "[entrypoint.sh] Stop MongoDb for insert USER or Update Feature Version ..."
stop_mongod

if [[ ${MONGO_REPLICA_SET_NAME} != 'NONE' && ${MONGO_REPLICA_SET_NAME} != '' ]]; then
  echo "[entrypoint.sh] use ReplicaSet definition"
  mongo_extra_args+=(--replSet "${MONGO_REPLICA_SET_NAME}")

  echo "[entrypoint.sh] Starting MongoDb for checking and initiate ReplicaSet"
  mongod --port "${MONGO_PORT}" --fork --syslog --dbpath "${MONGO_DATA_DIR}" "${mongo_extra_args[@]}" 2>&1

  if mongosh --quiet --norc admin --port "${MONGO_PORT}" --eval "rs.status().ok" >/dev/null 2>&1; then
    echo "[entrypoint.sh] ReplicaSet already initialized"
  else
    echo "[entrypoint.sh] initiate ReplicaSet"
    mongosh --quiet --norc admin --port "${MONGO_PORT}" --eval "rs.initiate()"
  fi
  echo "[entrypoint.sh] Stop mongodb for initiate ReplicaSet"
  stop_mongod
fi

if [[ ${MONGO_ROOT_PWD} != 'NONE' ]]; then
  if [[ ${MONGO_REPLICA_SET_NAME} != 'NONE' && ${MONGO_REPLICA_SET_NAME} != '' ]]; then
    if [[ ${MONGO_REPLICA_KEY} != 'RANDOM' && ${MONGO_REPLICA_KEY} != '' ]]; then
      echo "[entrypoint.sh] use given replica key"
      echo "${MONGO_REPLICA_KEY}" > "${MONGO_DATA_DIR}/replica.key"
    else
      echo "[entrypoint.sh] generate random replica key"
      openssl rand -base64 741 > "${MONGO_DATA_DIR}/replica.key"
    fi
    echo "[entrypoint.sh] chmod replica.key"
    chmod 400 "${MONGO_DATA_DIR}/replica.key"
    echo "[entrypoint.sh] chown replica.key"
    chown mongodb:mongodb "${MONGO_DATA_DIR}/replica.key"
    mongo_extra_args+=(--keyFile "${MONGO_DATA_DIR}/replica.key")
  fi
  mongo_extra_args+=(--auth)
fi

if [[ ${MONGO_LOG} != 'NONE' && ${MONGO_LOG} != '' ]]; then
   echo "[entrypoint.sh] set logpath"
   if [[ ${MONGO_LOG} == 'stdout' || ${MONGO_LOG} == 'STDOUT' ]]; then
     echo "[entrypoint.sh] set logpath to stdout"
     mongo_extra_args+=(--logpath "/proc/$$/fd/1")

     chown --dereference mongodb "/proc/$$/fd/1" "/proc/$$/fd/2" || :
   else
     echo "[entrypoint.sh] set logpath to ${MONGO_LOG}"
     mongo_extra_args+=(--logpath "${MONGO_LOG}")
   fi
   echo "[entrypoint.sh] Starting mongod..."
   print_mongod_args
   mongod --port "${MONGO_PORT}" --dbpath "${MONGO_DATA_DIR}" "${mongo_extra_args[@]}" --fork 2>&1
   if [[ ${MONGO_LOG} != 'stdout' && ${MONGO_LOG} != 'STDOUT' ]]; then
     echo "[entrypoint.sh] Start following the mongodb log"
     tail -f "${MONGO_LOG}"
   else
     PID=$(pgrep mongod)
     while ps -p "${PID}" &>/dev/null; do
       sleep 10
     done
   fi
else
   echo "[entrypoint.sh] Starting mongod..."
  print_mongod_args
  mongod --port "${MONGO_PORT}" --dbpath "${MONGO_DATA_DIR}" "${mongo_extra_args[@]}" --syslog --fork 2>&1
   PID=$(pgrep mongod)
   while ps -p "${PID}" &>/dev/null; do
      sleep 10
   done
fi
