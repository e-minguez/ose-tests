## Preparation

### Packages and container images

This can be done in a workstation, jumphost, whatever.

```bash
sudo yum clean all
sudo yum update -y
sudo yum install slirp4netns podman -y
echo "user.max_user_namespaces=28633" | sudo tee -a /etc/sysctl.d/userns.conf
sudo sysctl -p /etc/sysctl.d/userns.conf
sudo usermod --add-subuids 200000-300000 --add-subgids 200000-300000 $(whoami)
podman system migrate
podman login -u user -p password quay.io
podman pull quay.io/openshift/origin-tests:4.5
```

### Files

```bash
MYDIR=${HOME}/cluster-loader
MYFILE="cluster-loader-test.txt"
mkdir -p ${MYDIR}
cp ${HOME}/clusterconfigs/auth/kubeconfig ${MYDIR}/kubeconfig
echo '"[sig-scalability][Feature:Performance] Load cluster should populate the cluster [Slow][Serial] [Suite:openshift]"' > ${MYDIR}/${MYFILE}
```

### Fix https://github.com/openshift/origin/pull/25432 & https://github.com/openshift/origin/pull/25434

```bash
mkdir -p ${MYDIR}/templates/

for file in cakephp-mysql dancer-mysql django-postgresql nodejs-mongodb rails-postgresql; do
  curl -L https://github.com/openshift/origin/raw/master/test/extended/testdata/cluster/quickstarts/${file}.json -o ${MYDIR}/templates/${file}.json
done

# https://github.com/openshift/origin/pull/25432
sed -i -e 's/"value": "8"/"value": "latest"/g' ${MYDIR}/templates/nodejs-mongodb.json
# https://github.com/openshift/origin/pull/25434
sed -i -e 's/"value": "7.1"/"value": "latest"/g' ${MYDIR}/templates/cakephp-mysql.json


cat << EOF > ${MYDIR}/config.yaml
provider: local
ClusterLoader:
  cleanup: true
  ifexists: delete
  projects:
    - num: 10
      basename: clusterloader-cakephp-mysql
      ifexists: delete
      tuning: default
      templates:
        - num: 1
          file: /tests/templates/cakephp-mysql.json
  
    - num: 10
      basename: clusterloader-dancer-mysql
      ifexists: delete
      tuning: default
      templates:
        - num: 1
          file: /tests/templates/dancer-mysql.json
  
    - num: 10
      basename: clusterloader-django-postgresql
      ifexists: delete
      tuning: default
      templates:
        - num: 1
          file: /tests/templates/django-postgresql.json
  
    - num: 10
      basename: clusterloader-nodejs-mongodb
      ifexists: delete
      tuning: default
      templates:
        - num: 1
          file: /tests/templates/nodejs-mongodb.json
  
    - num: 10
      basename: clusterloader-rails-postgresql
      ifexists: delete
      tuning: default
      templates:
        - num: 1
          file: /tests/templates/rails-postgresql.json
  
  tuningsets:
    - name: default
      pods:
        stepping:
          stepsize: 5
          pause: 0 min
        rate_limit:
          delay: 0 ms
EOF
```

### Run the cluster loader

```bash
podman run --rm --name="cluster-loader" -v ${MYDIR}:/tests:Z -e VIPERCONFIG=/tests/config.yaml -e KUBECONFIG="/tests/kubeconfig" quay.io/openshift/origin-tests:4.5 /bin/bash -c "openshift-tests run --junit-dir=/tests/ -o /tests/cluster-loader.log -f /tests/${MYFILE}"
```

## References

* https://docs.openshift.com/container-platform/4.5/scalability_and_performance/using-cluster-loader.html
