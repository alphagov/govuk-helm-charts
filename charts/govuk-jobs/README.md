# ⚠️ DEPRECATED

## Please do not add to this chart.

Instead:

- If you want to run a Rake task from a cronjob, use the [cronTasks value]
  your app's configuration ([example]).
- If you need to do something nontrivial in a cronjob and a Rake task isn't a
  good fit, make a chart for it. Use `helm create` and remove all the parts you
  don't need. For example: [search-index-env-sync].
- Is a cronjob really the best fit for your use case? For example, for things
  that need to run every few minutes, consider using a timer or event loop
  within your application.

[cronTasks value]: https://github.com/alphagov/govuk-helm-charts/blob/5ae8b78/charts/generic-govuk-app/values.yaml#L27
[example]: https://github.com/alphagov/govuk-helm-charts/blob/5ae8b78/charts/app-config/values-integration.yaml#L371
[search-index-env-sync]: https://github.com/alphagov/govuk-helm-charts/tree/fe07283/charts/search-index-env-sync
