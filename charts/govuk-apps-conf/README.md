The `govuk-apps-conf` chart defines configuration items which are shared
between multiple GOV.UK apps.

It defines a ConfigMap which contains environment variables applied to all
GOV.UK apps.

It also the place to define ExternalSecrets mappings for AWS secrets which are
used by multiple apps but don't logically "belong" to any one app, for example
the API key for logging stacktraces to Sentry (an error-tracking SaaS product).

Temporarily, we're putting app-specific ExternalSecrets here as well because we
don't have individual app charts to put them in yet (because we're redeploying
the `govuk-rails-app` chart with different values instead of creating a chart
per app).

ExternalSecrets for cluster (i.e. non-application) services belong in
[../cluster-secrets](../cluster-secrets).
