resource "aws_backup_vault_policy" "vault_policy" {
  count = var.resources_in_same_account ? 1 : 0

  backup_vault_name = aws_backup_vault.vault[0].name
  policy            = data.aws_iam_policy_document.vault_policy[0].json
}

data "aws_iam_policy_document" "vault_policy" {
  count = var.resources_in_same_account ? 1 : 0

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
    for_each = var.enable_iam_protection ? [1] : []
    content {
      sid    = "DenyBackupVaultAccess"
      effect = "Deny"

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      actions = [
        "backup:DeleteRecoveryPoint",
        "backup:PutBackupVaultAccessPolicy",
        "backup:UpdateRecoveryPointLifecycle",
        "backup:DeleteBackupVault",
        "backup:StartRestoreJob",
        "backup:DeleteBackupVaultLockConfiguration",
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = var.enable_vault_protection && var.source_vault_arn != "" ? [1] : []
    content {
      sid    = "DenyBackupCopyExceptToSourceAccount"
      effect = "Deny"

      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${var.account_id}:root"]
      }
      actions = [
        "backup:CopyFromBackupVault"
      ]
      resources = ["*"]
      condition {
        test     = "StringNotEquals"
        variable = "backup:CopyTargets"
        values = [
          var.source_vault_arn
        ]
      }
    }
  }
}

# -----

moved {
  from = aws_backup_vault_policy.vault_policy
  to   = aws_backup_vault_policy.vault_policy[0]
}

moved {
  from = data.aws_iam_policy_document.vault_policy
  to   = data.aws_iam_policy_document.vault_policy[0]
}
