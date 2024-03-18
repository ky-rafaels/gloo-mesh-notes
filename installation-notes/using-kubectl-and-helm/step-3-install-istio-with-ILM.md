# Step 3 - Install Gloo Mesh Managed Istiod using IstioLifecycleManager

## Set required environment variables

```bash
export REMOTE_CONTEXT=
export MGMT_CONTEXT=
# Solo built Istio images details https://support.solo.io/hc/en-us/articles/4414409064596
export HUB=
export ISTIO_VERSION=
```

## Install Istiod using IstioLifecycleManager

```bash
kubectl apply --context "${MGMT_CONTEXT}" -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: IstioLifecycleManager
metadata:
  name: "istiod-control-plane-${REMOTE_CONTEXT}"
  namespace: gloo-mesh
spec:
  installations:
    - # List all workload clusters to install Istio into
      clusters:
      - name: "${REMOTE_CONTEXT}"
        # If set to true, the spec for this revision is applied in the cluster
        defaultRevision: true
      # When set to true, the lifecycle manager allows you to perform in-place upgrades by skipping checks that are required for canary upgrades
      skipUpgradeValidation: true
      istioOperatorSpec:
        # Only the control plane components are installed
        # (https://istio.io/latest/docs/setup/additional-setup/config-profiles/)
        profile: minimal
        # Solo.io Istio distribution repository; required for Gloo Istio.
        # You get the repo key from your Solo Account Representative.
        hub: ${HUB}
        # Any Solo.io Gloo Istio tag
        tag: ${ISTIO_VERSION}
        namespace: istio-system
        # Mesh configuration
        meshConfig:
          # Enable access logging only if using.
          accessLogFile: /dev/stdout
          # Encoding for the proxy access log (TEXT or JSON). Default value is TEXT.
          accessLogEncoding: JSON
          # Enable span tracing only if using.
          enableTracing: true
          defaultConfig:
            # Wait for the istio-proxy to start before starting application pods
            holdApplicationUntilProxyStarts: true
            proxyMetadata:
              # Enable Istio agent to handle DNS requests for known hosts
              # Unknown hosts are automatically resolved using upstream DNS servers
              # in resolv.conf (for proxy-dns)
              ISTIO_META_DNS_CAPTURE: "true"
              # Enable automatic address allocation (for proxy-dns)
              ISTIO_META_DNS_AUTO_ALLOCATE: "true"
          # Set the default behavior of the sidecar for handling outbound traffic
          # from the application
          outboundTrafficPolicy:
            mode: ALLOW_ANY
          # The administrative root namespace for Istio configuration
          rootNamespace: istio-system
        # Traffic management
        values:
          global:
            meshID: gloo-mesh
            network: "${REMOTE_CONTEXT}"
            multiCluster:
              clusterName: "${REMOTE_CONTEXT}"
        # Traffic management
        components:
          pilot:
            k8s:
              env:
              # Disable selecting workload entries for local service routing.
              # Required for Gloo VirtualDestinaton functionality.
              - name: PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES
                value: "false"
EOF
```

### Navigation links for other steps

* [Step 1 - Install Gloo Mesh Management Plane components in management cluster](./step-1-install-gm-mgmt-server-in-mgmt-cluster.md)
* [Step 2 - Install Gloo Mesh Agent components in workload cluster](./step-2-install-gm-agent.md)
* [Step 4 (next step) - Install Gloo Mesh Managed Istio Ingress gateway using GatewayLifecycleManager](./step-4-install-gateway-with-GLM.md)
* [Step 5 - Install sample applications](./step-5-sample-app.md)
