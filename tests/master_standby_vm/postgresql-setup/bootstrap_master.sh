#!/usr/bin/env bash

# Edit the following to change the version of PostgreSQL that is installed
PG_VERSION=9.4
PG_VERSION_UPGRADE_TO=9.6
ARCHIVE_DIRECTORY=/var/lib/postgresql/walshipping/logs.compelete
MASTER_IP=172.30.1.5
STANDBY_IP=172.30.1.6

function setup_environment {
    # Enable ru_RU.UTF-8 locale
    sed -i "s/# ru_RU.UTF-8/ru_RU.UTF-8/" /etc/locale.gen
    locale-gen

    PG_REPO_APT_SOURCE=/etc/apt/sources.list.d/pgdg.list
    if [ ! -f "$PG_REPO_APT_SOURCE" ]
    then
      # Add PG apt repo:
      echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" > "$PG_REPO_APT_SOURCE"

      # Add PGDG repo key:
      wget --quiet -O - https://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add -
    fi

    # Update package list and upgrade all packages
    apt-get update

    apt-get -y install "postgresql-$PG_VERSION" "postgresql-contrib-$PG_VERSION" "postgresql-client-$PG_VERSION"

    # create directory for wal archiving
    mkdir -p -m 0755 /var/lib/postgresql/walshipping/logs.complete
    chown -R postgres:postgres /var/lib/postgresql/walshipping

    #create backup directories
    mkdir -p -m 0755 /var/lib/postgresql/walshipping/data.master.0
    chown -R postgres:postgres /var/lib/postgresql/walshipping/data.master.0
    mkdir -p -m 0755 /var/lib/postgresql/walshipping/data.master.1
    chown -R postgres:postgres /var/lib/postgresql/walshipping/data.master.1

    # drop default cluster
    pg_dropcluster --stop ${PG_VERSION} main
}

function setup_master {
    #create cluster with ru_RU.UTF-8
    pg_createcluster --locale=ru_RU.UTF-8 --encoding=UTF-8 ${PG_VERSION} main

    # allow standby to connect
    mkdir -p -m 0755 /etc/postgresql/${PG_VERSION}/main/conf.d
    chown -R postgres:postgres /etc/postgresql/${PG_VERSION}/main/conf.d

    sudo -u postgres cat << EOF >> /etc/postgresql/${PG_VERSION}/main/pg_hba_custom.conf
host    all             all             127.0.0.1/32            trust
local   all             all                                     trust
host all all ${STANDBY_IP}/32 trust
host replication all ${STANDBY_IP}/32 trust
EOF

    sudo -u postgres cat << EOF >> /etc/postgresql/${PG_VERSION}/main/conf.d/replica.conf
hba_file = '/etc/postgresql/${PG_VERSION}/main/pg_hba_custom.conf'
wal_level = logical
listen_addresses = '*'
max_wal_senders = 6
EOF

    # start cluster
    pg_ctlcluster ${PG_VERSION} main start

    #create db and install extension
    sudo -u postgres psql -c "CREATE DATABASE test";
    sudo -u postgres psql -d test -c "CREATE EXTENSION \"uuid-ossp\"";
    sudo -u postgres psql -d test -c "CREATE EXTENSION pgstattuple";
}

function prepare_upgraded_master {
    # allow standby to connect on future upgraded version
    mkdir -p -m 0755 /etc/postgresql/${PG_VERSION_UPGRADE_TO}/main/conf.d
    chown -R postgres:postgres /etc/postgresql/${PG_VERSION_UPGRADE_TO}/main/conf.d
    chown -R postgres:postgres /etc/postgresql/${PG_VERSION_UPGRADE_TO}/main

    sudo -u postgres cat << EOF >> /etc/postgresql/${PG_VERSION_UPGRADE_TO}/main/pg_hba_custom.conf
host    all             all             127.0.0.1/32            trust
local   all             all                                     trust
host all all ${STANDBY_IP}/32 trust
host replication all ${STANDBY_IP}/32 trust
EOF

    sudo -u postgres cat << EOF >> /etc/postgresql/${PG_VERSION_UPGRADE_TO}/main/conf.d/replica.conf
hba_file = '/etc/postgresql/${PG_VERSION}/main/pg_hba_custom.conf'
wal_level = logical
listen_addresses = '*'
max_wal_senders = 6
EOF
}

PROVISIONED_ON=/etc/vm_provision_on_timestamp
if [ -f "$PROVISIONED_ON" ]
then
  echo "VM was already provisioned at: $(cat $PROVISIONED_ON)"
  exit
fi

setup_environment

setup_master

prepare_upgraded_master

# generate postgres ssh key
sudo -u postgres ssh-keygen -f /var/lib/postgresql/.ssh/id_rsa -t rsa -N ''

# Tag the provision time:
date > "$PROVISIONED_ON"

echo "Successfully created PostgreSQL "