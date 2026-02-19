# Backup Plans & Selections

Use this skill when the user adds or modifies backup plans, tag-based resource selections, retention lifecycle, or compliance framework checks.

## Tag-Based Resource Selection

Resources are included in backups via tags. Tags are **case-sensitive** — only `True` matches.

| Service | Default Selection Tag | Default Value | Config Variable |
|---------|----------------------|---------------|-----------------|
| S3/RDS (default plan) | `BackupLocal` | `True` | `backup_plan_config` |
| DynamoDB | `BackupDynamoDB` | `True` | `backup_plan_config_dynamodb` |
| EBS | `BackupEBSVol` | `True` | `backup_plan_config_ebsvol` |
| Aurora | `BackupAurora` | `True` | `backup_plan_config_aurora` |
| Parameter Store | `BackupParameterStore` | `True` | `backup_plan_config_parameter_store` |

Consumers override `selection_tag` (e.g. to `NHSE-Enable-Backup`) via the config variable.

### Null-Checking Pattern

`locals.tf` provides null-checked tag values:

```hcl
local.selection_tag_value_*_null_checked
```

If `selection_tag_value` is null, it defaults to `"True"`.

### Additional Selection Tags

`selection_tags` (plural) provides fine-grained filtering (e.g. by environment). Each tag in the list creates an additional `selection_by_tags` block.

## Backup Plan Structure

Plans are in `backup_plan.tf`. Each plan has:

- `rules` — list of objects with:
  - `schedule`: EventBridge cron expression (e.g. `cron(0 1 ? * * *)`)
  - `lifecycle.delete_after`: days until recovery point deletion
  - `copy_action[].delete_after`: days until cross-account copy deletion
  - Optional: `enable_continuous_backup` for PITR

### Cross-Account Copy Action

`copy_action` is only created when **both** conditions are met:

```hcl
var.backup_copy_vault_arn != "" && var.backup_copy_vault_account_id != ""
```

This prevents incomplete cross-account configuration.

## Compliance Framework

Each service has a compliance framework in `backup_framework.tf` checking:

- Backup resources encrypted
- Manual deletion disabled
- Minimum retention ≥ 35 days
- Backup frequency ≥ daily
- Resources are protected
- Last recovery point age within bounds

**Note:** Example retention values are intentionally short (e.g. 2 days) and will **fail** compliance checks by design. Production values require Information Asset Owner input.

## Retention Lifecycle

- `lifecycle.delete_after` — local vault retention
- `copy_action[].delete_after` — destination vault retention
- Never silently lengthen or shorten retention — treat as compliance-impacting
- Validate cron syntax against AWS EventBridge documentation

## Default Enable States

All service plans are **enabled by default**:

```hcl
backup_plan_config_dynamodb  = { enable = true, ... }
backup_plan_config_ebsvol    = { enable = true, ... }
backup_plan_config_aurora    = { enable = true, ... }
backup_plan_config_parameter_store = { enable = true, ... }
```

Consumers must explicitly disable services they do not use.

## Gotchas

- DynamoDB and Aurora do NOT support continuous backup in copy rules
- Aurora requires `restore_testing_overrides` (e.g. `dbsubnetgroupname`)
- S3 requires versioning enabled on the source bucket
- Parameter Store is not a native AWS Backup service — the blueprint uses a Lambda to export parameters to S3, which is then backed up via the normal S3 plan
