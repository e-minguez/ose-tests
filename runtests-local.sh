#!/bin/bash
if [ ! -d /tests/ ]; then
    echo "tests directory not found!"
    exit 1
fi

if [ ! -f /tests/kubeconfig ]; then
    echo "KUBECONFIG file not found!"
    exit 1
fi

DATE="$(date +%Y%m%d-%H%M%S)"
mkdir -p "${DATE}"

export KUBECONFIG=/tests/kubeconfig 
/usr/local/bin/allobjects.sh > /tests/"${DATE}"/before.out
for file in /usr/local/share/ose-tests/*.txt; do
  # If some tests fail, continue the execution
  /usr/bin/openshift-tests run --junit-dir=/tests/"${DATE}"/ -f "${file}" -o /tests/"${DATE}"/"${file##*/}" || true
done
/usr/local/bin/allobjects.sh > /tests/"${DATE}"/after.out
scl enable python27 "junit2html /tests/${DATE}/junit*.xml"

exit 0