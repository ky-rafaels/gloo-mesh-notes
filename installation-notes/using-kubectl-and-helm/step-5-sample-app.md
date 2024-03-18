### Navigation links for other steps

* [Step 1 - Install Gloo Mesh Management Plane components in management cluster](./step-1-install-gm-mgmt-server-in-mgmt-cluster.md)
* [Step 2 - Install Gloo Mesh Agent components in workload cluster](./step-2-install-gm-agent.md)
* [Step 3 - Install Gloo Mesh Managed Istiod using IstioLifecycleManager](./step-3-install-istio-with-ILM.md)
* [Step 4 - Install Gloo Mesh Managed Istio Ingress gateway using GatewayLifecycleManager](./step-4-install-gateway-with-GLM.md)

# Step 5 - Install sample applications

## Set required environment variables

```bash
export REMOTE_CONTEXT=
```

## Create `client-namespace` and enable sidecar injection using istio-injection label

```bash
kubectl --context "${REMOTE_CONTEXT}" apply -f- <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: client-namespace
  labels:
    istio-injection: enabled
EOF
```

## Deploying client app [Netshoot](https://github.com/nicolaka/netshoot) which has grpcurl

```bash
kubectl --context "${REMOTE_CONTEXT}" -n client-namespace apply -f- <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: netshoot
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: netshoot
spec:
  replicas: 1
  selector:
    matchLabels:
      app: netshoot
  template:
    metadata:
      labels:
        app: netshoot
    spec:
      serviceAccountName: netshoot
      containers:
      - name: netshoot
        image: docker.io/nicolaka/netshoot:v0.12
        command: ["/bin/sh", "-c", "while true; do sleep 10; done"]
EOF
```

## Create `server-namespace` and enable sidecar injection using istio-injection label

```bash
kubectl --context "${REMOTE_CONTEXT}" apply -f- <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: server-namespace
  labels:
    istio-injection: enabled
EOF
```

## Deploy gRPC backend server app [nmnellis/istio-echo](https://raw.githubusercontent.com/nmnellis/istio-echo/master/deploy/kube/istio-echo.yaml)

```bash
kubectl --context "${REMOTE_CONTEXT}" -n server-namespace apply -f- << EOF
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  labels:
    app: backend
    service: backend
spec:
  ports:
  - port: 8080
    name: http
  - port: 9080
    name: http2-grpc
  selector:
    app: backend
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend
  labels:
    account: backend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-v1
  labels:
    app: backend
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
      version: v1
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      serviceAccountName: backend
      containers:
      - name: backend
        image: ghcr.io/nmnellis/istio-echo:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
        args:
          - --name
          - backend-v1
          - --port
          - "8080"
          - --grpc
          - "9080"
          - --version
          - v1
          - --cluster
          - "${REMOTE_CONTEXT}"
EOF
```

# Validation of pod to pod communication on the mesh

## exec into client pod's container

```bash
kubectl --context=${REMOTE_CONTEXT} -n client-namespace exec -it \
  deploy/netshoot \
  -c netshoot -- bash
```

## follow server application log from application container

```bash
kubectl --context "${REMOTE_CONTEXT}" -n server-namespace \
  logs -f deploy/backend-v1 -c backend
```

## follow logs - client's envoy proxy sidecar container

```bash
kubectl --context "${REMOTE_CONTEXT}" -n client-namespace \
  logs -f deploy/netshoot -c istio-proxy
```

## follow logs - server's envoy proxy sidecar container

```bash
kubectl --context "${REMOTE_CONTEXT}" -n server-namespace \
  logs -f deploy/backend-v1 -c istio-proxy
```

## test gRPC pod-to-pod communication from the exec-ed shell

```bash
grpcurl -plaintext backend.server-namespace:9080 proto.EchoTestService/Echo | jq -r '.message'
```

## test http - (optional)
```bash
curl http://backend.server-namespace:8080
```

## check envoy access loglines - formatted and sorted by keys using jq

```bash
kubectl --context "${REMOTE_CONTEXT}" -n client-namespace \
  logs deploy/netshoot -c istio-proxy | \
  tail -3 | \
  jq --sort-keys
```

```bash
kubectl --context "${REMOTE_CONTEXT}" -n server-namespace \
  logs deploy/backend-v1 -c istio-proxy | \
  tail -3 | \
  jq --sort-keys
```
