#!/usr/bin/env bash

# change directory to script location
cd "$(dirname "$0")"

# ensure if vagrant not exists
vagrant destroy --force

# create vm with PostgreSQL server
vagrant up

# test ssh connection
ssh -q -o ConnectTimeout=90 vagrant@172.30.1.5 "exit"

# run playbook
ansible-playbook deploy_upgrade_on_vm.yml -i hosts -e "operate=yes"

# echo postgresql version
ssh -q vagrant@172.30.1.5 "sudo -u postgres psql -qt -c 'select version()'" | grep -q "PostgreSQL 9.6" && echo "TEST OK" || echo "TEST FAILED"

# destroy vagrant
vagrant destroy --force