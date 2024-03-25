# Gloo Mesh mgmt server installation
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

# Pre-requisite secrets for Gloo agent registration

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

# Gloo agent installation

```bash
until kubectl get service/gloo-mesh-mgmt-server --output=jsonpath='{.status.loadBalancer}' --context "${MGMT_CONTEXT}" -n gloo-mesh | grep "ingress"; do : ; done
until kubectl get service/gloo-telemetry-gateway --output=jsonpath='{.status.loadBalancer}' --context "${MGMT_CONTEXT}" -n gloo-mesh | grep "ingress"; do : ; done
echo
GLOO_PLATFORM_MGMT_SERVER_ADDRESS=$(kubectl get svc gloo-mesh-mgmt-server --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.status.loadBalancer.ingress[0].*}'):$(kubectl get svc gloo-mesh-mgmt-server --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.spec.ports[?(@.name=="grpc")].port}')
GLOO_PLATFORM_TELEMETRY_GATEWAY_ADDRESS=$(kubectl get svc gloo-telemetry-gateway --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.status.loadBalancer.ingress[0].*}'):$(kubectl get svc gloo-telemetry-gateway --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.spec.ports[?(@.name=="otlp")].port}')
echo "Mgmt Server Address: ${GLOO_PLATFORM_MGMT_SERVER_ADDRESS}"
echo "Telemetry Gateway Address: ${GLOO_PLATFORM_TELEMETRY_GATEWAY_ADDRESS}"
```

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