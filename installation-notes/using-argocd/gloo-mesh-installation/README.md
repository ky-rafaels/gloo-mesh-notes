# Gloo Mesh mgmt server installation

Referred manifests live in [installation-notes/using-argocd/gloo-mesh-installation/mgmt-cluster](https://github.com/find-arka/gloo-mesh-notes/tree/main/installation-notes/using-argocd/gloo-mesh-installation/mgmt-cluster) subfolder

```bash
kubectl apply --context "${MGMT_CONTEXT}" -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gloo-platform-mgmt-server-app-of-apps
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/find-arka/gloo-mesh-notes
    path: installation-notes/using-argocd/gloo-mesh-installation/mgmt-cluster
    targetRevision: HEAD
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m0s
EOF
```

# Pre-requisite secrets for Gloo agent registration - self signed CA setup

Referred manifests live in [installation-notes/using-argocd/gloo-mesh-installation/common-pre-requisite-gloo-agent-install](https://github.com/find-arka/gloo-mesh-notes/tree/main/installation-notes/using-argocd/gloo-mesh-installation/common-pre-requisite-gloo-agent-install) subfolder.

> The relay-identity-token-secret value in the yaml must be replaced by fetching the value from the mgmt cluster.
```bash
TOKEN=$(kubectl get secret relay-identity-token-secret --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.data.token}')
echo $TOKEN
```

> The ca.crt value in relay-root-tls-secret must be replaced by actual ca.crt value
```bash
CA_CRT=$(kubectl get secret relay-root-tls-secret --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.data.ca\.crt}')
echo $CA_CRT
```
These manifests could be kept in a private github repository as a one time setup and the same can be referred from the below ArgoCD application by editing the repoURL and configuring the Argo Application to interact with the private repository.

```bash
kubectl apply --context "${REMOTE_CONTEXT1}" -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: "gloo-agent-pre-requisite-${REMOTE_CONTEXT1}"
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/find-arka/gloo-mesh-notes
    path: installation-notes/using-argocd/gloo-mesh-installation/common-pre-requisite-gloo-agent-install
    targetRevision: HEAD
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m0s
EOF
```

# Gloo agent installation in workload clusters
(Same steps need to be repeated for each workload clusters)

### Install CRDs
```bash
kubectl apply --context "${REMOTE_CONTEXT1}" -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gloo-platform-crds
  namespace: argocd
spec:
  destination:
    namespace: gloo-mesh
    server: https://kubernetes.default.svc
  project: default
  source:
    chart: gloo-platform-crds
    repoURL: https://storage.googleapis.com/gloo-platform/helm-charts
    targetRevision: 2.5.4
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true 
    retry:
      limit: 2
      backoff:
        duration: 5s
        maxDuration: 3m0s
        factor: 2
EOF
```

### Checking if the Load Balancer has been provisioned or not
```bash
until kubectl get service/gloo-mesh-mgmt-server --output=jsonpath='{.status.loadBalancer}' --context "${MGMT_CONTEXT}" -n gloo-mesh | grep "ingress"; do : ; done
until kubectl get service/gloo-telemetry-gateway --output=jsonpath='{.status.loadBalancer}' --context "${MGMT_CONTEXT}" -n gloo-mesh | grep "ingress"; do : ; done
echo
GLOO_PLATFORM_MGMT_SERVER_ADDRESS=$(kubectl get svc gloo-mesh-mgmt-server --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.status.loadBalancer.ingress[0].*}'):$(kubectl get svc gloo-mesh-mgmt-server --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.spec.ports[?(@.name=="grpc")].port}')
GLOO_PLATFORM_TELEMETRY_GATEWAY_ADDRESS=$(kubectl get svc gloo-telemetry-gateway --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.status.loadBalancer.ingress[0].*}'):$(kubectl get svc gloo-telemetry-gateway --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.spec.ports[?(@.name=="otlp")].port}')
echo "Mgmt Server Address: ${GLOO_PLATFORM_MGMT_SERVER_ADDRESS}"
echo "Telemetry Gateway Address: ${GLOO_PLATFORM_TELEMETRY_GATEWAY_ADDRESS}"
```

### Creating the Gloo Agent Argo application
```bash
kubectl apply --context "${REMOTE_CONTEXT1}" -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  name: "gloo-agent-${REMOTE_CONTEXT1}"
  namespace: argocd
spec:
  destination:
    namespace: gloo-mesh
    server: https://kubernetes.default.svc
  project: default
  source:
    chart: gloo-platform
    helm:
      skipCrds: true
      values: |
        common:
          cluster: "${REMOTE_CONTEXT1}"
        glooAgent:
          enabled: true
          relay:
            serverAddress: "${GLOO_PLATFORM_MGMT_SERVER_ADDRESS}"
        telemetryCollector:
          enabled: true
          config:
            exporters:
              otlp:
                endpoint: "${GLOO_PLATFORM_TELEMETRY_GATEWAY_ADDRESS}"
    repoURL: https://storage.googleapis.com/gloo-platform/helm-charts
    targetRevision: 2.5.4
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

# Istio installation
(Same step needs to be repeated for each workload clusters)

Referred manifests live in [installation-notes/using-argocd/gloo-mesh-installation/lifecycle-managers-workload-cluster1](https://github.com/find-arka/gloo-mesh-notes/tree/main/installation-notes/using-argocd/gloo-mesh-installation/lifecycle-managers-workload-cluster1) subfolder

> The Hub, tag and the cluster name references in the yaml would need to be replaced.

```bash
kubectl apply --context "${MGMT_CONTEXT}" -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: "istio-${REMOTE_CONTEXT1}"
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/find-arka/gloo-mesh-notes
    path: installation-notes/using-argocd/gloo-mesh-installation/lifecycle-managers-workload-cluster1
    targetRevision: HEAD
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m0s
EOF
```
