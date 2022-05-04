## Cluster Security


This chart is installed by the cluster-services govuk-infrastructure
Terraform deployment.

# What does it do?

This chart installs two pod security policies. A baseline policy with moderate restrictions applied only to 'default' and 'apps' namespaces, and a privileged policy with no restrictions applied to all other namespaces in the cluster.

The policy enforces the service accounts in charge of deploying pods (via deployments,rs,sts,ds) abide by the restrictions outlined in the respective policy.