resource "aws_backup_vault" "vault" {
  name        = "${var.source_account_name}-backup-vault"
  kms_key_arn = var.kms_key
}

resource "aws_backup_vault_policy" "vault_policy" {
  backup_vault_name = aws_backup_vault.vault.name
  policy            = data.aws_iam_policy_document.vault_policy.json
}

resource "aws_backup_vault_lock_configuration" "vault_lock" {
  count               = var.enable_vault_protection ? 1 : 0
  backup_vault_name   = aws_backup_vault.vault.name
  changeable_for_days = var.vault_lock_type == "compliance" ? var.changeable_for_days : null
  max_retention_days  = var.vault_lock_max_retention_days
  min_retention_days  = var.vault_lock_min_retention_days
}

data "aws_iam_policy_document" "vault_policy" {

  statement {
    sid    = "AllowCopyToVault"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.source_account_id}:root"]
    }

    actions = [
      "backup:CopyIntoBackupVault"
    ]
    resources = ["*"]
  }
  dynamic "statement" {
    for_each = var.enable_vault_protection ? [1] : []
    content {
      sid    = "DenyBackupDeletion"
      effect = "Deny"

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      actions = [
        "backup:DeleteRecoveryPoint",
        "backup:PutBackupVaultAccessPolicy",
        "backup:UpdateRecoveryPointLifecycle",
        "backup:DeleteBackupVault"
      ]
      resources = ["*"]
    }
  }
}
