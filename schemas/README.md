# Schemas

This directory contains the JSON schemas for the Custom Resource Definitions
(CRDs) installed in our Kubernetes clusters, and referenced by the Helm charts
in this repository.

## Using the schemas for tests

We use [kubeconform] to validate our Kubernetes manifests against schemas for
those resources. This helps us ensure that our Helm charts are correct.

`kubeconform` runs in a GitHub Action as a pre-merge check and can also be run
locally.

You can run the validation tests locally by installing `kubeconform` and running

```shell
mkdir helm-dist
for c in $(ls charts)
do
  helm template "${c}" "charts/${c}" --output-dir helm-dist
done
kubeconform -schema-location default \
-schema-location "./schemas/{{ .ResourceKind }}_{{ .ResourceAPIVersion }}.json" \
-summary helm-dist
```

[kubeconform]: https://github.com/yannh/kubeconform

## Adding a new schema

Refer to the `kubeconform` documentation on [converting an openapi file to a json schema].

When you use a CRD in a Helm chart you must add a corresponding schema for the
CRD to this schemas directory, in order for kubeconform to validate that your
manifest conforms to the schemas (i.e. you have written a valid Kubernetes manifest).

Example process for generating a schema for the `TrainingJob` CRD:

```
./scripts/openapi2jsonschema.py https://raw.githubusercontent.com/aws/amazon-sagemaker-operator-for-k8s/master/config/crd/bases/sagemaker.aws.amazon.com_trainingjobs.yaml
mv trainingjob-sagemaker-v1.json govuk-helm-charts/schemas
```

[converting an openapi file to a json schema]: https://github.com/yannh/kubeconform#converting-an-openapi-file-to-a-json-schema
