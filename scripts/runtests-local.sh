#!/bin/bash
die(){
  >&2 echo "${1}"
  exit "${2}"
}

# Some checks before running the tests
if [ ! -d /tests/ ]; then
  die "tests directory not found!" 1
fi

if [ ! -f /tests/kubeconfig ]; then
  die "KUBECONFIG file not found (it must be located in /tests/kubeconfig)" 1
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

export KUBECONFIG=/tests/kubeconfig 

# https://superuser.com/q/363444/165006
if ! WHOAMI=$(oc whoami 2>&1); then
  die "${WHOAMI}" 2
fi

# Create a directory to store the assets
DESTDIR=/tests/"$(date +%Y%m%d-%H%M%S)"
mkdir -p "${DESTDIR}" || die "Error creating the ${DESTDIR} directory" 2

echo -n "Collecting the cluster status before running the tests..."
# Get all the objects. Redirect stdout to avoid 
# 'notfound' and 'Forbidden' messages as it is not executed as cluster-admin
/usr/local/bin/allobjects.sh > "${DESTDIR}"/before.out 2> /dev/null || \
  die "Error collecting the cluster status before running the tests" 2
echo "Done"
echo "Running the tests as ${WHOAMI}"
# Wait a few seconds to let the API settle
# as we stressed it with the allobjects script
sleep 10
# If some tests fail, continue the execution
/usr/bin/openshift-tests run --max-parallel-tests "${PARALLEL}" \
                             --count "${TIMES}" \
                             --junit-dir="${DESTDIR}"/ \
                             -f "${FILE}" \
                             -o "${DESTDIR}"/"${FILE##*/}" || true
# Wait some seconds for temporary namespaces to be deleted
sleep 20
echo -n "Collecting the cluster status after running the tests..."
# Get all the objects. Redirect stdout to avoid 
# 'notfound' and 'Forbidden' messages as it is not executed as cluster-admin
/usr/local/bin/allobjects.sh > "${DESTDIR}"/after.out 2> /dev/null || \
  die "Error collecting the cluster status after running the tests" 2
echo "Done"

# Being able to output html is nicer
echo -n "Converting junit xml to html..."
scl enable python27 "junit2html ${DESTDIR}/junit*.xml" || \
  die "Error converting junit xml to html" 2
echo "Done"

echo -n "Generating a cluster status diff before and after running the tests..."
# Generate a diff file
# git diff exit code = 1 if diff, otherwise 0, hence && instead ||
git diff --unified=0 \
         --word-diff-regex="[^[:space:]:]+" \
         "${DESTDIR}"/before.out \
         "${DESTDIR}"/after.out > "${DESTDIR}"/diff.out && \
        echo "There were no differences"
echo "Done"

exit 0
