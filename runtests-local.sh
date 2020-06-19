#!/bin/bash
export KUBECONFIG=/tests/kubeconfig 
./allobjects.sh > /tests/before.out
/usr/bin/openshift-tests run --junit-dir=/tests/ -f /tests/openshift-conformance-minimal.txt -o /tests/output.txt
./allobjects.sh > /tests/after.out
scl enable python27 "junit2html /tests/junit*.xml"