resource "aws_backup_vault_policy" "vault_policy" {
  count = var.resources_in_same_account == "" ? 1 : 0

  backup_vault_name = aws_backup_vault.main[0].name
  policy            = data.aws_iam_policy_document.vault_policy[0].json
}

data "aws_iam_policy_document" "vault_policy" {
  count = var.resources_in_same_account == "" ? 1 : 0

  statement {
    sid    = "DenyApartFromTerraform"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      values   = local.terraform_role_arns
      variable = "aws:PrincipalArn"
    }

    actions = [
      "backup:DeleteRecoveryPoint",
      "backup:PutBackupVaultAccessPolicy",
      "backup:UpdateRecoveryPointLifecycle"
    ]

    resources = ["*"]
  }
  dynamic "statement" {
    for_each = var.backup_copy_vault_arn != "" && var.backup_copy_vault_account_id != "" ? [1] : []
    content {
      sid    = "Allow account to copy into backup vault"
      effect = "Allow"

      actions   = ["backup:CopyIntoBackupVault"]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${var.backup_copy_vault_account_id}:root"]
      }
    }
  }
}

moved {
  from = aws_backup_vault_policy.vault_policy
  to   = aws_backup_vault_policy.vault_policy[0]
}

moved {
  from = data.aws_iam_policy_document.vault_policy
  to   = data.aws_iam_policy_document.vault_policy[0]
}
