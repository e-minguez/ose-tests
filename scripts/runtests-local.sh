#!/bin/bash
if [ ! -d /tests/ ]; then
  echo "tests directory not found!"
  exit 1
fi

if [ ! -f /tests/kubeconfig ]; then
  echo "KUBECONFIG file not found!"
  exit 1
fi

if [ ! -f /usr/local/share/ose-tests/"${TESTS}".txt ]; then
  echo "${TESTS} file not found!, using all.txt instead"
  FILE="/usr/local/share/ose-tests/all.txt"
else
  FILE="/usr/local/share/ose-tests/${TESTS}.txt"
fi

DESTDIR=/tests/"$(date +%Y%m%d-%H%M%S)"
mkdir -p "${DESTDIR}"

export KUBECONFIG=/tests/kubeconfig 
/usr/local/bin/allobjects.sh > "${DESTDIR}"/before.out
# If some tests fail, continue the execution
/usr/bin/openshift-tests run --junit-dir="${DESTDIR}"/ -f "${FILE}" -o "${DESTDIR}"/"${FILE##*/}" || true
# Wait some seconds for temporary namespaces to be deleted
sleep 20
/usr/local/bin/allobjects.sh > "${DESTDIR}"/after.out
scl enable python27 "junit2html ${DESTDIR}/junit*.xml"

# Generate a diff file
git diff --unified=0 --word-diff-regex="[^[:space:]:]+" "${DESTDIR}"/before.out "${DESTDIR}"/after.out > "${DESTDIR}"/diff.out

exit 0