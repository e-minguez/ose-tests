#!/bin/bash

./allobjects.sh > before.out

podman run -it --rm -v "${PWD}":/tests:Z -e KUBECONFIG=/tests/nonadmin.kubeconfig \
  quay.io/eminguez/ose-tests:latest /bin/bash -c '/usr/bin/openshift-tests run --junit-dir=/tests/ -f /tests/openshift-conformance-minimal.txt -o /tests/output.txt'

./allobjects.sh > after.out
