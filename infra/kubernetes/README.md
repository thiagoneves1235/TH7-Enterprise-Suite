# Kubernetes baseline

Renderize com `kubectl kustomize infra/kubernetes/base`. A policy bloqueia intencionalmente todo tráfego; antes de implantar workloads, desenhe e teste allowlists de DNS, ingress, egress e endpoints privados. Esta pasta não declara aplicações, ingress controller, CSI Secret Store, cluster, cert-manager, HPA/PDB ou storage class.