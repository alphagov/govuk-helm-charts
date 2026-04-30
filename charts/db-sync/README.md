# db-sync Helm Chart

Helm chart for deploying `govuk-db-sync` CronJobs to manage database backups and restores across PostgreSQL, MySQL, and DocumentDB.

## Installation

```bash
helm install db-sync ./charts/db-sync \
  -f values-staging.yaml \
  -n database-sync
```

## Configuration

### Basic Job Configuration

Each job in `values.yaml` requires:

- **schedule**: Cron schedule (e.g., `"0 2 * * *"`)
- **operation**: `backup` or `restore`
- **dbType**: `postgres`, `mysql`, or `documentdb`
- **dbName**: Target database name
- **s3Bucket**: S3 bucket for backups (e.g., `s3://govuk-prod-backups`)
- **s3Path**: S3 path prefix (e.g., `myapp/db`)

### Example Configuration

```yaml
cronjobs:
  production:
    # PostgreSQL backup
    account-api-postgres:
      schedule: "37 23 * * *"
      operation: backup
      dbType: postgres
      dbName: account-api_production
      s3Bucket: s3://govuk-prod-database-backups
      s3Path: account-api/db

    # PostgreSQL restore with transformation
    email-alert-api-postgres:
      schedule: "54 3 * * 1"
      operation: restore
      dbType: postgres
      dbName: email-alert-api_production
      s3Bucket: s3://govuk-staging-database-backups
      s3Path: email-alert-api/db
      extraEnv:
        - name: DB_OWNER
          value: email-alert-api

    # MySQL backup
    release-mysql:
      schedule: "11 3 * * 1"
      operation: backup
      dbType: mysql
      dbName: release_production
      s3Bucket: s3://govuk-prod-database-backups
      s3Path: release/db

    # DocumentDB backup
    publisher-documentdb:
      schedule: "13 3 * * 1"
      operation: backup
      dbType: documentdb
      dbName: publisher_production
      s3Bucket: s3://govuk-prod-database-backups
      s3Path: publisher/docdb
```

### Optional Job Configuration

- **suspend**: Set to `true` to disable a job (default: `false`)
- **maxJobRuntimeSeconds**: Maximum job runtime in seconds (default: 43200 = 12 hours)
- **transformScript**: Name of a transform script including path.
- **extraEnv**: Job-specific environment variables
- **resources**: Override default resource limits/requests

## Secrets Management

This chart uses AWS Secrets Manager via the ExternalSecrets operator.

**Expected Secret Structure:**

Create a secret at `govuk/db-sync/passwd` with key/value pairs mapping job names to passwords:

```json
{
  "account-api-postgres": "password123",
  "email-alert-api-postgres": "password456",
  "release-mysql": "password789",
  "publisher-documentdb": "mongodb-connection-string"
}
```

The chart loads these credentials into Kubernetes Secret `db-sync-passwd`, which is referenced by CronJobs.

## IAM Permissions

The ServiceAccount uses AWS IAM Roles for Service Accounts (IRSA). Configure the annotation:

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/db-sync-role
```

**Required IAM Permissions:**
- S3: `s3:GetObject`, `s3:PutObject` on backup buckets
- RDS (for backups): Database instance access
- Secrets Manager: `secretsmanager:GetSecretValue` for `govuk/db-sync/passwd`
- CloudWatch (optional): Metrics publishing

## Transform Scripts

Place SQL/JavaScript transformation scripts in the `scripts/` directory:

```
charts/db-sync/
├── scripts/
│   ├── email-alert-api.sql
│   ├── content-store.sql
│   └── custom-transform.js
```

Reference them in job config:

```yaml
transformScript: email-alert-api.sql
```

## Environment-Specific Values

Create separate values files for each environment:

```bash
values-production.yaml
values-staging.yaml
values-integration.yaml
```

Then deploy with:

```bash
helm install db-sync ./charts/db-sync -f values-production.yaml
```

## Monitoring

Each CronJob logs to stdout. Monitor failures via:
- Kubernetes Events: `kubectl describe cronjob db-sync-<job-name>`
- Pod Logs: `kubectl logs -l app.kubernetes.io/component=<job-name>`
- Failed Jobs: `kubectl get jobs --failed`

## Troubleshooting

**Job not running:**
- Check if suspended: `kubectl get cronjob db-sync-<job-name>`
- Verify schedule is valid: https://crontab.guru/

**Secret not found:**
- Ensure ExternalSecret is synced: `kubectl describe externalsecret db-sync-passwd`
- Check AWS Secrets Manager: `aws secretsmanager get-secret-value --secret-id govuk/db-sync/passwd`

**Pod crash:**
- Check pod logs: `kubectl logs <pod-name> -p` (for previous pod)
- Verify S3 bucket access and IAM permissions
- Check database connectivity and credentials

## Values Reference

See `values.yaml` for all available configuration options.
