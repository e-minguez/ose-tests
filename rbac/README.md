# audit2role

## Overview

This is a rough draft of a tool that generates the YAML required for a
particular action to be performed. It's intended to be in the same spirit as
audit2allow for SELinux. It queries both the OpenShift API audit log and the
regular Kubernetes API audit log for the verbs (along with their API group) that
have been called by the given user (defaults to "tests").

The MO for using the current version of the script is to let the tests run as a
new user that has been given cluster-admin privileges and then using this script
 to capture the verbs/resources it acted upon to perform the tests, then to
 remove cluster-admin, apply the resulting role and trying the test again.

You invoke it by just running it, you can provide a `-n <NAME>` option to
generate a role with the given name. By default it prints the role to stdout
(which can be redirected to a file) or you can provide a `-o <FILE>` to output
to a file instead.

NOTE: This creates a directory underneath `/var/tmp` that can be several MB's
large. Hasn't been an issue for me but could conceivably be.

## Known Issues

* There are certain things that aren't currently handled well by the script. For
 instance, if the tests ran try to create a role using verbs/resources it never
 uses elsewhere then this script fails to capture those currently. I need to
 find out how to capture that. Presently, the osetests error produces near
 JSON-compatible listing of the privileges being requested, so I've just been
 using `vim` to run some `%s//g` voodoo to convert the nearly-JSON into actual
 JSON then I have a second script that produces the YAML stanzas required from
 that.

* The script makes a cursory attempt at de-duping rules but it could be a lot
better.

* It directly calls out to binary executables when much of the logic can be done
 with Python native code. I just already had the commands written to do these
 things so it was easier to just call the command.

* It's a flat file rather than separated out into modules for easier review.

## Usage

The whole process would be:

* Create a fresh cluster
* Create a tests user with cluster-admin permissions
* Run the test-suite as documented in this repository
* Run the audit2role script with -n and -o set

This will generate the clusterrole but currently it misses some stuff.
The temporary workaround requires to perform some work:

* Apply the clusterrole to the user and remove the cluster-admin permissions
* Run the tests again

Some tests will fail because of permissions.

* Create a file with the content of each of the failed tests output from the
html junit output (foo.json), as:

```
{APIGroups:[""], Resources:["processedtemplates"], Verbs:["create" "delete" "deletecollection" "get" "list" "patch" "update" "watch" "get" "list" "watch"]}
    {APIGroups:[""], Resources:["projects"], Verbs:["get"]}
    {APIGroups:[""], Resources:["replicationcontrollers"], Verbs:["deletecollection" "patch" "update" "watch"]}
    {APIGroups:[""], Resources:["replicationcontrollers/scale"], Verbs:["create" "delete" "deletecollection" "patch" "update" "get" "list" "watch"]}
    {APIGroups:[""], Resources:["replicationcontrollers/status"], Verbs:["get" "list" "watch"]}
    {APIGroups:[""], Resources:["resourcequotas"], Verbs:["get" "watch"]}
...
```

* Convert that file to json:

```
sed -i -e 's/APIGroups:/"APIGroups":/g' \
       -e 's/Resources:/"Resources":/g' \
       -e 's/Verbs:/"Verbs":/g' \
       -e 's/" "/","/g' foo.json
```

* Create the following helper script:

```python
#!/usr/bin/python3

import json,sys

with open(sys.argv[1]) as fh:
    for line in fh.readlines():
        jsonObject=json.loads(line)
        print("- apiGroups:")
        if not jsonObject['APIGroups'][0]:
            print("  - ''")
        else:
            print("  - "+ jsonObject['APIGroups'][0])
        print("  resources:")
        print("  - "+ jsonObject['Resources'][0])
        print("  verbs:")
        for verb in jsonObject['Verbs']:
            print("  - "+ verb)
```

* Run it as `python foo.py foo.json`
* Append the output to the clusterrole previously created
* Verify it works
