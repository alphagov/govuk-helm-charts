# ExternalSecrets templates

Templates for use with [External Secrets
Operator](https://external-secrets.io/guides-templating/) are kept here and
read in [../templates/external-secrets/](../templates/external-secrets/) via
Helm's
[`.Files.Get`](https://helm.sh/docs/chart_template_guide/accessing_files/#basic-example).

These templates are Go templates, but not Helm templates. They are interpreted
by the External Secrets operator.

Keeping the ExternalSecrets templates in separate files — rather than writing
them inline inside the Helm templates — avoids nesting Go templates and the
[hard-to-read escaping syntax](https://stackoverflow.com/q/47195593/) which
that entails.
