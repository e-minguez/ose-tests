#!/bin/bash
if [ ! -d /tests/ ]; then
  echo "tests directory not found!"
  exit 1
fi

if [ ! -f /tests/kubeconfig ]; then
  echo "KUBECONFIG file not found (it must be located in /tests/kubeconfig)"
  exit 1
fi

if [ ! -f /usr/local/share/ose-tests/"${TESTS}".txt ]; then
  echo "${TESTS} file not found!, using all-non-disruptive.txt instead"
  FILE="/usr/local/share/ose-tests/all-non-disruptive.txt"
else
  FILE="/usr/local/share/ose-tests/${TESTS}.txt"
fi

# --count
TIMES=${TIMES:-1}
# --max-parallel-tests
PARALLEL=${PARALLEL:-0}

DESTDIR=/tests/"$(date +%Y%m%d-%H%M%S)"
mkdir -p "${DESTDIR}"

export KUBECONFIG=/tests/kubeconfig 

echo "Running the tests as $(oc whoami)"
# Get all the objects. Redirect stdout to avoid 'notfound' and 'Forbidden' messages as it is not executed as cluster-admin
/usr/local/bin/allobjects.sh > "${DESTDIR}"/before.out 2> /dev/null
# Wait a few seconds to let the API settle as we stressed it with the allobjects script
sleep 10
# If some tests fail, continue the execution
/usr/bin/openshift-tests run --max-parallel-tests "${PARALLEL}" --count "${TIMES}" --junit-dir="${DESTDIR}"/ -f "${FILE}" -o "${DESTDIR}"/"${FILE##*/}" || true
# Wait some seconds for temporary namespaces to be deleted
sleep 20
# Get all the objects. Redirect stdout to avoid 'notfound' and 'Forbidden' messages as it is not executed as cluster-admin
/usr/local/bin/allobjects.sh > "${DESTDIR}"/after.out 2> /dev/null
scl enable python27 "junit2html ${DESTDIR}/junit*.xml"

# Generate a diff file
git diff --unified=0 --word-diff-regex="[^[:space:]:]+" "${DESTDIR}"/before.out "${DESTDIR}"/after.out > "${DESTDIR}"/diff.out

exit 0
