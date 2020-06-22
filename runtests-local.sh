#!/bin/bash
if [ ! -d /tests/ ]; then
    echo "tests directory not found!"
    exit 1
fi

if [ ! -f /tests/kubeconfig ]; then
    echo "KUBECONFIG file not found!"
    exit 1
fi

export KUBECONFIG=/tests/kubeconfig 
/usr/local/bin/allobjects.sh > /tests/before-"$(date +%Y%m%d-%H%M%S)".out
for file in /usr/local/share/ose-tests/*.txt; do
  # If some tests fail, continue the execution
  /usr/bin/openshift-tests run --junit-dir=/tests/ -f "${file}" -o /tests/"$(date +%Y%m%d-%H%M%S)"-"${file##*/}" || true
done
/usr/local/bin/allobjects.sh > /tests/after-"$(date +%Y%m%d-%H%M%S)".out
scl enable python27 "junit2html /tests/junit*.xml"

exit 0