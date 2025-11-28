# Lambda Restore to RDS

Starts or monitors an AWS Backup restore of an RDS recovery point into a new DB instance in the same account.

Two modes:

1. START: Provide required identifiers to create a new restored instance.
2. MONITOR: Provide an existing `restore_job_id` to poll until completion or timeout.

## Event Contract

START example:

```json
{
  "recovery_point_arn": "arn:aws:backup:eu-west-2:123456789012:recovery-point:ABCDEF123456",
  "db_instance_identifier": "restored-app-db"
}
```

Optional fields:

- `db_instance_class`
- `db_subnet_group_name`
- `vpc_security_group_ids`
- `restore_metadata_overrides`
- `copy_source_tags_to_restored_resource` (boolean)

MONITOR mode:

```json
{ "restore_job_id": "1234abcd-job" }
```

## Environment Variables

- `IAM_ROLE_ARN` – Backup service role (injected by Terraform)
- `POLL_INTERVAL_SECONDS` – Poll delay (default 30)
- `MAX_WAIT_MINUTES` – Max wait before 202 (default 10)

## Behaviour

- Same-account enforcement (must copy cross-account recovery points first).
- Supports optional copying of source backup tags.
- Returns HTTP 200 (completed), 500 (failed/aborted), or 202 (still running after timeout).

## CLI Examples

Start:

```bash
AWS_PROFILE=code-ark-dev-2 aws lambda invoke \
    --function-name <name_prefix>_lambda-restore-to-rds \
    --cli-binary-format raw-in-base64-out \
    --payload '{"recovery_point_arn":"<rp_arn>","db_instance_identifier":"restored-db-1"}' \
    rds_restore_start.json
```

Monitor:

```bash
AWS_PROFILE=code-ark-dev-2 aws lambda invoke \
    --function-name <name_prefix>_lambda-restore-to-rds \
    --cli-binary-format raw-in-base64-out \
    --payload '{"restore_job_id":"<job_id>"}' \
    rds_restore_monitor.json
```

## Testing

```bash
python test_restore_to_rds.py
```

## Notes

- Copy recovery point locally first for air-gapped workflows.
- Use tag copying sparingly.
