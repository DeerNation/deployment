#!/usr/bin/env bash
# if [[ $(oc whoami) != "developer" ]]; then
#     oc login -u developer
# fi
if [[ $(oc project -q) != "deernation" ]]; then
    oc project deernation || return 1
fi
#oc config use-context `oc config get-contexts --no-headers=true --output=name | grep deernation | grep admin` || return 1

for file in kubernetes/*.yaml; do
    [ -e "$file" ] || continue
    istioctl kube-inject -f "$file" | oc apply -n deernation -f -
done

printf "Waiting for DeerNation system to get ready."
while [[ $(oc get pods --no-headers | grep -v Running | grep -v Completed | wc -l) != "0" ]]; do
    printf "."
    sleep 10
done
echo "DeerNation is ready"