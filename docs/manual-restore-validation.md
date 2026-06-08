# Manual Restore Validation Design

## 1. Purpose

Provide a light‑weight, on-demand restore + validation workflow where the **customer supplies their own validation Lambda**. This complements automated restore testing plans by enabling ad-hoc integrity checks (e.g. regression assessment after schema change, pre-cutover rehearsal) without standing orchestration state machines.

## 2. Overview

Flow (single resource type per invocation):

1. Operator (or CI job) invokes Orchestrator Lambda with optional `recoveryPointArn`.
2. Orchestrator chooses recovery point (latest if unspecified) from a backup vault.
3. Starts restore job using AWS Backup `StartRestoreJob`.
4. Polls status (`DescribeRestoreJob`) until terminal state.
5. Invokes customer validator Lambda with contextual payload.
6. Normalises validator response -> calls `PutRestoreValidationResult`.
7. Returns composite result to caller (for CLI / API inspection).

No Step Functions required for typical short restore + validation cycles; for long running (>15 min) scenarios Step Functions could replace polling.

## 3. Roles & Responsibilities

| Component | Responsibility |
|-----------|----------------|
| Orchestrator Lambda | Restore initiation, polling, validator invocation, publishing result |
| Customer Validator Lambda | Domain/resource-specific integrity checks (S3 object presence, record counts, hashes, etc.) |
| AWS Backup | Recovery point catalog & restore execution |
| IAM | Enforces least privilege for restore & validation actions |

## 4. Invocation Payload (Optional Fields)

```json
{
  "recoveryPointArn": "arn:aws:backup:...:recovery-point:...",  // optional override
  "expectedKeys": ["path/example1.txt", "path/example2.txt"],   // validator-specific
  "expectedMinObjects": 10                                       // optional fallback
}
```

## 5. Validator Contract

Input delivered to customer Lambda (superset of invocation + restore context):

```json
{
  "restoreJobId": "...",
  "recoveryPointArn": "...",
  "resourceType": "S3",
  "createdResourceArn": "arn:aws:s3:::restored-bucket",
  "targetBucket": "restored-bucket",
  "s3": { "bucket": "restored-bucket" },
  "expectedKeys": ["..."],
  "expectedMinObjects": 10
}
```

Return:

```json
{ "status": "SUCCESSFUL|FAILED|SKIPPED", "message": "summary", "details": { } }
```
Status mapping is case-insensitive; unknown maps to FAILED.

## 6. Security Considerations

- Orchestrator policy limited to listing recovery points, starting & describing restore jobs, publishing validation, invoking a single validator ARN.
- Validator policy scoped to specific target bucket ARNs (S3 example).
- Sensitive data avoidance: orchestrator does not log object contents, only metadata.
- Optionally use a dedicated IAM restore role if restore requires cross-service access.

## 7. Error Handling

| Scenario | Behaviour |
|----------|-----------|
| No recovery points | Orchestrator throws error (non-validation) |
| Restore timeout | Error after 55m (FAILED not published) |
| Validator throws | Orchestrator records FAILED with parse/message fallback |
| Validator returns malformed JSON | Treated as FAILED with parse error message |

## 8. Extensibility

- Add multi-resource batch mode via Step Functions if needed.
- Support additional resource types by adjusting Metadata mapping (e.g. RDS cluster restore specifics).
- Emit custom metrics (future) for restore duration & validator latency.

## 9. Example S3 Validator Patterns

| Pattern | Description |
|---------|-------------|
| Key existence | Ensure enumerated critical objects are present (manifest-sourced) |
| Non-empty bucket | Basic continuity signal after restore |
| Minimum count | Validate approximate dataset size threshold |
| Sample integrity | (Future) HEAD + ETag comparison against manifest |

## 10. Terraform Surfaces

Module `aws-backup-manual-validation` variables:

- `backup_vault_name` (string, required)
- `validation_lambda_arn` (string, required)
- `resource_type` (string, e.g. S3)
- `target_bucket_name` (string, S3 convenience)
- `name_prefix` (string)

Outputs:

- `orchestrator_lambda_arn`

## 11. Invocation Examples

AWS CLI (invoke latest recovery point):

```bash
aws lambda invoke \
  --function-name myproj-dev-manual-restore-orchestrator \
  --payload '{}' out.json && cat out.json | jq
```

Explicit recovery point + expected keys:

```bash
aws lambda invoke \
  --function-name myproj-dev-manual-restore-orchestrator \
  --payload '{"recoveryPointArn":"arn:aws:backup:..","expectedKeys":["manifest.json","data/file1"]}' out.json
```

## 12. Limitations

- Long-running restores may exceed Lambda timeout (convert to Step Functions for scale/time).
- Only single resource restore per invocation.
- No built-in notification channel (user can layer SNS or EventBridge rule on Lambda logs/exits).

## 13. Future Enhancements

- Step Functions wrapper for large parallel restores.
- Parameter / Secrets retrieval for RDS validation credentials.
- Config-driven validator selection registry.
