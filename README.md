# ose-tests as non cluster-admin

## Prerequisites

### podman

A container with the ose-tests will be executed as part of the procedure. In order to run the container, podman must be available in the host. The container will be executed with the current user permissions, there is no need to run it as root.

### Temporary folder to store the assets

```bash
export OUTPUTDIR="${HOME}/ose-tests/"
mkdir -p "${OUTPUTDIR}"
cd ${OUTPUTDIR}
```

### oc

The `oc` cli should be installed/available.

### A cluster-admin kubeconfig

In order to create a user and a custom role, cluster-admin permissions are required.

```bash
export KUBECONFIG=/path/to/my/cluster-admin.kubeconfig
```

### A non cluster-admin user

Add a user to the cluster (this requires cluster-admin permissions). This example uses an htpasswd auth backend. Your mileage may vary.

To setup a htpasswd auth backend:

```bash
cat << EOF | oc apply -f -
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: htpassidp
    challenge: true
    login: true
    mappingMethod: claim
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-secret
EOF
```

Let's create an 'admin/admin' user with cluster-admin permissions:

```bash
# Using htpasswd provided by the httpd-tools package
ADMINPASS=$(htpasswd -b -n admin admin | base64)
cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: htpass-secret
  namespace: openshift-config
data:
  htpasswd: ${ADMINPASS}
EOF
# It can take a few moments for the user to be created...
oc adm policy add-cluster-role-to-user cluster-admin admin
```

Then create a 'nonadmin/nonadmin' user:

```bash
# Extract the already created secret from the cluster
oc get secret htpass-secret -ojsonpath="{.data.htpasswd}" -n openshift-config | base64 -d > "${OUTPUTDIR}"/users.htpasswd

# Append the nonadmin user
htpasswd -bB "${OUTPUTDIR}"/users.htpasswd nonadmin nonadmin

# Verify the file "${OUTPUTDIR}"/users.htpasswd contains at least the admin and nonadmin lines

# Instead creating the secret with the here-doc syntax, you can use create secret instead
oc create secret generic htpass-secret --from-file=htpasswd="${OUTPUTDIR}"/users.htpasswd --dry-run -o yaml -n openshift-config | oc replace -f -

# This will generate a "${OUTPUTDIR}"/kubeconfig file
export KUBECONFIG="${OUTPUTDIR}"/kubeconfig
# It can take a few moments for the user to be created...
oc login --insecure-skip-tls-verify=true -u nonadmin -p nonadmin https://api.example.com:6443
```

### Privileging The Non-Admin User

Each test suite will eventually have its own role that empower the user account running the test to perform the actions required by the given tests suite.

#### For each test suite

As `cluster-admin`, create a custom cluster role that contains all the user rights required to run this suite by performing an `oc create` on role definition located in the rbac directory of this repository. The role used depends on the test suite being ran:

* [all-non-disruptive](rbac/osetests-all-non-disruptive.yaml) - The default one.

```bash
oc auth reconcile -f https://raw.githubusercontent.com/e-minguez/ose-tests/master/rbac/osetests-all-non-disruptive.yaml
```

* [openshift-conformance-minimal](rbac/osetests-openshift-conformance-minimal.yaml)

```bash
oc auth reconcile -f https://raw.githubusercontent.com/e-minguez/ose-tests/master/rbac/osetests-openshift-conformance-minimal.yaml
```

* [openshift-conformance](rbac/osetests-openshift-conformance.yaml)

```bash
oc auth reconcile -f https://raw.githubusercontent.com/e-minguez/ose-tests/master/rbac/osetests-openshift-conformance.yaml
```

* [kubernetes-conformance](rbac/osetests-kubernetes-conformance.yaml)

```bash
oc auth reconcile -f https://raw.githubusercontent.com/e-minguez/ose-tests/master/rbac/osetests-kubernetes-conformance.yaml
```

It's advisable to wait a few minutes to let the custom role propagate to avoid any potentially undesirable results. Once you're sure the role has successfully propagated you can assign it to the nonadmin user (again as the cluster-admin user from before):

```bash
oc adm policy add-cluster-role-to-user <cluster-role> nonadmin
```

Where `<cluster-role>` is the cluster role created before (osetests-<suite>)

and then wait another few minutes or so.

#### General permissions

If you don't want to create a specific cluster-role for each test suite, you can
create a self-provisioner-namespace cluster role that allows namespace
creation/deletion and assign that cluster role to the user as well as the
'admin' role (no cluster-admin, just admin):

```bash
# As a cluster-admin user:
export KUBECONFIG=/path/to/my/cluster-admin.kubeconfig
cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    openshift.io/description: A user that can create and delete namespaces
  name: self-provisioner-namespaces
rules:
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - "*"
EOF

oc adm policy add-cluster-role-to-user admin nonadmin
oc adm policy add-cluster-role-to-user cluster-reader nonadmin
oc adm policy add-cluster-role-to-user self-provisioner-namespaces nonadmin
# It can take a while for the user to be given the permissions
```

### Tests

The container image includes a few lists proven to be successfully executed with non cluster-admin permissions. In order to specify the tests list that the execution will run, the `TESTS` environmental variable is used as `-e TESTS=<filename>`, where filename is:

* [openshift-conformance-minimal](tests-lists/openshift-conformance-minimal.txt). Based on the openshift/conformance/parallel/minimal tests suite (`openshift-tests run all --dry-run 2>/dev/null| grep "openshift/conformance/parallel/minimal" | grep -v -i "clusteradmin"` and extracted the ones that passed with non cluster-admin permissions)
* [openshift-conformance](tests-lists/openshift-conformance.txt). Based on the openshift/conformance tests suite (`openshift-tests run openshift/conformance --dry-run | grep -v -i "clusteradmin"` and extracted the ones that passed with non cluster-admin permissions)
* [kubernetes-conformance](tests-lists/kubernetes-conformance.txt).  Based on the kubernetes/conformance tests suite (`openshift-tests run kubernetes/conformance --dry-run | grep -v -i "clusteradmin"` and extracted the ones that passed with non cluster-admin permissions)
* [openshift-network-stress](tests-lists/openshift-network-stress.txt).  Based on the openshift/network/stress tests suite (`openshift-tests run  openshift/network/stress --dry-run | grep -v -i "clusteradmin"` and extracted the ones that passed with non cluster-admin permissions)
* [openshift-conformance-excluded-non-disruptive](tests-lists/openshift-conformance-excluded-non-disruptive.txt).  Based on the openshift/conformance-excluded tests suite (`openshift-tests run openshift/conformance-excluded --dry-run | grep -v -i "clusteradmin" | grep -v -i "disruptive"` and extracted the ones that passed with non cluster-admin permissions)
* [openshift-conformance-excluded-disruptive](tests-lists/openshift-conformance-excluded-disruptive.txt).  Based on the openshift/conformance-excluded tests suite (`openshift-tests run openshift/conformance-excluded --dry-run | grep -v -i "clusteradmin" | grep -i "disruptive"` and extracted the ones that passed with non cluster-admin permissions. ***Please be aware that running this might affect your cluster in a disruptive way.***)
* [all-disruptive](tests-lists/all-disruptive.txt). All the tests previously mentioned which are ***disruptive***
* [all-non-disruptive](tests-lists/all-non-disruptive.txt). All the tests previously mentioned which are not disruptive

If no `TESTS` environmental variable is used (or it is set to an incorrect value), the `all` suite is used.

For more information about the tests and the tests suite, see [https://github.com/openshift/origin/tree/master/test/extended](https://github.com/openshift/origin/tree/master/test/extended)

## Test suites that do not work with non cluster-admin permissions

The below suites fail to run as a non cluster-admin user. The expectation is that all of the tests will fail for this user

* openshift/build 
* openshift/templates
* openshift/image-registry
* openshift/image-ecosystem
* openshift/jenkins-e2e
* openshift/test-cmd

## Run the tests in disconnected environments

If the OCP environment doesn't have internet connectivity, it is required to 'preload' the images in the hosts container images cache. See [README-offline-images.md](README-offline-images.md) document before continuing.

## Run the tests

* [openshift-conformance-minimal](tests-lists/openshift-conformance-minimal.txt)

```bash
podman run --rm --name="ose-tests" -e TESTS="openshift-conformance-minimal" -v ${OUTPUTDIR}:/tests:Z quay.io/eminguez/ose-tests-full:latest
```

* [openshift-conformance](tests-lists/openshift-conformance.txt)

```bash
podman run --rm --name="ose-tests" -e TESTS="openshift-conformance" -v ${OUTPUTDIR}:/tests:Z quay.io/eminguez/ose-tests-full:latest
```

* [kubernetes-conformance](tests-lists/kubernetes-conformance.txt)

```bash
podman run --rm --name="ose-tests" -e TESTS="kubernetes-conformance" -v ${OUTPUTDIR}:/tests:Z quay.io/eminguez/ose-tests-full:latest
```

* [openshift-network-stress](tests-lists/openshift-network-stress.txt)

```bash
podman run --rm --name="ose-tests" -e TESTS="openshift-network-stress" -v ${OUTPUTDIR}:/tests:Z quay.io/eminguez/ose-tests-full:latest
```

* [openshift-conformance-excluded-non-disruptive](tests-lists/openshift-conformance-excluded-non-disruptive.txt)

```bash
podman run --rm --name="ose-tests" -e TESTS="openshift-conformance-excluded-non-disruptive" -v ${OUTPUTDIR}:/tests:Z quay.io/eminguez/ose-tests-full:latest
```

* [openshift-conformance-excluded-disruptive](tests-lists/openshift-conformance-excluded-disruptive.txt)

```bash
podman run --rm --name="ose-tests" -e TESTS="openshift-conformance-excluded-disruptive" -v ${OUTPUTDIR}:/tests:Z quay.io/eminguez/ose-tests-full:latest
```

* [all-disruptive](tests-lists/all-disruptive.txt)

```bash
podman run --rm --name="ose-tests" -e TESTS="all-disruptive" -v ${OUTPUTDIR}:/tests:Z quay.io/eminguez/ose-tests-full:latest
```

* [all-non-disruptive](tests-lists/all-non-disruptive.txt)

```bash
podman run --rm --name="ose-tests" -e TESTS="all-non-disruptive" -v ${OUTPUTDIR}:/tests:Z quay.io/eminguez/ose-tests-full:latest
```

or

```bash
podman run --rm --name="ose-tests" -v ${OUTPUTDIR}:/tests:Z quay.io/eminguez/ose-tests-full:latest
```

NOTE: When running rootless podman in RHEL8, an error similar to `ERRO[0546] unable to close namespace: "close /proc/33435/ns/user: bad file descriptor"` can happen. You can safely ignore the error message. What happens is that Podman closes all the files once it re-execs itself in the child user namespace, and the userns/mountns file descriptors were mistakenly closed twice. See [this issue](https://github.com/containers/libpod/issues/5626) for more information.

## Tests execution options

The `openshift-tests` binary accepts some parameters that are wrapped into a script so there is no need to specify any option.

However, there are some parameters that can be used:

* `TIMES` to run each test a specified number of times (1 by default or the test suite's preferred value) as:

```bash
podman run --rm --name="ose-tests" -e TIMES="2" -e TESTS="all-non-disruptive" -v ${OUTPUTDIR}:/tests:Z quay.io/eminguez/ose-tests-full:latest
```

* `PARALLEL` to specify the maximum number of tests running in parallel (0 by default to test suite recommended value, which is different in each suite) as:

```bash
podman run --rm --name="ose-tests" -e PARALLEL="1" -e TESTS="all-non-disruptive" -v ${OUTPUTDIR}:/tests:Z quay.io/eminguez/ose-tests-full:latest
```

NOTE: The parameters can be used simultaneously like:

```bash
podman run --rm --name="ose-tests" -e PARALLEL="1" -e TIMES="2" -e TESTS="all-non-disruptive" -v ${OUTPUTDIR}:/tests:Z quay.io/eminguez/ose-tests-full:latest
```

## Explanations and files

In order to run the tests as non cluster-admin, a modification in the code is needed (see [here](https://github.com/openshift/origin/issues/25084) for more information).

Instead compiling your own openshift-tests binary and provide an easier method, a couple of container images have been created:

* [https://quay.io/repository/eminguez/ose-tests](https://github.com/e-minguez/origin/blob/cluster-admin-not-needed/images/tests/Dockerfile.rhel). This is the same image used by the openshift-tests but using public images, `registry.redhat.io/rhel8/go-toolset:1.13` (vs `registry.svc.ci.openshift.org/ocp/builder:golang-1.13`) & `registry.redhat.io/openshift4/ose-cli:v4.4` (vs `registry.svc.ci.openshift.org/ocp/4.2:cli`) and the custom `openshift-tests` binary with the cluster-admin requisite removed.
* [https://quay.io/repository/eminguez/ose-tests-full](Dockerfile). This image extends the previous one and contains some [scripts](scripts/) to make it easy the execution of the ose-tests, as well as [the lists of tests](tests-lists/) that would be executed proved to be successfully executed as non cluster-admin.

### Files

```bash
/home/kni/ose-tests
├── 20200622-154054
│   ├── after.out
│   ├── before.out
│   ├── diff.out
│   ├── junit_e2e_20200622-154835.xml
│   ├── junit_e2e_20200622-154835.xml.html
│   └── openshift-conformance-minimal.txt
└── kubeconfig
```

### Tests execution

1. A folder based on the date & time the container has been executed is created. `20200622-154054` in the example.
2. A script is executed to query the API to gather all the information available to the non cluster-admin user previously created. This creates a [before.out](examples/before.out) file with a line per object as `/<api-path>/<resource>:<resourceversion>`
3. For every test suite in the [tests-lists](tests-lists/) folder, the `openshift-tests` binary is executed. The output is stored in a file based on the tests suite that has been executed, like [openshift-conformance-minimal.txt](examples/openshift-conformance-minimal.txt)
4. After the tests are executed, a script is executed to query the API to gather all the information available to the non cluster-admin user previously created. This creates an [after.out](examples/after.out) file with the same content than the [before.out](examples/before.out) one but after running the tests.
5. The junit output [XML file](examples/junit.xml) is converted to [html](examples/junit.html) to be easily consumable.
6. A diff is executed to [extract the modifications that happened to the cluster by running the tests](examples/diff.out).

### Diff explanation

The diff will show the resources in a git diff format:

* Added. Prepended by "{+"

```bash
grep "^{+" diff.out
{+/apis/events.k8s.io/v1beta1/namespaces/openshift-kube-scheduler/events/openshift-kube-scheduler-kni1-vmaster-2.1619ebb09ab0ea2e:1468963+}
...
```

* Deleted. Prepended by "[-"

```bash
grep "^\[-" diff.out
[-/api/v1/namespaces/whatever/pods/my-awesomepod:14627-]
...
```

* Modified. It will show the resource version that changed:

```bash
grep -v -E "^\[-|^{+" diff.out
/apis/operators.coreos.com/v1alpha1/namespaces/openshift-operator-lifecycle-manager/clusterserviceversions/packageserver:[-1492385-]{+1505051+}
...
```

NOTE: Due to the nature of OpenShift, some objects are constantly changing, such as configmaps used by the internal components, events, etc.

## Appendix - Run the tests in a loop and extract results

The tests can be executed in a for loop like:

```bash
for i in {0..10}; do echo "Run $i"; podman run --rm --name="ose-tests" -e TESTS="openshift-conformance-minimal" -v ${OUTPUTDIR}:/tests:Z quay.io/eminguez/ose-tests-full:latest; done
```

* Get tests passed/failed/skipped

```bash
find -name openshift-conformance-minimal.txt -print0 | xargs -0 tail -n1
```

Will output something similar to:

```bash
==> ./20200707-105323/openshift-conformance-minimal.txt <==
119 pass, 0 skip (8m2s)
==> ./20200707-111249/openshift-conformance-minimal.txt <==
119 pass, 0 skip (6m25s)
==> ./20200707-114659/openshift-conformance-minimal.txt <==
119 pass, 0 skip (7m31s)
==> ./20200707-113853/openshift-conformance-minimal.txt <==
119 pass, 0 skip (7m3s)
==> ./20200707-115535/openshift-conformance-minimal.txt <==
error: 1 fail, 118 pass, 0 skip (8m18s)
...
```

* Find unique tests that failed

```bash
find -name openshift-conformance-minimal.txt -print0 | xargs -I {} -0 sh -c "awk '/Failing tests:/,0' {} | grep '^\[.*'" | sort -u
```

* Find all tests that failed per run

```bash
find -name openshift-conformance-minimal.txt -print0 | xargs -I {} -0 sh -c "echo {}; awk '/Failing tests:/,0' {} | grep '^\[.*'"
```

## Appendix - Compile your own openshift-tests binary in RHEL8

Instead using the provisioned `openshift-tests` binary, this is the procedure to create a custom one in RHEL8

### Install golang 1.13

```bash
sudo yum install -y golang git
mkdir $HOME/go
```

### Get the source

```bash
go get -u -v github.com/openshift/origin
go get -u -v github.com/tools/godep
```

### (Optional) Remove the requisite for the tests to be cluster-admin

See [here](https://github.com/openshift/origin/issues/25084) for more information.

### Compile the openshift-tests binary

```bash
cd ~/go/src/github.com/openshift/origin/
make WHAT=cmd/openshift-tests
```

### Make the `openshift-tests` binary available

```bash
file _output/local/bin/linux/amd64/openshift-tests
_output/local/bin/linux/amd64/openshift-tests: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, for GNU/Linux 3.2.0, BuildID[sha1]=028ab749f31719c9ccf9446f16de84264f186361, stripped

chmod a+x _output/local/bin/linux/amd64/openshift-tests
sudo cp _output/local/bin/linux/amd64/openshift-tests /usr/local/bin/
```
