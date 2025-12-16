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
}
