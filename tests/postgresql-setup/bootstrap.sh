#!/bin/sh -e

# Edit the following to change the version of PostgreSQL that is installed
PG_VERSION=9.4

PROVISIONED_ON=/etc/vm_provision_on_timestamp
if [ -f "$PROVISIONED_ON" ]
then
  echo "VM was already provisioned at: $(cat $PROVISIONED_ON)"
  exit
fi

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

# drop default cluster
pg_dropcluster --stop ${PG_VERSION} main

#create cluster with ru_RU.UTF-8
pg_createcluster --locale=ru_RU.UTF-8 --encoding=UTF-8 ${PG_VERSION} main

# start cluster
pg_ctlcluster ${PG_VERSION} main start

# Tag the provision time:
date > "$PROVISIONED_ON"

echo "Successfully created PostgreSQL "