# How to make the images available offline

## List of images used by the tests

The following snippet will output the list of images already pulled in the cluster. In this case, it was executed after running the tests in a connected environment:

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

According to [the official k8s documentation](https://kubernetes.io/docs/concepts/containers/images/#updating-images) the default pull policy is `IfNotPresent` meaning that the node won't pull the image if it is already present in the local cache. The following procedure pulls the images in a linux host with internet connectivity and then make the images available in the hosts.

This requires cluster-admin permissions.

NOTE: In order to copy a file to a node, `oc debug node/<node> -- bash -c 'cat > host/tmp/myfile-remote' <(cat myfile)` worked in previous oc versions. Now it doesn't until [this PR](https://github.com/openshift/oc/pull/470) is merged, so as a temporary workaround in order to copy the required files to the nodes, scp as core user to the nodes is required.

### Download the images in a linux host with internet connectivity

```bash
export IMAGES=("docker.io/library/nginx:1.14-alpine" "us.gcr.io/k8s-artifacts-prod/e2e-test-images/agnhost:2.12")
# Create an empty tar file to store all the images
tar cvf image-files.tar --files-from /dev/null
for image in "${IMAGES[@]}"; do
  # Pull the image locally
  podman pull ${image}
  # Save the image into a tar file
  podman save > ${image##*/}.tar ${image}
  # Append the image to the tar file
  tar rvf image-files.tar ${image##*/}.tar
  # Remove the temporary tar file
  rm -f ${image##*/}.tar
done
# GZ the tar file with all the images
gzip image-files.tar
```

### Copy the images to the hosts

From a host with access to the nodes, the `image-files.tar.gz` file and as a cluster-admin user:

```bash
export IMAGES=("docker.io/library/nginx:1.14-alpine" "us.gcr.io/k8s-artifacts-prod/e2e-test-images/agnhost:2.12")
for node in $(oc get nodes -o name); do
  # Copy the tar.gz file to every host
  # This used to work back in the day but now it doesn't until https://github.com/openshift/oc/pull/470 is merged
  # oc debug ${node} -- chroot /host bash -c 'cat > /tmp/image-files.tar.gz' <(cat image-files.tar.gz)
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ./image-files.tar.gz \
    core@$(oc get ${node} -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}'):/tmp/
  # Extract the tar.gz
  oc debug ${node} -- chroot /host bash -c 'tar -C /tmp -xzf /tmp/image-files.tar.gz && rm -f /tmp/image-files.tar.gz'
  for image in "${IMAGES[@]}"; do
    # Import every image locally using podman import
    oc debug ${node} -- chroot /host bash -c "cat /tmp/${image##*/}.tar | podman import - ${image} && rm -f /tmp/${image##*/}.tar"
  done
done
```

## Clean up the images

Optionally, after the tests have been executed, the images can be removed from the local cache as:

```bash
export IMAGES=("docker.io/library/nginx:1.14-alpine" "us.gcr.io/k8s-artifacts-prod/e2e-test-images/agnhost:2.12")
for node in $(oc get nodes -o name); do
  for image in "${IMAGES[@]}"; do
    oc debug ${node} -- chroot /host bash -c "podman rmi ${image}"
  done
done
```
