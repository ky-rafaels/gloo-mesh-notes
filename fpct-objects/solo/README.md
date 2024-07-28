# Solo Custom Resources and Configurations

## Provided Charts

Dependency wrapper charts have been provided in solo/charts directory for the purpose of cases in which a remote pull from a helm chart repo is not possible. 

## A Note on Policy Examples

Example Gloo Platform policy examples have been provided in solo/policies directory. There are currently no ArgoCD apps that point to these examples. A strategy should be developed on how these should be applied to cluster.

An example strategy for applying policies could be delivering this in a custom applications helm chart and enabled through a set of values.