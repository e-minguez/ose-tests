## List of images used by the tests

```bash
for node in $(oc get nodes -o name);do oc debug ${node} -- chroot /host sh -c 'crictl images -o json' 2>/dev/null | jq -r .images[].repoTags[]; done | sort -u

docker.io/library/nginx:1.14-alpine
kni1-bootstrap.cloud.lab.eng.bos.redhat.com:<none>
quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:<none>
registry.redhat.io/rhel7/support-tools:latest
us.gcr.io/k8s-artifacts-prod/e2e-test-images/agnhost:2.12
```

The only ones required are:

* `us.gcr.io/k8s-artifacts-prod/e2e-test-images/agnhost:2.12`
* `docker.io/library/nginx:1.14-alpine`

## Make the images offline

```bash
export IMAGES="docker.io/library/nginx:1.14-alpine us.gcr.io/k8s-artifacts-prod/e2e-test-images/agnhost:2.12"
tar cvf image-files.tar --files-from /dev/null
for image in ${IMAGES}; do
  podman pull ${image}
  podman save > ${image##*/}.tar ${image}
  tar rvf image-files.tar ${image##*/}.tar
  rm -f ${image##*/}.tar
done
gzip image-files.tar
```

```bash
for node in $(oc get nodes -o name); do
  oc debug ${node} -- chroot /host sh -c 'cat > /tmp/image-files.tar.gz' <(cat image-files.tar.gz)
  oc debug ${node} -- chroot /host sh -c 'tar xzvf /tmp/image-files.tar.gz'
  for image in ${IMAGES}; do
    oc debug ${node} -- chroot /host sh -c 'cat /tmp/${image##*/}.tar | podman import - ${image} && rm -f /tmp/${image##*/}.tar'
  done
done
```
