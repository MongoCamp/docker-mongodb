# quadstingray/mongodb:4.0.10

- [Introduction](#introduction)
  - [Contributing](#contributing)
  - [Issues](#issues)
- [Getting started](#getting-started)
  - [Installation](#installation)
  - [Quickstart](#quickstart)
  - [Persistence](#persistence)
  - [Environment Variables](#environment-variables)

# Introduction
Git-Repository to build [Docker](https://www.docker.com/) containerimage for [MongoDB](https://www.mongodb.org/).

## Contributing
If you find this image helpfull, so you can see here how you can help:
- Send a pull request with your features and bug fixes
- Help users resolve their [issues](https://github.com/QuadStingray/docker-mongodb/issues).

## Issues
Before reporting your issue please try updating Docker to the latest version and check if it resolves the issue. Refer to the Docker [installation guide](https://docs.docker.com/installation) for instructions.

If that recommendations do not help then [report your issue](../../issues/new) along with the following information:

- Output of the `docker version` and `docker info` commands
- The `docker run` command or `docker-compose.yml` used to start the
  image. Mask out the sensitive bits.

# Getting started
## Installation
Automated builds of the image are available on
[Dockerhub](https://hub.docker.com/r/quadstingray/mongodb/)

```bash
docker pull quadstingray/mongodb:4.0.10
```

Alternatively you can build the image yourself.
```bash
docker build . --tag 'quadstingray/mongodb:dev';
```

## Quickstart
Start MongoDB using:

```bash
docker run --publish 27017:27017 quadstingray/mongodb:4.0.10
```

*Alternatively, you can use the sample [docker-compose.yml](docker-compose.yml) file to start the container using [Docker Compose](https://docs.docker.com/compose/)*

## Persistence
For MongoDB to persist the state of the container across shutdown and startup, you should mount a volume at the data directory. The container image use by default `/var/lib/mongodb`. You can cange the data directory with the [Docker Environment Variable](https://docs.docker.com/compose/environment-variables/) `MONGO_DATA_DIR`.

> The [Quickstart](#quickstart) and [docker-compose.yml Sample](docker-compose.yml) command or the [Quickstart bash command](#Quickstart) already mounts a volume for persistence.

## Environment Variables

| Variable                       | Default Value    | Informations                                                                                                                                                                                                                                |
|:-------------------------------|:-----------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| MONGO_DATA_DIR                 | /var/lib/mongodb |                                                                                                                                                                                                                                             |
| MONGO_ROOT_USERNAME            | root             |                                                                                                                                                                                                                                             |
| MONGO_PORT                     | 27017            | Specifies the TCP port on which the MongoDB                                                                                                                                                                                                 |
| MONGO_ROOT_PWD                 | NONE             | If the param not equal `NONE` or "" the MongoDB [authorization](https://docs.mongodb.com/manual/reference/program/mongod/#cmdoption-port) will enabled. The password of the `MONGO_ROOT_USERNAME` will be reseted on every container start. |
| MONGO_USE_SYSLOG               | false            | Enable Loging to [SysLog](https://docs.mongodb.com/manual/reference/program/mongod/#cmdoption-syslog)                                                                                                                                       |
| MONGO_STORAGEENGINE            | wiredTiger       | Value for the [storageEngine](https://docs.mongodb.com/manual/reference/program/mongod/#cmdoption-storageengine) parameter                                                                                                                  |
| MONGO_WIREDTIGER_CACHE_SIZE_GB | NONE             | Value for the [wiredTigerCacheSizeGB](https://docs.mongodb.com/manual/reference/program/mongod/#wiredtiger-options) parameter                                                                                                               |
| MONGO_MAX_CONNECTIONS          | NONE             | Value for the [maxConns](https://docs.mongodb.com/manual/reference/program/mongod/#cmdoption-maxconns) parameter if not equal `NONE`                                                                                                        |
| MONGO_REPLICA_SET_NAME         |                  | set name for replSet [replication options](https://docs.mongodb.com/manual/reference/program/mongod/#replication-options)                                                                                                                   |
| MONGO_BINDING                  | --bind_ip_all    | ip binding  [ip binding options](https://docs.mongodb.com/manual/reference/program/mongod/#cmdoption-mongod-bind-ip)                                                                                      |
| MONGO_EXTRA_ARGS               |                  | You can use every `mongod` [commandline option](https://docs.mongodb.com/manual/reference/program/mongod/#options)                                                                                                                          |
