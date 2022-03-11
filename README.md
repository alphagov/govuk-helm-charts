## Usage

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Refer to the [GOV.UK Kubernetes Cluster User Docs] for an introduction to
the cluster or ask for help from [#govuk-replatforming] in Slack.

Once Helm has been set up correctly, add the repo as follows:

    helm repo add govuk-helm-charts https://alphagov.github.io/govuk-helm-charts/

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
<alias>` to see the charts.

To install the <chart-name> chart:

    helm install my-<chart-name> <alias>/<chart-name>

To uninstall the chart:

    helm delete my-<chart-name>

## Schemas

Refer to `schemas/README.md` for guidance on the schema that the Kubernetes
manifests are validated against.

[GOV.UK Kubernetes Cluster User Docs]: https://govuk-k8s-user-docs.publishing.service.gov.uk
[#govuk-replatforming]: https://gds.slack.com/channels/govuk-replatforming
