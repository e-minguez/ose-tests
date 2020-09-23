# How to make the images available offline

## Why cannot just mirror those images?

The OpenShift cluster can be configured to redirect requests to pull images from a repository on a source image registry and have it resolved by a repository on a mirrored image registry. It uses an `ImageContentSourcePolicy` object that specifies the source reposit
ory and the mirrored one. It also configures "mirror-by-digest-only = true" which makes pulling an image as "image:tag" skip the mirroring, which makes it not valid to be able to run the ose-tests as they images used are ['hardcoded'](https://github.com/openshift/origin/blob/master/vendor/k8s.io/kubernetes/test/utils/image/manifest.go) to use image:tag.

You can read more about this in [the official OCP documentation](https://docs.openshift.com/container-platform/4.4/openshift_images/image-configuration.html#images-configuration-registry-mirror_image-configuration) and the details in the [containers-registries.conf](https://github.com/containers/image/blob/master/docs/containers-registries.conf.5.md#remapping-and-mirroring-registries) man.

## oc debug in disconnected environments

Currently, [there is an issue](https://bugzilla.redhat.com/show_bug.cgi?id=1728135) when using `oc debug node` in disconnected environments as it uses the `registry.redhat.io/rhel7/support-tools:latest` image by default (Which requires internet connectivity). The image is pulled using image:tag, so an `ImageContentSourcePolicy` won't work.

However, `oc debug` has a `--image` parameter where a different image can be specified.

To leverage that functionality, the `registry.redhat.io/rhel7/support-tools:latest` can be mirrored into the registry used to deploy OCP as:

```bash
export MYREGISTRY='registry.example.com'
IMAGEID=$(podman pull registry.redhat.io/rhel7/support-tools:latest 2>/dev/null)
podman login ${MYREGISTRY}
podman push ${IMAGEID} ${MYREGISTRY}/rhel7/support-tools:latest
```

Then, every `oc debug` invocation should contain the `--image=${MYREGISTRY}/rhel7/support-tools:latest` parameter, like:

```bash
export TOOLSIMAGE="registry.example.com/rhel7/support-tools:latest"
oc debug --image="${TOOLSIMAGE}"
```

## List of images used by the tests

The following sections shows the images used by the tests so there is no need to perform these steps, it is just a reference.

The list of registries and images that the tests use can be observed in the [test/utils/image/manifest.go](https://github.com/openshift/origin/blob/master/vendor/k8s.io/kubernetes/test/utils/image/manifest.go).

The following snippet will output the list of images already pulled in the cluster at the time of writting the document. Please check [the current list of images just in case](https://github.com/openshift/origin/blob/master/vendor/k8s.io/kubernetes/test/utils/image/manifest.go):

```bash
export TOOLSIMAGE="registry.example.com/rhel7/support-tools:latest"
for node in $(oc get nodes -o name);do oc debug --image="${TOOLSIMAGE}" ${node} -- chroot /host sh -c 'crictl images -o json' 2>/dev/null | jq -r .images[].repoTags[]; done | sort -u
```

To get the list of images used by the tests, in a connected environment run the previous command before and after running the tests, so you can see which images where pulled by the tests execution.

### [openshift-conformance-minimal](tests-lists/openshift-conformance-minimal.txt) images

```bash
export IMAGES=(
      "docker.io/library/busybox:1.29"
      "docker.io/library/httpd:2.4.38-alpine"
      "docker.io/library/nginx:1.14-alpine"
      "gcr.io/kubernetes-e2e-test-images/mounttest:1.0"
      "k8s.gcr.io/pause:3.2"
      "us.gcr.io/k8s-artifacts-prod/e2e-test-images/agnhost:2.20"
      )
```

### [openshift-conformance](tests-lists/openshift-conformance.txt) images

```bash
export IMAGES=(
      "docker.io/library/busybox:1.29"
      "docker.io/library/httpd:2.4.38-alpine"
      "docker.io/library/nginx:1.14-alpine"
      "gcr.io/kubernetes-e2e-test-images/mounttest:1.0"
      "k8s.gcr.io/pause:3.2"
      "us.gcr.io/k8s-artifacts-prod/e2e-test-images/agnhost:2.20"
      )
```

### [kubernetes-conformance](tests-lists/kubernetes-conformance.txt) images

```bash
export IMAGES=(
      "docker.io/library/busybox:1.29"
      "docker.io/library/httpd:2.4.38-alpine"
      "docker.io/library/nginx:1.14-alpine"
      "gcr.io/kubernetes-e2e-test-images/mounttest:1.0"
      "k8s.gcr.io/pause:3.2"
      "us.gcr.io/k8s-artifacts-prod/e2e-test-images/agnhost:2.20"
      )
```

### [openshift-network-stress](tests-lists/openshift-network-stress.txt) images

```bash
export IMAGES=(
      "k8s.gcr.io/pause:3.2"
      "us.gcr.io/k8s-artifacts-prod/e2e-test-images/agnhost:2.20"
      )
```

### [openshift-conformance-excluded-non-disruptive](tests-lists/openshift-conformance-excluded-non-disruptive.txt) images

```bash
export IMAGES=(
      "docker.io/library/busybox:1.29"
      "docker.io/library/nginx:1.14-alpine"
      "gcr.io/kubernetes-e2e-test-images/resource-consumer:1.5"
      "k8s.gcr.io/pause:3.2"
      "us.gcr.io/k8s-artifacts-prod/e2e-test-images/agnhost:2.20"
      )
```

### [openshift-conformance-excluded-disruptive](tests-lists/openshift-conformance-excluded-disruptive.txt) images

```bash
export IMAGES=(
      "docker.io/library/busybox:1.29"
      )
```

### [all-disruptive](tests-lists/all-disruptive.txt) images

```bash
export IMAGES=(
      "docker.io/library/busybox:1.29"
      )
```

### [all-non-disruptive](tests-lists/all-non-disruptive.txt) images

```bash
export IMAGES=(
      "docker.io/library/busybox:1.29"
      "docker.io/library/httpd:2.4.38-alpine"
      "docker.io/library/nginx:1.14-alpine"
      "gcr.io/authenticated-image-pulling/alpine:3.7"
      "gcr.io/kubernetes-e2e-test-images/mounttest:1.0"
      "gcr.io/kubernetes-e2e-test-images/resource-consumer:1.5"
      "k8s.gcr.io/pause:3.2"
      "us.gcr.io/k8s-artifacts-prod/e2e-test-images/agnhost:2.20"
      )
```

## Make the images offline

According to [the official k8s documentation](https://kubernetes.io/docs/concepts/containers/images/#updating-images) the default pull policy is `IfNotPresent` meaning that the node won't pull the image if it is already present in the local cache. The following procedure pulls the images in a linux host with internet connectivity and then make the images available in the hosts.

This requires cluster-admin permissions.

NOTE: In order to copy a file to a node, `oc debug node/<node> -- bash -c 'cat > host/tmp/myfile-remote' <(cat myfile)` worked in previous oc versions. Now it doesn't until [this PR](https://github.com/openshift/oc/pull/470) is merged, so as a temporary workaround in order to copy the required files to the nodes, scp as core user to the nodes is required.

### Download the images in a linux host with internet connectivity

Depending on the tests you are about to execute, the `export IMAGES` command can be different (see [the list of images used by the tests](#List-of-images-used-by-the-tests)):

```bash
export IMAGES=(
      "docker.io/library/busybox:1.29"
      "docker.io/library/httpd:2.4.38-alpine"
      "docker.io/library/nginx:1.14-alpine"
      "gcr.io/kubernetes-e2e-test-images/mounttest:1.0"
      "gcr.io/authenticated-image-pulling/alpine:3.7"
      "gcr.io/kubernetes-e2e-test-images/resource-consumer:1.5"
      "k8s.gcr.io/pause:3.2"
      "us.gcr.io/k8s-artifacts-prod/e2e-test-images/agnhost:2.12"
      )

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
export TOOLSIMAGE="registry.example.com/rhel7/support-tools:latest"

export IMAGES=(
      "docker.io/library/busybox:1.29"
      "docker.io/library/httpd:2.4.38-alpine"
      "docker.io/library/nginx:1.14-alpine"
      "gcr.io/kubernetes-e2e-test-images/mounttest:1.0"
      "gcr.io/authenticated-image-pulling/alpine:3.7"
      "gcr.io/kubernetes-e2e-test-images/resource-consumer:1.5"
      "k8s.gcr.io/pause:3.2"
      "us.gcr.io/k8s-artifacts-prod/e2e-test-images/agnhost:2.12"
      )

for node in $(oc get nodes -o name); do

  # Copy the tar.gz file to every host
  # This used to work back in the day but now it doesn't until https://github.com/openshift/oc/pull/470 is merged
  # oc debug ${node} -- chroot /host bash -c 'cat > /tmp/image-files.tar.gz' <(cat image-files.tar.gz)
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ./image-files.tar.gz \
    core@$(oc get ${node} -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}'):/tmp/

  # Extract the tar.gz
  oc debug --image="${TOOLSIMAGE}" ${node} -- chroot /host bash -c 'tar -C /tmp -xzf /tmp/image-files.tar.gz && rm -f /tmp/image-files.tar.gz'

  for image in "${IMAGES[@]}"; do

    # Import every image locally using podman load
    oc debug --image="${TOOLSIMAGE}" ${node} -- chroot /host bash -c "cat /tmp/${image##*/}.tar | podman load && rm -f /tmp/${image##*/}.tar"

  done

done
```

## Run the tests

Now you can go back and [run the tests](README.md#run-the-tests)

## Clean up the images

As a good practice, after the tests have been executed, the images can be removed from the local cache, otherwise, someone can use the images already available to run a pod.

```bash
export TOOLSIMAGE="registry.example.com/rhel7/support-tools:latest"

export IMAGES=(
      "docker.io/library/busybox:1.29"
      "docker.io/library/httpd:2.4.38-alpine"
      "docker.io/library/nginx:1.14-alpine"
      "gcr.io/kubernetes-e2e-test-images/mounttest:1.0"
      "gcr.io/authenticated-image-pulling/alpine:3.7"
      "gcr.io/kubernetes-e2e-test-images/resource-consumer:1.5"
      "k8s.gcr.io/pause:3.2"
      "us.gcr.io/k8s-artifacts-prod/e2e-test-images/agnhost:2.12"
      )

for node in $(oc get nodes -o name); do

  for image in "${IMAGES[@]}"; do
    oc debug --image="${TOOLSIMAGE}" ${node} -- chroot /host bash -c "podman rmi ${image}"
  done

done
```

