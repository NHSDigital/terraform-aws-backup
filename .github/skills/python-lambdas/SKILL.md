---
name: python-lambdas
description: Knowledge for working with Python Lambda functions under the aws-backup-source module, including catalogue, conventions, testing, and deployment details.
---

# Python Lambdas

Use this skill when the user works on Python Lambda code under `modules/aws-backup-source/resources/`.

## Lambda Catalogue

| Lambda | File | Purpose | Trigger | Has Tests |
| -------- | ------ | --------- | --------- | ----------- |
| **parameter-store-backup** | `parameter_store_backup.py` | Discovers SSM parameters by tag, encrypts with KMS, writes to S3 as `.encrypted` files | EventBridge cron (default: `0 6 * * ? *`) | Yes (4 cases) |
| **copy-recovery-point** | `copy_recovery_point.py` + `lambda_function.py` | Copies recovery points from destination vault back to source vault cross-account via STS | EventBridge / manual | Yes (4 cases) |
| **restore-to-s3** | `restore_to_s3.py` | Starts/monitors AWS Backup S3 recovery point restore jobs | Step Function / manual | Yes (6 cases, uses `botocore.stub.Stubber`) |
| **post_build_version** | `post_build_version.py` | POSTs module version + account ID to API endpoint on every backup job | EventBridge (backup job complete) | No |

### Stub Directories (Planned, Not Implemented)

- `restore-to-aurora/` — empty (`__pycache__/` only)
- `restore-to-dynamodb/` — empty
- `restore-to-rds/` — empty

## Code Patterns

### Configuration Loading

```python
def load_configuration():
    return {
        'kms_key_id': os.environ['KMS_KEY_ARN'],
        'bucket_name': os.environ['PARAMETER_STORE_BUCKET_NAME'],
        ...
    }
```

All config via `os.environ`. Handle `KeyError` for missing vars.

### Error Handling

```python
try:
    result = do_work()
    return {"status": "SUCCESS", ...}
except Exception as e:
    logger.error("Failed", exc_info=True)
    return {"status": "FAILED", "error": str(e)}
```

Log with `exc_info=True`, return structured dicts.

### Cross-Account STS

`copy_recovery_point.py` uses `sts:AssumeRole` when `ASSUME_ROLE_ARN` is set:

```python
sts_client = boto3.client('sts')
credentials = sts_client.assume_role(
    RoleArn=assume_role_arn,
    RoleSessionName='cross-account-copy'
)
```

## The `_build_copy_job_params` Gotcha

In `copy_recovery_point.py`, the naming appears swapped but is **intentional**:

- `DestinationBackupVaultArn` = `source_vault_arn` (copying **into** source)
- `SourceBackupVaultName` = parsed from `destination_vault_arn` (copying **from** destination)

This was a historical bug root cause (ENG-930) and must not be "fixed".

## Testing

```bash
cd modules/aws-backup-source/resources/parameter-store-backup/
python test_parameter_store_backup.py
```

- Framework: `unittest` (no pytest dependency)
- Mocking: `unittest.mock.MagicMock` for AWS clients
- Env vars: `@patch.dict(os.environ, {...})`
- Pattern: test success path + at least one failure scenario
- Run directly: `python test_<name>.py`

## Packaging

- No separate build step — Terraform `data.archive_file` creates zip at plan/apply time
- Each Lambda's `.tf` file references its source directory
- Python runtime: 3.12

## IAM Policy Pattern

Keep actions minimal. Wildcard resources only when the service requires it:

```terraform
statement {
  effect    = "Allow"
  actions   = ["ssm:DescribeParameters", "ssm:GetParametersByPath", ...]
  resources = ["arn:aws:ssm:*:*:*"]
}
```

Document any `resources = ["*"]` with a justification comment.

## Gotchas

- `parameter_store_lambda_encryption_role` is a **fixed role name** referenced by the destination KMS key policy — do not rename
- `post_build_version` has no tests — add tests if modifying
- `copy-recovery-point` has two entry points: `lambda_function.py` re-exports from `copy_recovery_point.py`
- Version is read from `modules/aws-backup-source/version` file at plan time via `file()`
