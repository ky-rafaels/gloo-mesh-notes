### Navigation links for other steps

* [Step 1 - Install Gloo Mesh Management Plane components in management cluster](./step-1-install-gm-mgmt-server-in-mgmt-cluster.md)
* [Step 2 - Install Gloo Mesh Agent components in workload cluster](./step-2-install-gm-agent.md)
* [Step 3 - Install Gloo Mesh Managed Istiod using IstioLifecycleManager](./step-3-install-istio-with-ILM.md)
* [Step 5 - Install sample applications](./step-5-sample-app.md)

# Step 4 - Install Gloo Mesh Managed Istio Ingress gateway using GatewayLifecycleManager

## Set required environment variables

```bash
# required env vars
export REMOTE_CONTEXT=
export MGMT_CONTEXT=
# Solo built Istio images details https://support.solo.io/hc/en-us/articles/4414409064596
export HUB=
export ISTIO_VERSION=
```

## Create istio-gateways Namespace
```bash
kubectl --context "${REMOTE_CONTEXT}" apply -f- <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: istio-gateways
EOF
```

## Create Service to expose the ingress gateway

```bash
kubectl apply --context ${REMOTE_CONTEXT} -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: istio-ingressgateway
  namespace: istio-gateways
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
  labels:
    istio: ingressgateway
    app: istio-ingressgateway
spec:
  type: LoadBalancer
  selector:
    app: istio-ingressgateway
    istio: ingressgateway
  ports:
  # Port for health checks on path /healthz/ready.
  # For AWS ELBs, this port must be listed first.
  - name: status-port
    port: 15021
    targetPort: 15021
  # main http ingress port
  - port: 80
    targetPort: 8080
    name: http2
  # main https ingress port
  - port: 443
    targetPort: 8443
    name: https
EOF
```

## Install Istio Ingress Gateway using GatewayLifecycleManager
```bash
kubectl apply --context ${MGMT_CONTEXT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: GatewayLifecycleManager
metadata:
  name: "istio-ingressgateway-${REMOTE_CONTEXT}"
  namespace: gloo-mesh
spec:
  installations:
    - clusters:
      - name: "${REMOTE_CONTEXT}"
        # If set to true, the spec for this revision is applied in the cluster
        activeGateway: true
      istioOperatorSpec:
        # No control plane components are installed
        profile: empty
        # Solo.io Istio distribution repository; required for Gloo Istio.
        # You get the repo key from your Solo Account Representative.
        hub: ${HUB}
        # The Solo.io Gloo Istio tag
        tag: ${ISTIO_VERSION}
        values:
          gateways:
            istio-ingressgateway:
              customService: true
        components:
          ingressGateways:
            - name: istio-ingressgateway
              namespace: istio-gateways
              enabled: true
              label:
                istio: ingressgateway
EOF
```
