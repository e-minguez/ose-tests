# ose-tests

## Prerequisites

### Packages

* Enable epel to install some packages

In RHEL8:

```bash
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
ARCH=$( /bin/arch )
sudo subscription-manager repos --enable "codeready-builder-for-rhel-8-${ARCH}-rpms"
```

* Install parallel, jq and podman (if not installed already):

```bash
sudo yum install -y parallel jq podman
```

### oc

The `oc` cli should be installed/available

## Add a non cluster-admin user

Add a user to the cluster (this requires cluster-admin permissions). This example uses an htpasswd auth backend already created. Your mileage may vary.

```bash
oc get secret htpass-secret -ojsonpath={.data.htpasswd} -n openshift-config | base64 -d > users.htpasswd

htpasswd -bB users.htpasswd nonadmin nonadmin
Adding password for user nonadmin

oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd --dry-run -o yaml -n openshift-config | oc replace -f -
secret/htpass-secret replaced

# This will generate a /tmp/nonadmin.kubeconfig file
export KUBECONFIG=./nonadmin.kubeconfig
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
./runtests.sh
```

## Verify the differences

```bash
diff ./before.out ./after.out
```
