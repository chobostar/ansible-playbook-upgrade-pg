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

# Test correct version upgrade:
# echo postgresql version
ssh -q vagrant@172.30.1.5 "sudo -u postgres psql -qt -c 'select version()'" | grep -q "PostgreSQL 9.6" && echo "TEST UPGRADE: OK" || echo "TEST UPGRADE: FAILED"

# Test updated extensions:
ssh -q vagrant@172.30.1.5 "sudo -u postgres psql -d test -t -c 'select * from pg_available_extensions where default_version != installed_version' | wc -l" | grep -q "1" && echo 'TEST EXTENSIONS: OK' || echo 'TEST EXTENSION: FAILED'

# Test rename current wal archiving dir
ssh -q vagrant@172.30.1.5 "if [ -d /var/lib/postgresql/walshipping/logs.complete_9.4 ]; then echo 'TEST ARCHIVE RENAME: OK'; else echo 'TEST ARCHIVE RENAME: FAILED'; fi"

# Test rename is exists archiving dir
ssh -q vagrant@172.30.1.5 "if [ -d /var/lib/postgresql/walshipping/logs.complete ]; then echo 'TEST NEW ARCHIVE CREATEDIR: OK'; else echo 'TEST NEW ARCHIVE CREATEDIR: FAILED'; fi"

# Test rename current backup dir 1:
ssh -q vagrant@172.30.1.5 "if [ -d /var/lib/postgresql/walshipping/9.4_data.master.0 ]; then echo 'TEST BACKUP1 RENAME: OK'; else echo 'TEST BACKUP1 RENAME: FAILED'; fi"

# Test rename current backup dir 2:
ssh -q vagrant@172.30.1.5 "if [ -d /var/lib/postgresql/walshipping/9.4_data.master.1 ]; then echo 'TEST BACKUP2 RENAME: OK'; else echo 'TEST BACKUP2 RENAME: FAILED'; fi"

# destroy vagrant
#vagrant destroy --force