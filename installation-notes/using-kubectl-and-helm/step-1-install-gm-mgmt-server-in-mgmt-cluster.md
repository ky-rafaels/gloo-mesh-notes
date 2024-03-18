# Step 1 - Install Gloo Mesh Management Plane components in management cluster

## Set required environment variables

```bash
export MGMT_CONTEXT=
export GLOO_MESH_VERSION=
export GLOO_MESH_LICENSE_KEY=
export GLOO_GATEWAY_LICENSE_KEY=
export GLOO_NETWORK_LICENSE_KEY=
```

## Create gloo-mesh NameSpace

```bash
kubectl --context "${MGMT_CONTEXT}" apply -f- <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: gloo-mesh
EOF
```

## Install Gloo Mesh related CRDs in the gloo-mesh NameSpace

```bash
helm repo add gloo-platform https://storage.googleapis.com/gloo-platform/helm-charts
helm repo update
```

```bash
helm upgrade --install gloo-platform-crds gloo-platform/gloo-platform-crds \
  --version="${GLOO_MESH_VERSION}" \
  --kube-context "${MGMT_CONTEXT}" \
  --namespace=gloo-mesh \
  --wait
```

## Check default values of the helm chart - optional
```bash
helm show values gloo-platform/gloo-platform --version "${GLOO_MESH_VERSION}" > default-values-gloo-platform-helm-chart.yaml
open default-values-gloo-platform-helm-chart.yaml
```

## Create helm values overrides file to install Gloo Mesh management plane
```bash
cat << EOF > gloo-platform-management-server-helm-values.yaml
common:
  cluster: "${MGMT_CONTEXT}"
# Gloo Platform product licenses.
licensing:
  glooMeshLicenseKey: "${GLOO_MESH_LICENSE_KEY}"
  glooGatewayLicenseKey: "${GLOO_GATEWAY_LICENSE_KEY}"
  glooNetworkLicenseKey: "${GLOO_NETWORK_LICENSE_KEY}"
glooMgmtServer:
  enabled: true
  serviceType: LoadBalancer
  serviceOverrides:
    metadata:
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
glooUi:
  enabled: true
prometheus:
  enabled: true
redis:
  deployment:
    enabled: true
telemetryGateway:
  enabled: true
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
telemetryCollector:
  enabled: true
EOF
```

## Install Gloo Mesh Management plane
```bash
helm upgrade --install gloo-platform gloo-platform/gloo-platform \
  --namespace gloo-mesh \
  --kube-context "${MGMT_CONTEXT}" \
  --version="${GLOO_MESH_VERSION}" \
  -f gloo-platform-management-server-helm-values.yaml \
  --wait
```

## Validation using meshctl

### Install meshctl
```bash
curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION="v${GLOO_MESH_VERSION}" sh - ;
export PATH=$HOME/.gloo-mesh/bin:$PATH
```

### check status using meshctl CLI
```bash
meshctl check --kubecontext "${MGMT_CONTEXT}"
```

### check status using Gloo Mesh UI
```bash
meshctl dashboard --kubecontext "${MGMT_CONTEXT}"
```

### Navigation links for other steps

* [Step 2 - Install Gloo Mesh Agent components in workload cluster](./step-2-install-gm-agent.md)
* [Step 3 - Install Gloo Mesh Managed Istiod using IstioLifecycleManager](./step-3-install-istio-with-ILM.md)
* [Step 4 - Install Gloo Mesh Managed Istio Ingress gateway using GatewayLifecycleManager](./step-4-install-gateway-with-GLM.md)
* [Step 5 - Install sample applications](./step-5-sample-app.md)
