# GitHub Copilot Instructions for `terraform-aws-backup`

> AI assistant contract defining how to operate within this Terraform AWS Backup blueprint repository.

## Mission & Scope

Two-module Terraform blueprint implementing AWS Backup for disaster recovery with logically air-gapped cross-account replication:

- **Source module** (`modules/aws-backup-source`): vault, plans, restore testing, notifications, KMS, Lambda utilities (Parameter Store → S3, cross-account recovery point copy), compliance framework.
- **Destination module** (`modules/aws-backup-destination`): separate account vault with vault lock (governance/compliance modes), KMS, IAM restrictions, optional cross-account restore permissions.
- **Supported services**: S3, RDS/Aurora, DynamoDB, EBS, Parameter Store (see `COVERED_SERVICES.md` for scope & caveats).

Priority: data protection integrity (immutability, retention correctness, tag semantics), security (least-privilege IAM, safe KMS policies, vault lock protection), reproducibility (modular Terraform, idempotence), comment minimization.

Out of scope: application code backup, speculative destructive operations, compliance mode toggling without explicit approval.

This module is consumed by the `code-ark` repository. See code-ark's `docs/blueprint-ownership.md` for the full ownership boundary between the two repositories.

## Architecture & Key Patterns

### Two-Vault Pattern

Source vault (`aws_backup_vault.main` in source module) + destination replicated vault (destination module). Source vault used for normal restores; destination vault only for disaster recovery when source account compromised. Deploy destination **before** source (destination outputs feed source inputs).

**Critical**: `examples/destination/aws-backups.tf` must be applied first to generate `destination_vault_arn` consumed by source configuration via `TF_VAR_destination_vault_arn`.

### Vault Lock Modes

**Never** auto-enable compliance mode. Require explicit user confirmation with cooling period acknowledgment. See the `vault-lock-safety` skill for full details.

## Agent Skills

Specialist knowledge is organised into on-demand skills under `.github/skills/`. See `.github/skills/README.md` for the full catalogue. Skills cover: backup plans & tag selections, Python Lambdas, and vault lock safety.

Copilot loads skills automatically when relevant to a task. Always-on rules stay here; specialist detail lives in skills.

## Terraform Conventions

- Required versions (per module README): Terraform `>= 1.14.6`; Providers: `aws ~> 6`, `awscc ~> 1`, `archive ~> 2`.
- Preserve input variable schemas; don't rename existing variables unless part of an approved refactor.
- Avoid expanding resource surface unless justified (e.g., adding new AWS service support). If adding service support: supply docs update + variable toggles + tests.
- Run `terraform fmt` implicitly (do not show command unless asked). Keep modules deterministic.
- When editing backup plans: Maintain structure of `rules` objects (schedule, lifecycle, copy_action, optional continuous backup). Validate cron syntax referencing AWS EventBridge docs.
- Additions to IAM policies must justify least privilege; never broaden to `*` unless solving cyclic dependencies and documented (see historical fix issue 44).

### Module Instantiation Order

1. **Destination first** (`examples/destination/aws-backups.tf`): Creates destination vault, outputs `destination_vault_arn`
1. **Source second** (`examples/source/aws-backups.tf`): Consumes `TF_VAR_destination_vault_arn` environment variable (see README GitHub Actions YAML for CI/CD pattern)

Destination must complete before source to avoid missing ARN references.

## Security & Compliance

- Reference `SECURITY.md` for vulnerability reporting; never include PII or secrets in examples.
- Treat retention choices as compliance-impacting; don't silently lengthen or shorten.
- Never downgrade vault lock or remove protection flags.
- Highlight irreversible actions (compliance mode enable) before performing.
- Keep IAM actions minimal; wildcard resources only when service requires it. Document any `resources = ["*"]` with justification comment.

## Documentation & Comment Policy

- Respect `comment_minimization: true` – avoid restating obvious Terraform arguments.
- Update affected README sections when adding capabilities (source vs destination vs service-specific notes).
- Cross-link new docs under `docs/` if design changes (e.g., restoration orchestration). Provide concise rationales.

## Testing Strategy

Existing automated tests: Lambda unit tests. Missing (future): integration tests for restore Step Function and backup lifecycle.

For changes:

1. Add/adjust unit tests (happy path + 1–2 edge cases).
1. Provide minimal mocking for AWS services; do not hardcode credentials.
1. Validate tag filtering logic via fixture sets.
1. For Terraform logic additions, prefer `terraform plan` reasoning rather than full apply (unless user asks for runtime validation).

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

## Quick Checklist Before Acting

1. Read relevant module file(s).
1. Confirm account context (source vs destination).
1. Check for irreversible operations.
1. Ensure tag semantics unchanged.
1. Plan test additions (at least happy + edge).
1. Minimise commentary.
1. Present diff + validation plan.

