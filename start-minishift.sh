#!/usr/bin/env bash

if [ -d ~/.minishift ]; then
    read -p "Installation is active. Remove it? [y/n]" -n 1 -s res
    echo
    if [ "$res" == "y" ]; then
        echo "Removing current installation..."
        killall -9 oc
        minishift stop || true
        minishift delete || true
        rm -rf ~/.minishift
        rm -rf ~/.kube
    fi;
fi

SLEEP=1
STATUS=`minishift status | grep Minishift | awk '{print $2}'`
echo "Minishift status: $STATUS"
if [[ "$STATUS" == "Stopped" ]] || [[ "$STATUS" == "" ]]; then
    minishift addon enable admin-user
    minishift addon enable anyuid
    minishift config set image-caching true

    echo "starting minishift"
    minishift start --memory 8GB --openshift-version v3.10.0 --vm-driver virtualbox --cpus 3
    SLEEP=15
fi;

echo "applying environments..."
eval $(minishift oc-env)
eval $(minishift docker-env)

echo "applying bash-completion..."
source ./.minishift-completion
source ./.oc-completion

oc login -u admin -p admin
# install istio
pushd .
cd istio/install/kubernetes/ansible/
ansible-playbook main.yml || return 1
popd
oc adm policy add-scc-to-user anyuid -z default -n deernation
oc adm policy add-scc-to-user privileged -z default -n deernation
oc adm policy add-scc-to-user privileged developer
oc adm policy add-role-to-user admin developer -n istio-system
oc adm policy add-cluster-role-to-user cluster-admin -z default

printf "Waiting for istio system to get ready."
while [[ $(oc get pods -n istio-system --no-headers | grep -v Running | grep -v Completed | wc -l) != "0" ]]; do
    printf "."
    sleep 10
done
echo "istio is ready"

# expose some of istios services
oc expose svc grafana -n istio-system
oc expose svc servicegraph -n istio-system
oc expose svc zipkin -n istio-system
oc expose svc prometheus -n istio-system
SERVICEGRAPH=$(oc get route servicegraph -n istio-system -o jsonpath='{.spec.host}{"\n"}')/dotviz
GRAFANA=$(oc get route grafana -n istio-system -o jsonpath='{.spec.host}{"\n"}')
ZIPKIN=$(oc get route zipkin -n istio-system -o jsonpath='{.spec.host}{"\n"}')

# oc login -u developer
if [[ $(oc get projects -o=name | grep deernation) == "" ]]; then
    oc new-project deernation --display-name=DeerNation
fi;

source ./apply.sh

oc port-forward -n istio-system `oc get pods -n istio-system --selector=app=istio-ingressgateway -o name | cut -f2 -d /` 8080:80 &

# enable port-forwarding for dgraph (server + ratel)
#echo "enabling port-forwarding..."
#
## wait for pod to be ready
#while [[ $(oc get pod -l app=dgraph-server --no-headers | awk '{print $3}') != "Running" ]]; do
#    echo "waiting for dgraph-server pod to be running"
#    sleep 1
#done
#oc port-forward dgraph-server-0 9080 &
#oc port-forward dgraph-server-0 8080 &
#
#while [[ $(oc get pod -l app=dgraph-ratel --no-headers | awk '{print $3}') != "Running" ]]; do
#    echo "waiting for dgraph-ratel pod to be running"
#    sleep 1
#done
#oc port-forward `oc get pods --selector=app=dgraph-ratel -o name | cut -f2 -d /` 8000 &
