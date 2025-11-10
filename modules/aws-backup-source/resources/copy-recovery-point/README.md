# Copy Recovery Point Lambda

Initiates or monitors an AWS Backup copy job to copy a recovery point from the destination (air‑gapped) backup vault back into the source account's backup vault.

## Cross-account invocation

If the destination (air‑gapped) vault lives in a separate AWS account, set the environment variable `ASSUME_ROLE_ARN` (wired via Terraform variable `lambda_copy_recovery_point_assume_role_arn`). When present the function:

1. Calls `sts:AssumeRole` on that ARN.
2. Uses the temporary credentials to invoke `StartCopyJob` / `DescribeCopyJob` against AWS Backup.

Minimal destination role policy (tighten resource scope when practical):

```json
{
  "Effect": "Allow",
  "Action": ["backup:StartCopyJob", "backup:DescribeCopyJob"],
  "Resource": "*"
}
```

Trust policy must allow the Lambda execution role in the source account to assume it.

If you deploy this Lambda directly into the destination account you may omit `ASSUME_ROLE_ARN`.

## Event Contract

Start a new copy job:

```json
{
  "recovery_point_arn": "arn:aws:backup:eu-west-2:123456789012:recovery-point:1EB3B5E7-9EB0-435A-A80B-108B488B0D45"
}
```

The request must provide the full recovery point ARN.

Poll an existing copy job:

```json
{
  "copy_job_id": "abcd1234-...."
}
```

Optional fields:

- `metadata`: object merged into request input map (e.g. `{ "trigger": "step-function" }`).
- `wait`: boolean; if true the lambda sleeps 30 seconds before describing the copy job (useful to give AWS Backup time to transition from `CREATED` to `RUNNING` for orchestration stability).

Example starting with wait + metadata:

```json
{
  "recovery_point_arn": "arn:aws:backup:eu-west-2:123456789012:recovery-point:1EB3B5E7-9EB0-435A-A80B-108B488B0D45",
  "wait": true,
  "metadata": {"trigger": "sf", "attempt": 1}
}
```

Example polling with wait:

```json
{
  "copy_job_id": "abcd1234-....",
  "wait": true
}
```

## Response (start)

```json
{
  "statusCode": 200,
  "body": {
    "message": "Copy job started",
    "copy_job": {
      "copy_job_id": "...",
      "state": "CREATED|RUNNING|COMPLETED|FAILED|...",
      "status_message": "...",
      "source_recovery_point_arn": "...",
      "destination_recovery_point_arn": "..."
    }
  }
}
```

## Environment Variables

- `DESTINATION_VAULT_ARN` – ARN of the vault that currently holds the recovery point (air‑gapped/destination).
- `SOURCE_VAULT_ARN` – ARN of the local/source vault to copy into.
- `ASSUME_ROLE_ARN` – (Optional) role to assume in the destination account before API calls.

## Notes

- Lifecycle for the copied recovery point is not overridden; AWS defaults apply.
  
- No continuous polling loop is performed; Step Function orchestration should invoke periodically to monitor status. `wait` adds a one‑off 30s delay, not a loop.
