# GOV.UK Helm Charts

## Getting started

See [Helm's documentation](https://helm.sh/docs) to get started with Helm.

See the [GOV.UK Kubernetes cluster
docs](https://govuk-kubernetes-cluster-user-docs.publishing.service.gov.uk/)
for an introduction to the cluster or ask [#govuk-ask-platform-engineering] in
Slack.

## Versioned vs unversioned charts

Most of the charts in this repository are designed to be deployed via [Argo
CD](https://argo-cd.readthedocs.io/en/stable/) rather than by `helm install`.
For these charts, we don't use `Chart.Version` or Helm's packaging system.

A few charts are still installed via `helm install` ([via
Terraform](https://github.com/search?q=repo%3Aalphagov%2Fgovuk-infrastructure+path%3Aterraform%2Fdeployments%2Fcluster-services+alphagov.github.io)).
Those charts are [automatically packaged and
pushed](https://github.com/alphagov/govuk-helm-charts/blob/main/.github/workflows/release.yml)
to our Helm repository when a change to `Chart.Version` is merged.

## Repository operations

The Makefile at the root of this repository provides common operational tasks.

Run `make help` to see available targets, including:

- **Linting**: `make lint` runs yamllint across the repository
- **Deployment toggles**: `make enable-deployment-integration`, `make disable-deployment-staging`, etc. for toggling automatic deployments

The `bin/` directory contains utility scripts for repository operations. See [bin/README.md](bin/README.md) for details.

## Local development

### Prerequisites

1. Install Helm and [yq](https://github.com/mikefarah/yq#yq)

    ```sh
    brew install helm yq
    ```

1. Clone the repository

    ```sh
    git clone git@github.com:alphagov/govuk-helm-charts.git
    ```

1. Configure git hooks

    ```sh
    cd govuk-helm-charts &&
    git config core.hooksPath git-hooks
    ```

### Installing an application chart without Argo CD

Inspect the template output of your application chart:

```sh
cd charts/app-config

ENVIRONMENT=integration
APP=collections-publisher
helm template $USER-${APP?} ../generic-govuk-app --values <(
  helm template . --values values-${ENVIRONMENT}.yaml |
  yq e '.|select(.metadata.name=="'$APP'").spec.source.helm.values'
) --set sentry.enabled=false --set rails.createKeyBaseSecret=false
```

To deploy it, run `helm install $USER-...` instead of `helm template $USER...`.
You should see your deployed pod(s) in the list at `kubernetes get pods`, and
be able to interact with it as normal.

Use `helm uninstall $USER-${APP?}` to uninstall your chart when you've finished.

### Chart repository

Some of the charts in this git repository are published via GitHub Actions to a
chart repository hosted on GitHub Pages.

To add the chart repo to Helm:

```sh
helm repo add govuk-helm-charts https://alphagov.github.io/govuk-helm-charts/
```

You can then run `helm search repo <alias>` to see the charts.
`helm repo update` retrieves the latest versions of the packages.

## Schemas

We have several Custom Resource Definitions (CRDs) installed in our Kubernetes clusters, and referenced by the Helm charts
in this repository.

We use [kubeconform] to validate our Kubernetes manifests against schemas for
those resources. This helps us ensure that our Helm charts are correct.

`kubeconform` runs in a GitHub Action as a pre-merge check and can also be run
locally.

You can run the validation tests locally by installing `kubeconform` and running

```shell
mkdir helm-dist
for c in charts/*; do
  helm template "$(basename "$c")" "$c" --output-dir helm-dist
done

kubeconform -schema-location default \
-schema-location "https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
-summary helm-dist
```

[kubeconform]: https://github.com/yannh/kubeconform

## Team

[GOV.UK Platform Engineering](https://github.com/orgs/alphagov/teams/gov-uk-platform-engineering) team looks after this repo. If you're inside GDS, you can find us in [#govuk-platform-engineering] or view our [kanban board](https://trello.com/b/u4FCzm53/).

## Licence

[MIT License](LICENCE)


[#govuk-platform-engineering]: https://gds.slack.com/channels/govuk-platform-engineering
