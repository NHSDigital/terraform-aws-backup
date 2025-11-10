# Copy Recovery Point Lambda

Initiates or monitors an AWS Backup copy job to copy a recovery point from the destination (air‑gapped) backup vault back into the source account's backup vault.

## Event Contract

Start a new copy job:

```json
{
  "recovery_point_id": "1EB3B5E7-9EB0-435A-A80B-108B488B0D45"
}
```

`recovery_point_id` may be either the raw UUID/ID or the full RecoveryPoint ARN.

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
  "recovery_point_id": "1EB3B5E7-9EB0-435A-A80B-108B488B0D45",
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
- `ASSUME_ROLE_ARN` – (Optional) role to use if cross‑account invocation requires assuming a role (future enhancement; current implementation invokes directly).

## Notes

- Lifecycle for the copied recovery point is not overridden; AWS defaults apply.
- If providing only the recovery point ID, the function searches the destination vault for a matching ARN suffix.
- No continuous polling loop is performed; Step Function orchestration should invoke periodically to monitor status. `wait` adds a one‑off 30s delay, not a loop.
