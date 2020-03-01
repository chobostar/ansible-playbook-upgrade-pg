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

function setup_standby {
    #create cluster with ru_RU.UTF-8
    pg_createcluster --locale=ru_RU.UTF-8 --encoding=UTF-8 ${PG_VERSION} main

    rm -rf /var/lib/postgresql/${PG_VERSION}/main

    sudo -u postgres cat << EOF >> /etc/postgresql/${PG_VERSION}/main/postgresql.conf
wal_level = logical
listen_addresses = '*'
hot_standby = on
EOF

    sudo -u postgres cat << EOF > /etc/postgresql/${PG_VERSION}/main/recovery.conf
primary_conninfo = 'host=172.30.1.5 port=5432'
standby_mode = on
EOF

    sudo -u postgres pg_basebackup -v -c fast -X stream -D /var/lib/postgresql/${PG_VERSION}/main -h ${MASTER_IP}
    sudo -u postgres ln -s /etc/postgresql/${PG_VERSION}/main/recovery.conf /var/lib/postgresql/${PG_VERSION}/main/
    sleep 3
    sudo pg_ctlcluster ${PG_VERSION} main start
}

function prepare_upgraded_standby {
    apt-get -y install "postgresql-$PG_VERSION_UPGRADE_TO" "postgresql-contrib-$PG_VERSION_UPGRADE_TO" "postgresql-client-$PG_VERSION_UPGRADE_TO"

    mkdir -p -m 0755 /etc/postgresql/${PG_VERSION_UPGRADE_TO}/main/conf.d
    chown -R postgres:postgres /etc/postgresql/${PG_VERSION_UPGRADE_TO}/main/conf.d
    chown -R postgres:postgres /etc/postgresql/${PG_VERSION_UPGRADE_TO}/main

    sudo -u postgres cat << EOF > /etc/postgresql/${PG_VERSION_UPGRADE_TO}/main/recovery.conf
primary_conninfo = 'host=172.30.1.5 port=5432'
standby_mode = on
EOF

    sudo -u postgres cat << EOF >> /etc/postgresql/${PG_VERSION_UPGRADE_TO}/main/conf.d/replica.conf
port = 5432
wal_level = logical
listen_addresses = '*'
hot_standby = on
EOF

    #create and del pgdata of new cluster
    pg_createcluster --locale=ru_RU.UTF-8 --encoding=UTF-8 ${PG_VERSION} main
    pg_ctlcluster 9.6 main stop

    rm -rf /var/lib/postgresql/${PG_VERSION_UPGRADE_TO}/*
}

PROVISIONED_ON=/etc/vm_provision_on_timestamp
if [ -f "$PROVISIONED_ON" ]
then
  echo "VM was already provisioned at: $(cat $PROVISIONED_ON)"
  exit
fi

setup_environment

setup_standby

prepare_upgraded_standby

# Tag the provision time:
date > "$PROVISIONED_ON"

echo "Successfully created PostgreSQL "