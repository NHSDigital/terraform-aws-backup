resource "aws_backup_vault_policy" "vault_policy" {
  backup_vault_name = aws_backup_vault.vault.name
  policy            = data.aws_iam_policy_document.vault_policy.json
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
      sid    = "DenyBackupVaultAccess"
      effect = "Deny"

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      actions = [
        "backup:DeleteRecoveryPoint",
        "backup:UpdateRecoveryPointLifecycle",
        "backup:DeleteBackupVault",
        "backup:StartRestoreJob",
        "backup:DeleteBackupVaultLockConfiguration",
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = var.enable_vault_protection ? [1] : []
    content {
      sid    = "DenyBackupVaultPolicyExceptTerraform"
      effect = "Deny"

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      actions = [
        "backup:PutBackupVaultAccessPolicy",
      ]
      resources = ["*"]
      condition {
        test     = "ArnNotEquals"
        values   = [var.terraform_role_arn]
        variable = "aws:PrincipalArn"
      }
    }
  }

  # dynamic "statement" {
  #   for_each = var.enable_vault_protection ? [1] : []
  #   content {
  #     sid    = "DenyBackupCopyExceptToSourceAccount"
  #     effect = "Deny"

  #     principals {
  #       type        = "AWS"
  #       identifiers = ["arn:aws:iam::${var.account_id}:root"]
  #     }
  #     actions = [
  #       "backup:CopyFromBackupVault"
  #     ]
  #     resources = ["*"]
  #     condition {
  #       test     = "StringNotEquals"
  #       variable = "backup:CopyTargets"
  #       values = [
  #         "arn:aws:backup:${var.region}:${var.source_account_id}:backup-vault:${var.region}-${var.source_account_id}-backup-vault"
  #       ]
  #     }
  #   }
  # }
}
