# Bootstrapping steps

Once you have applied the `cluster-services` Terraform project, you should
run the following commands against the cluster.

1. Manually store the Signon API token as a secret.

  ```shell
  kubectl -n apps create secret generic signon-auth-token --from-literal=token=$(openssl rand -base64 40)
  ```

2. Manually create all of secrets specified as ExternalSecrets in AWS
  SecretsManager. E.g. see charts/govuk-apps-conf/templates/external-secrets/*.yaml
  and charts/cluster-secrets/*.yaml
