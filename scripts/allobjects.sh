#!/bin/bash
oc get --raw / | jq '.paths | map(select(. | test("/v1")))[]' | \
  sed -e 's/^"//' -e 's/"$//' | parallel -a - --jobs 20 --tag 'apigetter.sh {= $args[0] =} 2> /dev/null' | \
  sed 's/\s/\//g' | parallel -a - --jobs 20 oc get --raw | \
  jq -r '.items[] | .metadata.selfLink+":"+.metadata.resourceVersion' | sort