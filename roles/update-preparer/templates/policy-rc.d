#!/usr/bin/env bash

### THIS FILE CONTROLLED BY PUPPET ###

# Do not stop, start, restart services:
ignore_service_patterns="^postgresql(\$|@) ^pgbouncer(\$|@)"

service="$1"

for s in $ignore_service_patterns ; do
    if [[ "$service" =~ $s ]]; then
        exit 101
    fi
done

exit 0