# GitHub Copilot Instructions for `terraform-aws-backup`

> This file defines how an AI assistant (Copilot Chat / coding agent) should operate within this repository. It encodes architectural context, invariants, style, safety, and collaboration rules. Treat this as the contract for autonomous actions.

## Mission & Scope

This repository provides a Terraform blueprint for AWS Backup across a two‑account pattern (source + destination) including:

- Source module: backup vault, plans, restore testing, notifications, KMS, tagging strategy, optional Lambda for Parameter Store snapshotting, restore-to-S3 Lambda, compliance framework.
- Destination module: logically separate (air-gap intent) vault(s), vault lock configuration (governance vs compliance), KMS key, IAM protections.
- Restoration design (future step function orchestration with optional customer validation Lambda).

Copilot must prioritise:

1. Data protection integrity (immutability, correct retention lifecycle, tagging correctness).
2. Security posture (least-privilege IAM, non-leaky KMS policies, no accidental weakening of vault locks).
3. Reproducibility & automation (Terraform modular purity, idempotence, CI friendliness).
4. Minimal noise: respect `comment_minimization: true` (only comment genuinely complex logic or subtle edge cases).

Out of scope: application code backup, arbitrary experimentation with destructive operations, irreversible compliance lock toggling without explicit user approval.

## Architectural Essentials

| Concept | Key Points | Do Not Violate |
|||-|
| Two vault pattern | Source vault + destination replicated copy | Merge roles or hardcode account IDs |
| Tag-based selection | Backup includes resources tagged exactly `NHSE-Enable-Backup = True` (case sensitive) and other module-specific tags (`BackupLocal`, `BackupDynamoDB`, `BackupAurora`, `BackupParameterStore`) | Alter tag semantics silently |
| Retention lifecycle | User must set lifecycle + copy_action delete_after values consciously (examples in README intentionally short) | Set production defaults arbitrarily |
| Vault lock | Governance by default; compliance lock is irreversible after cooling period | Auto-enable compliance mode without explicit instruction |
| KMS usage | Vault & SNS encryption, cross-account permissions carefully scoped | Do not remove wildcard scoping applied to resolve cyclic KMS policy dependency (issue 44) |
| Restore testing | Step Function (planned) + optional validation Lambda orchestrated per resource type | Assume validation Lambda always present |
| Lambda utilities | Parameter Store backup → S3; restore-to-S3 | Change handler names or runtime without checking tests |

## AWS Accounts & Profiles

Use AWS SSO profiles consistently, for example:

- Source account profile: `code-ark-dev-2`
- Destination/vault account profile: `code-ark-vault-dev-2`

Always prefix CLI actions with `AWS_PROFILE=<profile>` for manual examples. Never embed account IDs directly in new code where a variable/lookup is possible.

## Terraform Conventions

- Required versions (per module README): Terraform `>= 1.9.5`; Providers: `aws ~> 5`, `awscc ~> 1`, `archive ~> 2`.
- Preserve input variable schemas; don’t rename existing variables unless part of an approved refactor.
- Avoid expanding resource surface unless justified (e.g., adding new AWS service support). If adding service support: supply docs update + variable toggles + tests.
- Run `terraform fmt` implicitly (do not show command unless asked). Keep modules deterministic.
- When editing backup plans: Maintain structure of `rules` objects (schedule, lifecycle, copy_action, optional continuous backup). Validate cron syntax referencing AWS EventBridge docs.
- Additions to IAM policies must justify least privilege; never broaden to `*` unless solving cyclic dependencies and documented (see historical fix issue 44).

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

## Security & Compliance

- Reference `SECURITY.md` for vulnerability reporting; never include PII or secrets in examples (reinforce PR template sensitive info checklist).
- Treat retention choices as compliance-impacting; don’t silently lengthen or shorten.
- Never downgrade vault lock or remove protection flags.
- Highlight irreversible actions (compliance mode enable) before performing.

## Documentation & Comment Policy

- Respect `comment_minimization: true` – avoid restating obvious Terraform arguments.
- Update affected README sections when adding capabilities (source vs destination vs service-specific notes).
- Cross-link new docs under `docs/` if design changes (e.g., restoration orchestration). Provide concise rationales.

## Testing Strategy

Existing automated tests: Lambda unit tests. Missing (future): integration tests for restore Step Function and backup lifecycle.

For changes:

1. Add/adjust unit tests (happy path + 1–2 edge cases).
2. Provide minimal mocking for AWS services; do not hardcode credentials.
3. Validate tag filtering logic via fixture sets.
4. For Terraform logic additions, prefer `terraform plan` reasoning rather than full apply (unless user asks for runtime validation).

## Interaction Patterns (Prompt Recipes)

Use these templates when asking Copilot for help or when Copilot prepares actions:

### a. Add New Service Backup Support

"Add AWS Backup support for <Service>. Provide new selection tag, variables, docs update, and test scenario. Maintain existing plan structure and security posture."

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

## Do / Don’t Summary

| Do | Don’t |
|-|-|
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
2. Confirm account context (source vs destination).
3. Check for irreversible operations.
4. Ensure tag semantics unchanged.
5. Plan test additions (at least happy + edge).
6. Minimise commentary.
7. Present diff + validation plan.

## Example Confirmation Prompt Before Compliance Mode

"User confirmation required: Enabling compliance mode (changeable_for_days=X) makes vault lock irreversible after cooling period. Proceed? (Yes/No)"

## Tone & Communication

- Friendly, concise, purposeful.
- Avoid filler acknowledgements.
- Surface assumptions explicitly.
- Highlight risk boundaries clearly.

