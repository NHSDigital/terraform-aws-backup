# GitHub Copilot Instructions for `terraform-aws-backup`

> AI assistant contract defining how to operate within this Terraform AWS Backup blueprint repository.

## Mission & Scope

Two-module Terraform blueprint implementing AWS Backup for disaster recovery with logically air-gapped cross-account replication:

- **Source module** (`modules/aws-backup-source`): vault, plans, restore testing, notifications, KMS, Lambda utilities (Parameter Store → S3, cross-account recovery point copy), compliance framework.
- **Destination module** (`modules/aws-backup-destination`): separate account vault with vault lock (governance/compliance modes), KMS, IAM restrictions, optional cross-account restore permissions.
- **Supported services**: S3, RDS/Aurora, DynamoDB, EBS, Parameter Store (see `COVERED_SERVICES.md` for scope & caveats).

Priority: data protection integrity (immutability, retention correctness, tag semantics), security (least-privilege IAM, safe KMS policies, vault lock protection), reproducibility (modular Terraform, idempotence), comment minimization.

Out of scope: application code backup, speculative destructive operations, compliance mode toggling without explicit approval.

## Architecture & Key Patterns

### Two-Vault Pattern

Source vault (`aws_backup_vault.main` in source module) + destination replicated vault (destination module). Source vault used for normal restores; destination vault only for disaster recovery when source account compromised. Deploy destination **before** source (destination outputs feed source inputs).

**Critical**: `examples/destination/aws-backups.tf` must be applied first to generate `destination_vault_arn` consumed by source configuration via `TF_VAR_destination_vault_arn`.

### Tag-Based Resource Selection

Resources included in backups via tags:

- **General**: `NHSE-Enable-Backup = True` (case-sensitive) for S3/RDS/EBS
- **Service-specific**: `BackupDynamoDB`, `BackupAurora`, `BackupParameterStore` (tag keys defined in `variables.tf` `backup_plan_config_*` blocks)

Selection logic in `backup_plan.tf` uses `aws_backup_selection` resources with `selection_by_tags` blocks. Tag values default to `"True"` if `selection_tag_value` is null (see `locals.tf` null-checking pattern: `local.selection_tag_value_*_null_checked`).

### Retention Lifecycle Design

Example retention values in `examples/source/aws-backups.tf` are **intentionally short** (e.g., 35 days daily, 365 days destination copy). Production values require Information Asset Owner input. Each `backup_plan_config.rules` object requires:

- `schedule`: EventBridge cron expression (e.g., `cron(0 1 ? * * *)`)
- `lifecycle.delete_after`: days until recovery point deletion
- `copy_action[].delete_after`: days until cross-account copy deletion (only if `backup_copy_vault_arn` set)

**Important**: `copy_action` only created when both `backup_copy_vault_arn` and `backup_copy_vault_account_id` are non-empty (see `backup_plan.tf` dynamic block condition).

### Vault Lock Modes

`modules/aws-backup-destination/backup_vault_lock.tf`:

- **Governance** (default): vault deletable, policy editable, suitable for testing
- **Compliance**: irreversible after `changeable_for_days` cooling period (3-36,500 days, default 14)

**Never** auto-enable compliance mode. Require explicit user confirmation with cooling period acknowledgment. Variable guards: `enable_vault_protection` + `vault_lock_type = "compliance"`.

### Lambda Function Patterns

All Lambdas in `modules/aws-backup-source/resources/*/`:

- **Runtime**: Python 3.12
- **Testing**: `test_*.py` using `unittest.mock` for AWS client mocking
- **Environment config**: Load from `os.environ` with `load_configuration()` pattern
- **Error handling**: Log exceptions with `exc_info=True`, return `{"status": "FAILED", "error": ...}` dicts

Key Lambdas:

1. **parameter-store-backup** (`parameter_store_backup.py`): Discovers SSM parameters by tag, encrypts with KMS, stores JSON in S3. Handles pagination (`NextToken`).
1. **copy-recovery-point** (`copy_recovery_point.py`): Cross-account recovery point copy with STS assume role, waits for `COMPLETED`/`FAILED` state with configurable `WAIT_DELAY_SECONDS`.

Test invocation: `python test_<name>.py` (no pytest/coverage tools configured).

## AWS Profiles & Multi-Account Workflow

**From `.github/instructions/memory.instructions.md`**:

- Source account: `AWS_PROFILE=code-ark-dev-2` (723760173216)
- Destination/vault account: `AWS_PROFILE=code-ark-vault-dev-2` (954869684612)

Always use profile prefix for CLI commands in examples. Use `data.aws_caller_identity.current.account_id` and `data.aws_arn.destination_vault_arn.account` for dynamic account ID resolution (see `examples/source/aws-backups.tf` locals).

## Terraform Conventions

- Required versions (per module README): Terraform `>= 1.9.5`; Providers: `aws ~> 5`, `awscc ~> 1`, `archive ~> 2`.
- Preserve input variable schemas; don't rename existing variables unless part of an approved refactor.
- Avoid expanding resource surface unless justified (e.g., adding new AWS service support). If adding service support: supply docs update + variable toggles + tests.
- Run `terraform fmt` implicitly (do not show command unless asked). Keep modules deterministic.
- When editing backup plans: Maintain structure of `rules` objects (schedule, lifecycle, copy_action, optional continuous backup). Validate cron syntax referencing AWS EventBridge docs.
- Additions to IAM policies must justify least privilege; never broaden to `*` unless solving cyclic dependencies and documented (see historical fix issue 44).

### Module Instantiation Order

1. **Destination first** (`examples/destination/aws-backups.tf`): Creates destination vault, outputs `destination_vault_arn`
1. **Source second** (`examples/source/aws-backups.tf`): Consumes `TF_VAR_destination_vault_arn` environment variable (see README GitHub Actions YAML for CI/CD pattern)

Destination must complete before source to avoid missing ARN references.

## Python Lambda Guidelines

Current Lambdas (under `modules/aws-backup-source/resources/`):

- `parameter-store-backup/parameter_store_backup.py`
- `restore-to-s3/restore_to_s3.py`

Testing files exist. Maintain test runnable via `python test_<name>.py`.

Assumptions:

- Python version: 3.12
- Style: flake8

Edge Cases to cover for new Lambda code:

- Empty parameter sets / paginated SSM responses.
- Large S3 object sets (paging, memory).
- Retry transient AWS errors (throttling, network).

### Lambda Testing Pattern

From `test_parameter_store_backup.py`:

```python
@patch.dict(os.environ, {
    'KMS_KEY_ARN': 'test-kms-key',
    'PARAMETER_STORE_BUCKET_NAME': 'test-bucket',
    'TAG_KEY': 'test-key',
    'TAG_VALUE': 'test-value'
})
def test_load_configuration(self):
    config = load_configuration()
    self.assertEqual(config['kms_key_id'], 'test-kms-key')
```

- Mock AWS clients using `unittest.mock.MagicMock`
- Patch environment variables with `@patch.dict(os.environ, {...})`
- Test success path + at least one failure scenario
- Run directly: `python test_<name>.py` (no pytest dependency)

## Security & Compliance

- Reference `SECURITY.md` for vulnerability reporting; never include PII or secrets in examples (reinforce PR template sensitive info checklist).
- Treat retention choices as compliance-impacting; don't silently lengthen or shorten.
- Never downgrade vault lock or remove protection flags.
- Highlight irreversible actions (compliance mode enable) before performing.

### IAM Policy Pattern

From `modules/aws-backup-source/lambda_parameter_store_backup.tf`:

```terraform
statement {
  effect    = "Allow"
  actions   = [
    "ssm:DescribeParameters",
    "ssm:GetParametersByPath",
    "ssm:GetParameter",
    "ssm:GetParameters",
    "ssm:ListTagsForResource"
  ]
  resources = ["arn:aws:ssm:*:*:*"]
}
```

Keep IAM actions minimal; wildcard resources only when service requires it (SSM parameters, KMS encrypt operations). Document any `resources = ["*"]` with justification comment.

## Documentation & Comment Policy

- Respect `comment_minimization: true` – avoid restating obvious Terraform arguments.
- Update affected README sections when adding capabilities (source vs destination vs service-specific notes).
- Cross-link new docs under `docs/` if design changes (e.g., restoration orchestration). Provide concise rationales.

### Example Comment Standards

**Avoid** (restates obvious):

```terraform
# Create backup plan
resource "aws_backup_plan" "default" {
  name = "${local.resource_name_prefix}-plan"
}
```

**Acceptable** (explains non-obvious logic):

```terraform
# copy_action only created when both vault ARN and account ID provided
# to avoid incomplete cross-account configuration
dynamic "copy_action" {
  for_each = var.backup_copy_vault_arn != "" && var.backup_copy_vault_account_id != "" && rule.value.copy_action != null ? rule.value.copy_action : {}
  content { ... }
}
```

## Testing Strategy

Existing automated tests: Lambda unit tests. Missing (future): integration tests for restore Step Function and backup lifecycle.

For changes:

1. Add/adjust unit tests (happy path + 1–2 edge cases).
1. Provide minimal mocking for AWS services; do not hardcode credentials.
1. Validate tag filtering logic via fixture sets.
1. For Terraform logic additions, prefer `terraform plan` reasoning rather than full apply (unless user asks for runtime validation).

### Running Tests

Lambda tests run directly with Python unittest:

```bash
cd modules/aws-backup-source/resources/parameter-store-backup/
python test_parameter_store_backup.py
```

No pytest or coverage tools configured. Tests use `unittest.mock` extensively for AWS service mocking.

## Interaction Patterns (Prompt Recipes)

Use these templates when asking Copilot for help or when Copilot prepares actions:

### a. Add New Service Backup Support

"Add AWS Backup support for \<Service\>. Provide new selection tag, variables, docs update, and test scenario. Maintain existing plan structure and security posture."

### b. Adjust Retention Policy

"Modify daily rule retention from 35 to 60 days while keeping copy retention 365. Show diff only for affected rule."

### c. Parameter Store Enhancement

"Extend parameter store backup Lambda to skip parameters with key prefix 'SECRET_'. Update tests accordingly."

### d. Restoration Orchestration

"Draft Step Function definition (JSON/YAML) for cross-account copy then restore for DynamoDB including optional validation Lambda invocation."

### e. Vault Lock Decision Aid

"Summarise risks & pre-checklist before enabling compliance mode vault lock."

## Required Assistant Behaviours

- Always gather file context via read operations before edits.
- Use research (AWS & Terraform registry docs) before introducing new AWS Backup features.
- Avoid speculative architecture changes; anchor to existing README and module contracts.
- When uncertain about org-specific defaults (retention, Python version, lint tools) explicitly ask for confirmation.
- Never execute destructive operations (deleting vaults, disabling locks) without an explicit user directive.

## Do / Don't Summary

| Do | Don't |
|----|----|
| Preserve variable interfaces | Rename inputs casually |
| Validate cron & retention logic | Invent retention defaults |
| Minimise comments | Add commentary on trivial assignments |
| Ask before irreversible actions | Enable compliance lock silently |
| Provide concise diffs | Dump entire file unchanged |
| Cite external docs when adding features | Rely solely on prior model memory |

## Branching & PR conventions

Branch naming convention: `ENG-<ticket>-short-desc` or `<user-short-code>-ENG-<ticket>-short-desc`.

Pull Request title format: `ENG-<ticket> <short description>` (may be prefixed with user short code similarly).

These conventions should be enforced in examples and automation; assistants generating branches or PR titles must adhere unless user explicitly overrides.

## Research References

Limited external docs fetched (GitHub Copilot documentation landing pages). For deeper feature additions: consult AWS Backup docs (vault locks, logically air-gapped vaults, restore testing) and Terraform Provider AWS registry.

## Quick Checklist Before Acting

1. Read relevant module file(s).
1. Confirm account context (source vs destination).
1. Check for irreversible operations.
1. Ensure tag semantics unchanged.
1. Plan test additions (at least happy + edge).
1. Minimise commentary.
1. Present diff + validation plan.

## Example Confirmation Prompt Before Compliance Mode

"User confirmation required: Enabling compliance mode (changeable_for_days=X) makes vault lock irreversible after cooling period. Proceed? (Yes/No)"

## Tone & Communication

- Friendly, concise, purposeful.
- Avoid filler acknowledgements.
- Surface assumptions explicitly.
- Highlight risk boundaries clearly.

