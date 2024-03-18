# Step 2 - Install Gloo Mesh Agent components in workload cluster

## Set required environment variables

```bash
export REMOTE_CONTEXT=
export MGMT_CONTEXT=
export GLOO_MESH_VERSION=
```

## Create gloo-mesh NameSpace

```bash
kubectl --context "${REMOTE_CONTEXT}" apply -f- <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: gloo-mesh
EOF
```

## Copy the public TLS root certificate from mgmt cluster to workload cluster

```bash
CA_CRT=$(kubectl get secret relay-root-tls-secret --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.data.ca\.crt}')
kubectl -n gloo-mesh --context "${REMOTE_CONTEXT}" apply -f - << EOF
apiVersion: v1
metadata:
  name: relay-root-tls-secret
data:
  ca.crt: "${CA_CRT}"
kind: Secret
type: Opaque
EOF
```

## Copy the relay-identity-token used for the Gloo agents to authenticate with the management plane.

```bash
TOKEN=$(kubectl get secret relay-identity-token-secret --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.data.token}')
kubectl -n gloo-mesh --context "${REMOTE_CONTEXT}" apply -f - << EOF
apiVersion: v1
metadata:
  name: relay-identity-token-secret
data:
  token: "${TOKEN}"
kind: Secret
type: Opaque
EOF
```

## Install Gloo Mesh related CRDs in the gloo-mesh NameSpace

```bash
helm upgrade --install gloo-platform-crds gloo-platform/gloo-platform-crds \
  --version="${GLOO_MESH_VERSION}" \
  --kube-context "${REMOTE_CONTEXT}" \
  --namespace=gloo-mesh \
  --wait
```

## Create a KubernetesCluster object in the management cluster before registering the agent

```bash
kubectl --context "${MGMT_CONTEXT}" apply -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: KubernetesCluster
metadata:
  name: "${REMOTE_CONTEXT}"
  namespace: gloo-mesh
spec:
  clusterDomain: cluster.local
EOF
```

## Wait for the Load Balancers to be provisioned in the management cluster before installing the agent

```bash
until kubectl get service/gloo-mesh-mgmt-server --output=jsonpath='{.status.loadBalancer}' --context "${MGMT_CONTEXT}" -n gloo-mesh | grep "ingress"; do : ; done
until kubectl get service/gloo-telemetry-gateway --output=jsonpath='{.status.loadBalancer}' --context "${MGMT_CONTEXT}" -n gloo-mesh | grep "ingress"; do : ; done
echo
GLOO_PLATFORM_MGMT_SERVER_ADDRESS=$(kubectl get svc gloo-mesh-mgmt-server --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.status.loadBalancer.ingress[0].*}'):$(kubectl get svc gloo-mesh-mgmt-server --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.spec.ports[?(@.name=="grpc")].port}')
GLOO_PLATFORM_TELEMETRY_GATEWAY_ADDRESS=$(kubectl get svc gloo-telemetry-gateway --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.status.loadBalancer.ingress[0].*}'):$(kubectl get svc gloo-telemetry-gateway --context "${MGMT_CONTEXT}" -n gloo-mesh -o jsonpath='{.spec.ports[?(@.name=="otlp")].port}')
echo "Mgmt Server Address: ${GLOO_PLATFORM_MGMT_SERVER_ADDRESS}"
echo "Telemetry Gateway Address: ${GLOO_PLATFORM_TELEMETRY_GATEWAY_ADDRESS}"
```

## Create helm values overrides file to install Gloo Mesh agent and collector

```bash
cat << EOF > gloo-platform-agent-helm-values.yaml
common:
  cluster: "${REMOTE_CONTEXT}"
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
EOF
```

## Install Gloo Mesh Agent

```bash
helm upgrade --install gloo-platform gloo-platform/gloo-platform \
  --namespace gloo-mesh \
  --kube-context "${REMOTE_CONTEXT}" \
  --version="${GLOO_MESH_VERSION}" \
  -f gloo-platform-agent-helm-values.yaml \
  --wait
```

## Validation using meshctl

```
meshctl check --kubecontext "${MGMT_CONTEXT}"
```

### Navigation links for other steps

* [Step 1 - Install Gloo Mesh Management Plane components in management cluster](./step-1-install-gm-mgmt-server-in-mgmt-cluster.md)
* [Step 3 - Install Gloo Mesh Managed Istiod using IstioLifecycleManager](./step-3-install-istio-with-ILM.md)
* [Step 4 - Install Gloo Mesh Managed Istio Ingress gateway using GatewayLifecycleManager](./step-4-install-gateway-with-GLM.md)
* [Step 5 - Install sample applications](./step-5-sample-app.md)
