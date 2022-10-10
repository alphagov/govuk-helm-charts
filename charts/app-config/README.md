# Application configuration Helm chart

The `app-config` chart defines the `Application` resources which determine
which Helm charts ArgoCD continuously deploys into the cluster, the Helm values
which are passed into those charts and other configuration relating to the
GOV.UK apps to be deployed into the cluster.

App configuration belongs in this chart if it is:

 - common to several GOV.UK applications.
 - app-specific but not able to be put in the app's own chart, for example
   because the app uses the generic `govuk-rails-app` chart.

This includes:

 - the `govuk-apps-env` ConfigMap, which contains environment variables common
   to most GOV.UK apps.
 - `ExternalSecrets` mappings for AWS secrets for apps which don't have their own charts.

## Configuration which belongs elsewhere

ExternalSecrets for base cluster services belong in
[../cluster-secrets](../cluster-secrets).
