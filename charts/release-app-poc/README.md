# release-app-poc

A proof-of-concept Helm chart demonstrating the GOV.UK application template library pattern. This chart showcases how to consume shared templates from the `govuk-application-template` library chart to build standardized GOV.UK applications.

## Overview

This chart uses the **govuk-application-template** library to provide reusable Kubernetes resource templates for:

- **Deployment** - Basic application deployment with security best practices
- **Service** - Service exposure with configurable ports and types
- **PodMonitor** - Prometheus metrics collection
- **Sentry** - Error tracking integration via ExternalSecrets
- **Redis** - Redis deployment with persistence (available but not used in this POC)

## Dependencies

This chart depends on the `govuk-application-template` library chart, which is included as a local dependency:

```yaml
dependencies:
  - name: govuk-application-template
    version: "1.0.0"
    repository: "file://../govuk-application-template"
```

## Usage

### Rendering the Chart

To render the chart and see the generated Kubernetes manifests:

```bash
# From the charts/release-app-poc directory
helm template release-app-poc . --debug

# Or specify a release name
helm template my-release . --debug

# Render to a file for inspection
helm template release-app-poc . > rendered-manifests.yaml
```

### Installing the Chart

Before installing, ensure dependencies are updated:

```bash
# Update chart dependencies
helm dependency update

# Install the chart
helm install release-app-poc . --namespace apps --create-namespace

# Install with custom values
helm install release-app-poc . -f custom-values.yaml --namespace apps
```

### Overriding Values

You can override default values in several ways:

#### 1. Custom Values File

Create a `custom-values.yaml` file:

```yaml
# Disable optional components
enablePodMonitor: false
enableSentry: false

# Override image
image:
  repository: my-registry/my-app
  tag: v1.2.3

# Customize environment variables
env:
  LOG_LEVEL: debug
  CUSTOM_VAR: "my-value"

# Adjust resources
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 256Mi
```

Then install with:
```bash
helm install release-app-poc . -f custom-values.yaml
```

#### 2. Command Line Overrides

```bash
# Override specific values
helm install release-app-poc . \
  --set replicaCount=3 \
  --set image.tag=v2.0.0 \
  --set enableSentry=false
```

#### 3. Environment-Specific Values

Create environment-specific value files:

```bash
# values-staging.yaml
replicaCount: 1
env:
  RAILS_ENV: staging

# values-production.yaml  
replicaCount: 3
env:
  RAILS_ENV: production
```

### Extending with App-Specific Resources

To add application-specific resources that aren't covered by the library templates:

#### 1. Add Custom Templates

Create additional template files in the `templates/` directory:

```bash
# templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "govuk-application-template.fullname" . }}-config
data:
  app-config.yaml: |
    custom_setting: {{ .Values.customSetting }}
```

#### 2. Add Custom Values

Extend `values.yaml` with app-specific configuration:

```yaml
# App-specific configuration
customSetting: "my-custom-value"
additionalLabels:
  team: "platform"
  environment: "production"
```

#### 3. Override Template Behavior

You can selectively enable/disable library components:

```yaml
# Enable only what you need
enableService: true
enablePodMonitor: true
enableSentry: false  # Disable if using different error tracking

# Or completely disable the deployment to use a custom one
# (remove templates/deployment.yaml and create your own)
```

## Available Templates from govuk-application-template

The library provides these templates that can be included:

| Template | Include Statement | Purpose |
|----------|------------------|---------|
| Deployment | `{{ include "govuk-application-template.deployment" . }}` | Basic application deployment |
| Service | `{{ include "govuk-application-template.service" . }}` | Service exposure |
| PodMonitor | `{{ include "govuk-application-template.podmonitor" . }}` | Prometheus monitoring |
| Sentry | `{{ include "govuk-application-template.sentry" . }}` | Error tracking setup |
| Redis Deployment | `{{ include "govuk-application-template.redis.deployment" . }}` | Redis deployment |
| Redis Service | `{{ include "govuk-application-template.redis.service" . }}` | Redis service |
| Redis PVC | `{{ include "govuk-application-template.redis.pvc" . }}` | Redis persistence |
| Redis ConfigMap | `{{ include "govuk-application-template.redis.configmap" . }}` | Redis configuration |

## Configuration Values

### Core Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of pod replicas | `2` |
| `image.repository` | Container image repository | `172025368201.dkr.ecr.eu-west-1.amazonaws.com/github/alphagov/govuk/release` |
| `image.tag` | Container image tag | `v565` |
| `image.pullPolicy` | Image pull policy | `Always` |

### Feature Toggles

| Parameter | Description | Default |
|-----------|-------------|---------|
| `enableService` | Enable Service resource | `true` |
| `enablePodMonitor` | Enable PodMonitor for metrics | `true` |
| `enableSentry` | Enable Sentry error tracking | `true` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `NodePort` |
| `service.port` | Service port | `80` |
| `service.targetPort` | Target port on pods | `3000` |

### Monitoring Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `monitoring.enabled` | Enable monitoring | `true` |
| `monitoring.metricsPort` | Metrics port | `9394` |

## Notes

- This chart demonstrates the **library pattern** for Helm charts, promoting code reuse across GOV.UK applications
- The `govuk-application-template` library encapsulates common Kubernetes resource patterns used across GOV.UK
- Templates from the library are designed to be **production-ready** with security best practices built-in
- All library templates use the same **helper functions** for consistent labeling and naming
- To extend this pattern for your own application, copy this POC and modify the values and any app-specific templates

## Development

To modify the underlying templates, edit the `govuk-application-template` library chart. Changes will be reflected in all consuming charts after running `helm dependency update`.

## Troubleshooting

### Common Issues

1. **Template not found errors**: Ensure `helm dependency update` has been run
2. **Values not applied**: Check template conditional logic (`enableX` flags)
3. **Resource conflicts**: Verify resource names don't conflict with existing deployments

### Debug Commands

```bash
# Validate chart syntax
helm lint .

# Dry-run installation
helm install --dry-run --debug release-app-poc .

# Check rendered templates
helm template release-app-poc . --debug > debug-output.yaml
```