#!/bin/bash
export KUBECONFIG=/tests/kubeconfig 
/usr/local/bin/allobjects.sh > /tests/before.out
for file in /usr/local/share/ose-tests/*.txt; do
  /usr/bin/openshift-tests run --junit-dir=/tests/ -f "${file}" -o /tests/"${file##*/}"
done
/usr/local/bin/allobjects.sh > /tests/after.out
scl enable python27 "junit2html /tests/junit*.xml"