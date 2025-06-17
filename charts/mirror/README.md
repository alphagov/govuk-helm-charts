# Mirror

A Helm chart for deploying the [GOV.UK mirror](https://github.com/alphagov/govuk-mirror) sync job on Kubernetes.

## Overview

This chart deploys a CronJob that runs the GOV.UK mirror sync process, which is a concurrent crawler and site downloader that creates local copies of the GOV.UK website. The mirrored content is uploaded to AWS S3 buckets and used as backup mirrors for high availability.

## Configuration

### Required Values

| Parameter | Description | Example |
|-----------|-------------|---------|
| `serviceAccount.annotations."eks.amazonaws.com/role-arn"` | AWS IAM role for S3 access | `arn:aws:iam::123456789:role/govuk-mirror-sync` |
| `externalDomainSuffix` | Domain suffix for the site being mirrored | `gov.uk` |
| `assetsDomain` | Assets domain for the site | `assets.publishing.service.gov.uk` |
| `govukEnvironment` | Environment name for S3 bucket naming | `staging` or `production` |

### Optional Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `schedule` | Cron schedule for the sync job | `43 1 * * *` (daily at 1:43 AM) |
| `image.repository` | Container image repository | `govuk-mirror` |
| `image.tag` | Container image tag | `release` |
| `storage.size` | PVC storage size | `1000Gi` |
| `resources.limits.cpu` | CPU limit | `1` |
| `resources.limits.memory` | Memory limit | `1500Mi` |

## Monitoring

The chart includes:

- **PodDisruptionBudget**: Ensures availability during cluster maintenance
- **ExternalSecret**: Manages rate limit tokens from AWS Secrets Manager
- **Resource limits**: Prevents resource exhaustion

The mirror freshness can be monitored via the `last-updated.txt` file created in the S3 bucket.

### Manual Run

To trigger a manual run outside the schedule:

```bash
kubectl create job --from=cronjob/mirror manual-mirror-run -n apps
```

