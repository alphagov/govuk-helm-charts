# GOV.UK Helm Charts


## Getting started

See [Helm's documentation](https://helm.sh/docs) to get started with Helm.

See the [GOV.UK Kubernetes Cluster User Docs] for an introduction to the
cluster or ask [#govuk-replatforming] in Slack.

[GOV.UK Kubernetes Cluster User Docs]: https://govuk-k8s-user-docs.publishing.service.gov.uk/
[#govuk-replatforming]: https://gds.slack.com/channels/govuk-replatforming


## Local development

Most of the charts in this repository are designed to be installed via [Argo
CD] rather than by `helm`. We hope to improve portability over time.

[Argo CD]: https://argo-cd.readthedocs.io/en/stable/

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

```sh
cd charts/app-config

ENVIRONMENT=integration
APP=content-publisher
helm install $USER-${APP?} ../generic-govuk-app --values <(
  helm template . --values values-${ENVIRONMENT}.yaml |
  yq e '.|select(.metadata.name=="'$APP'").spec.source.helm.values'
) --set sentry.enabled=false --set rails.createKeyBaseSecret=false
```

You can inspect the final template output by running `helm template` instead of
`helm install`.


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

`kubeconform` runs as a pre-merge check. The JSON schemas that it validates
against are in the [`schemas/`](schemas) directory.

## Team

GOV.UK Replatforming team looks after this repo. If you're inside GDS, you can find us in [#govuk-replatforming](https://gds.slack.com/archives/C013F737737) or view our [kanban board](https://trello.com/b/u4FCzm53/).

## Licence

[MIT License](LICENCE)
