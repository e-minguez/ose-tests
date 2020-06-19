#!/bin/bash
oc get --raw "${1}" | jq '.resources | map(select(.name | test("^\\w*$")))[].name' | sed -e 's/^"//' -e 's/"$//'