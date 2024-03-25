#!/bin/sh
set -e 

for MY_CLUSTER_CONTEXT in $MGMT_CONTEXT $REMOTE_CONTEXT1 $REMOTE_CONTEXT2
do
    kubectl create namespace argocd --context "${MY_CLUSTER_CONTEXT}"
    until kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.5/manifests/install.yaml --context "${MY_CLUSTER_CONTEXT}" > /dev/null 2>&1; do sleep 2; done
done

for MY_CLUSTER_CONTEXT in $MGMT_CONTEXT $REMOTE_CONTEXT1 $REMOTE_CONTEXT2
do
    kubectl --context "${MY_CLUSTER_CONTEXT}" -n argocd rollout status deploy/argocd-applicationset-controller
    kubectl --context "${MY_CLUSTER_CONTEXT}" -n argocd rollout status deploy/argocd-dex-server
    kubectl --context "${MY_CLUSTER_CONTEXT}" -n argocd rollout status deploy/argocd-notifications-controller
    kubectl --context "${MY_CLUSTER_CONTEXT}" -n argocd rollout status deploy/argocd-redis
    kubectl --context "${MY_CLUSTER_CONTEXT}" -n argocd rollout status deploy/argocd-repo-server
    kubectl --context "${MY_CLUSTER_CONTEXT}" -n argocd rollout status deploy/argocd-server
done

echo "sleeping for 10 sec before updating admin password"
sleep 10

for MY_CLUSTER_CONTEXT in $MGMT_CONTEXT $REMOTE_CONTEXT1 $REMOTE_CONTEXT2
do
    # bcrypt(password)=$2a$10$79yaoOg9dL5MO8pn8hGqtO4xQDejSEVNWAGQR268JHLdrCw6UCYmy
    # password: solo.io
    kubectl --context "${MY_CLUSTER_CONTEXT}" -n argocd patch secret argocd-secret \
    -p '{"stringData": {
        "admin.password": "$2a$10$79yaoOg9dL5MO8pn8hGqtO4xQDejSEVNWAGQR268JHLdrCw6UCYmy",
        "admin.passwordMtime": "'$(date +%FT%T%Z)'"
    }}'
done
