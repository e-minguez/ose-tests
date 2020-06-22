#!/bin/bash
if [ ! -d /tests/ ]; then
    echo "tests directory not found!"
    exit 1
fi

if [ ! -f /tests/kubeconfig ]; then
    echo "KUBECONFIG file not found!"
    exit 1
fi

DESTDIR=/tests/"$(date +%Y%m%d-%H%M%S)"
mkdir -p "${DESTDIR}"

export KUBECONFIG=/tests/kubeconfig 
/usr/local/bin/allobjects.sh > "${DESTDIR}"/before.out
for file in /usr/local/share/ose-tests/*.txt; do
  # If some tests fail, continue the execution
  /usr/bin/openshift-tests run --junit-dir="${DESTDIR}"/ -f "${file}" -o "${DESTDIR}"/"${file##*/}" || true
done
/usr/local/bin/allobjects.sh > "${DESTDIR}"/after.out
scl enable python27 "junit2html ${DESTDIR}/junit*.xml"

exit 0