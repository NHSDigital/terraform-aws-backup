# AWS Backup Manual Restore Validation Module

Provides an on-demand Lambda **orchestrator** that:

1. Selects a recovery point (latest by default) from a specified backup vault.
2. Starts a restore job for the chosen recovery point (supports S3 in example).
3. Waits for restore job completion (polling AWS Backup).
4. Invokes a **customer-provided validation Lambda** (you own resource-specific logic).
5. Publishes validation status back to AWS Backup using `PutRestoreValidationResult`.

This pattern differs from automated restore testing plans: it is **manually triggered** (e.g. via `aws lambda invoke` or an API Gateway front-end) and delegates validation logic entirely to a customer-maintained Lambda.

## Key Design Principles

- **Separation of concerns**: Orchestrator handles restore lifecycle & result publishing; customer Lambda handles semantic integrity checks.
- **Pluggable**: Any runtime or language for validator (only contract is JSON in/out).
- **Minimal surface**: No Step Functions required for single-resource manual validation.

## Orchestrator Environment Variables

| Variable | Purpose |
|----------|---------|
| `BACKUP_VAULT_NAME` | Source vault to enumerate recovery points |
| `RESOURCE_TYPE` | Backup resource type (e.g. `S3`) |
| `VALIDATOR_LAMBDA` | ARN of customer validator Lambda |
| `TARGET_BUCKET` | (S3 only) Destination bucket name to validate |
| `RESTORE_ROLE_ARN` | (Optional) IAM role used for restore job |

## Customer Validator Contract

**Invocation Payload** (example):

```json
{
  "restoreJobId": "1234abcd",
  "recoveryPointArn": "arn:aws:backup:...:recovery-point:...",
  "resourceType": "S3",
  "createdResourceArn": "arn:aws:s3:::restored-bucket",
  "targetBucket": "restored-bucket",
  "s3": { "bucket": "restored-bucket" }
}
```

**Return Object**:

```json
{ "status": "SUCCESSFUL|FAILED|SKIPPED", "message": "Human readable summary" }
```
Statuses are normalised by the orchestrator before calling `PutRestoreValidationResult`.

## Terraform Inputs

See `variables.tf` for full list. Essential:

```hcl
module "manual_validation" {
  source               = "../modules/aws-backup-manual-validation"
  enable               = true
  name_prefix          = var.name_prefix
  backup_vault_name    = var.backup_vault_name
  resource_type        = "S3"
  validation_lambda_arn = aws_lambda_function.customer_validator.arn
  target_bucket_name   = var.target_restore_bucket
}
```

## Example Validator (S3 Presence / Count)

See `../../examples/customer-s3-validator` for a full TypeScript implementation scanning a set of expected keys or listing a prefix to ensure non-empty restore.

## Operational Notes

- Timeouts: Orchestrator Lambda default timeout is 15 minutes; long restores will exceed this—use small test datasets or adapt to Step Functions if needed.
- Costs: Avoid listing millions of S3 keys in the validator; prefer sampling.
- IAM Hardening: Current policy uses broad `backup:*` subset and `s3:Get*`; tighten to specific ARNs in production.

## Future Enhancements

- Option to specify explicit recovery point instead of auto-pick (supported already via event.recoveryPointArn field).
- Emit custom CloudWatch metrics for validation duration & success rate.
- Optional SNS notification on failure.

---
MIT style licensing per repository policy.
