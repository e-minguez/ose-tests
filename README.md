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

Add a user to the cluster (this requires cluster-admin permissions). This example uses an htpasswd auth backend already created. Your mileage may vary.

```bash
oc get secret htpass-secret -ojsonpath={.data.htpasswd} -n openshift-config | base64 -d > "${OUTPUTDIR}"/users.htpasswd

htpasswd -bB "${OUTPUTDIR}"/users.htpasswd nonadmin nonadmin
Adding password for user nonadmin

# Verify the file "${OUTPUTDIR}"/users.htpasswd contains at least the admin and nonadmin lines

oc create secret generic htpass-secret --from-file=htpasswd="${OUTPUTDIR}"/users.htpasswd --dry-run -o yaml -n openshift-config | oc replace -f -
secret/htpass-secret replaced

# This will generate a "${OUTPUTDIR}"/kubeconfig file
export KUBECONFIG="${OUTPUTDIR}"/kubeconfig
# Maybe you need to wait a while for the user to be created...
oc login --insecure-skip-tls-verify=true -u nonadmin -p nonadmin https://api.example.com:6443
```

Create a self-provisioner-namespace cluster role that allows namespace creation/deletion and assign that cluster role to the user as well as the 'admin' role (no cluster-admin, just admin):

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

## Run the tests

```bash
podman run --rm -v ${OUTPUTDIR}:/tests:Z quay.io/eminguez/ose-tests-full:latest
```

## Explanations and files

In order to run the tests as non cluster-admin, a modification in the code is needed (see [here](https://github.com/openshift/origin/issues/25084) for more information).

Instead compiling your own openshift-tests binary and provide an easier method, a couple of container images have been created:

* [https://quay.io/repository/eminguez/ose-tests](https://github.com/e-minguez/origin/blob/cluster-admin-not-needed/images/tests/Dockerfile.rhel). This is the same image used by the openshift-tests but using public images, `registry.redhat.io/rhel8/go-toolset:1.13` (vs `registry.svc.ci.openshift.org/ocp/builder:golang-1.13`) & `registry.redhat.io/openshift4/ose-cli:v4.4` (vs `registry.svc.ci.openshift.org/ocp/4.2:cli`)
* [https://quay.io/repository/eminguez/ose-tests-full](Dockerfile). This image contains some scripts to make it easy the execution of the ose-tests, as well as [the lists of tests](tests-lists/) that would be executed proved to be successfully executed as non cluster-admin.

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

Basically comment out (or just remove) the line `TestContext.CreateTestingNS = createTestingNS` from the `test/extended/util/test.go` file ([line 93](https://github.com/openshift/origin/blob/master/test/extended/util/test.go#L93) at the moment of writting this file). See [here](https://github.com/openshift/origin/issues/25084) for more information.

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
