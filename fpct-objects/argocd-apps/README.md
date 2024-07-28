# Usage

This directory includes only ArgoCD application or applicationSets manifests. Two scenarios are provided for multi-cluster and single-cluster setups.

## Istio Advanced Installation Option

There is an advanced installation option provided for Istio gateway and control plane installation using helm + ArgoCD ApplicationSets that can be found in {multi-cluster,single-cluster}/02-admin-config/advanced. This example leverages clsuter generator in an ApplicationSet to install both gateway and controlplane in all clusters registered as a target in ArgoCD. More information on cluster generator can be found here: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Cluster/

