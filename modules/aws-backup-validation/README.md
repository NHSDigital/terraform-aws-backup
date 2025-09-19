# aws-backup-validation Module

Prototype module that deploys infrastructure to validate AWS Backup Restore Testing jobs.

## Components

- Lambda validator (pluggable placeholder) reading config from SSM Parameter
- Step Functions state machine orchestrating describe + validator + publish result
- EventBridge rule triggering on restore job COMPLETED for a specific restore testing plan ARN
- IAM roles/policies (least-privilege baseline – refine for production)

## Inputs

Refer to `variables.tf` for full list. Key variables:

- `restore_testing_plan_arn` (required)
- `validation_config_json` JSON document with resource-type validation definitions

## Outputs

- `state_machine_arn`
- `validator_lambda_arn`
- `config_parameter_name`

## Example

```hcl
module "backup_validation" {
  source                   = "../modules/aws-backup-validation"
  restore_testing_plan_arn = awscc_backup_restore_testing_plan.backup_restore_testing_plan.arn
  validation_config_json   = jsonencode({
    rds = { sql_checks = [{ database = "appdb", statement = "SELECT 1" }] }
  })
}
```

## Next Steps

- Expand validator logic (RDS via rds-data, S3 manifest comparisons, DynamoDB samples)
- Add CloudWatch metrics & alarms
- Add optional custom Lambda override mapping per resource type
