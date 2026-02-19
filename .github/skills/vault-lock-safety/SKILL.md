# Vault Lock Safety

Use this skill when the user mentions vault lock, compliance mode, immutability settings, or vault protection.

## Vault Lock Modes

Configured in `modules/aws-backup-destination/backup_vault_lock.tf`:

### Governance Mode (Default)

- Vault is deletable
- Policy is editable
- Suitable for testing and development
- No irreversible consequences

### Compliance Mode

- **IRREVERSIBLE** after the cooling period expires
- Cooling period: `changeable_for_days` (3–36,500 days, default 14)
- During cooling period: lock can still be removed
- After cooling period: **permanent** — cannot be removed, retention cannot be shortened, vault cannot be deleted

## Variable Guards

Both must be set to enable compliance mode:

```hcl
enable_vault_protection = true
vault_lock_type         = "compliance"
```

Optional:

```hcl
changeable_for_days = 14  # cooling period before lock becomes permanent
```

## Mandatory Confirmation

**Never auto-enable compliance mode.**

Before enabling, present this confirmation:

> "User confirmation required: Enabling compliance mode (changeable_for_days=X) makes vault lock irreversible after the cooling period. Proceed? (Yes/No)"

## Vault Policy Protection

`enable_iam_protection` in the destination module denies destructive actions on the vault:

```hcl
enable_iam_protection = true
```

This adds deny statements for `DeleteBackupVault`, `PutBackupVaultAccessPolicy`, `DeleteRecoveryPoint`, `UpdateRecoveryPointLifecycle` except for specified principals.

## Pre-Checklist Before Compliance Mode

1. Confirm retention periods are final (cannot be shortened after lock)
2. Confirm `changeable_for_days` value gives adequate cooling period
3. Confirm this is a production environment (never lock dev/test vaults)
4. Confirm the Information Asset Owner has approved retention values
5. Confirm backup plans and selections are stable (adding new ones is fine, removing is not)
6. Document the decision and date of enablement

## Gotchas

- There is no "undo" for compliance mode after the cooling period
- Governance mode is safe for all environments
- Vault lock applies to the **destination** vault only (source vault has no lock)
- `min_retention_days` and `max_retention_days` on the lock constrain all recovery point lifecycles in the vault
