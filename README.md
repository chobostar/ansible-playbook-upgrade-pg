Ansible playbook to deploy postgresql updates on Debian Linux
=============================================================

Graceful way to minor update of PostgreSQL instance

And major upgrade of PostgreSQL Cluster master with 2 standbys 

features:
- performs all checks before operate
    - ssh access for rsync
    - standbys circumstaces: replication lag, existing directories
- handles additional tablespaces
- handles PgBouncer
- uses aggressive way of analyze after upgrade (with cancel wraparound vacuums)
- handles column level custom statistics for faster analyze
- mocks policy-rc.d to prevent undesirable postgresql restart

#### Install
on Ubuntu:
```
apt-get update
apt-get install software-properties-common
apt-add-repository --yes --update ppa:ansible/ansible
apt-get install ansible

pip install python-apt
# or
# apt-get install python-apt
```


#### Requirements

Debian 8, 9 <br>
PostgreSQL 9.6 <br>
PgBouncer 1.7.2 or newer<br>
Ansible 2.7 or newer<br>

Vagrant for testing 

<br>

#### Example upgrade major version

Step 1. Prepare inventory file (inventory)

```ini
pgsql00
```

Step 2. Fill up host_vars ( host_vars/pgsql00/main.yml )
```yaml
postgresql_version: "9.4"
postgresql_cluster_names:
- main

postgresql_upgrade_version_to: "9.6"

postgresql_packages:
- 'postgresql-{{ postgresql_version }}'
- 'postgresql-{{ postgresql_version }}-dbg'
- 'postgresql-client-{{ postgresql_version }}'
- 'postgresql-contrib-{{ postgresql_version }}'
- 'postgresql-plperl-{{ postgresql_version }}'
- 'postgresql-plpython-{{ postgresql_version }}'

postgresql_upgrade_packages:
- 'postgresql-{{ postgresql_upgrade_version_to }}'
- 'postgresql-{{ postgresql_upgrade_version_to }}-dbg'
- 'postgresql-client-{{ postgresql_upgrade_version_to }}'
- 'postgresql-contrib-{{ postgresql_upgrade_version_to }}'
- 'postgresql-plperl-{{ postgresql_upgrade_version_to }}'
- 'postgresql-plpython-{{ postgresql_upgrade_version_to }}'

pgbouncer_instances:
- { name: pgbouncer-dev, action: stop, port: 6404 }
- { name: pgbouncer-server, action: stop, port: 6432 }

is_puppet_managed: true
is_testing: false
remove_synchronous_commit: false
```

Step 3. Define upgrade playbook (deploy_upgrade.yml)
(set your own ssh remote_user)
```yaml
- name: Deploy postgresql upgrade
  become: true
  gather_facts: true
  remote_user: <remote_user>
  no_log: false
  strategy: free
  roles:
  - update-preparer
  - postgresql-upgrade
  hosts:
  - pgsql00
```

Step 4. Run playbook (with variable `operate=yes`)
```bash
ansible-playbook deploy_upgrade.yml -i inventory -e operate=yes
```

<br>

#### Example of update minor version

Step 1. Prepare inventory file:
```ini
pgsql00
```

Step 2. Fill up host_vars ( host_vars/pgsql00/main.yml ):
```yaml
postgresql_version: "9.6"
postgresql_cluster_names:
  - main
postgresql_packages:
  - 'postgresql-{{ postgresql_version }}'
  - 'postgresql-{{ postgresql_version }}-dbg'
  
pgbouncer_instances:
  - { name: pgbouncer-dev, action: stop, port: 6404 }
  - { name: pgbouncer-server, action: pause, port: 6432 }
```
and group_vars ( group_vars/stretch/main.yml ):
```yaml
apt_repos:
- "deb http://apt.postgresql.org/pub/repos/apt stretch-pgdg main"
```

Step 3-a. install only binaries without cluster restart:
```
ansible-playbook update_pg.yml -i inventory
```

Step 3-b. install and cluster restart (variable `operate` is defined):
```
ansible-playbook update_pg.yml -i inventory -e operate=yes
```

<br>

#### Run tests

```bash
# ssh-keygen
$ apt-get install virtualbox vagrant
$ tests/standalone/run_pgupgrade_test.sh
```

it will run vagrant with postgresql 9.4, apply playbook and print tests results.<br>
 - test environment bootstrap: tests/standalone/postgresql-setup/bootstrap.sh<br>
 - variables for test environment: tests/standalone/vars/postgresql.yml<br>

Case with pg_upgrade with rsync cluster of master plus standby:
```bash
$ tests/master_standby_vm/run_pgupgrade_test.sh
```

#### Notes
If you use `vacuum_defer_cleanup_age`, remove it before upgrade: https://www.postgresql.org/message-id/15615-a64615b9b466c18f%40postgresql.org

#### Links
- Vagrant setup: https://github.com/jackdb/pg-app-dev-vm
- pg_upgrade: https://www.postgresql.org/docs/current/pgupgrade.html
- one the best check list: https://bricklen.github.io/2018-03-27-Postgres-10-upgrade/
- statistics hack (use on your own risk!): https://postgrespro.com/docs/postgrespro/9.6/dump-stat
- https://www.depesz.com/2016/11/08/major-version-upgrading-with-minimal-downtime/
- https://www.depesz.com/2015/02/27/how-to-pg_upgrade/
- https://aws.amazon.com/ru/blogs/database/best-practices-for-upgrading-amazon-rds-to-major-and-minor-versions-of-postgresql/
- https://why-upgrade.depesz.com/
- pg_upgrade internals: https://momjian.us/main/writings/pgsql/pg_upgrade.pdf
