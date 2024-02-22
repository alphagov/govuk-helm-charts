# Bootstrapping steps

Once you have applied the `cluster-services` Terraform module, you should
run the following commands against the cluster.

1. In AWS Secrets Manager, create the secrets corresponding to the
   ExternalSecrets in the cluster. SecretsManager. See
   `charts/external-secrets/` and `charts/cluster-secrets/`. You can use a
   script
   ([example](https://github.com/alphagov/govuk-infrastructure/compare/main...sengi/bulk-secrets))
   to dump, edit and load the secrets from an existing environment.
