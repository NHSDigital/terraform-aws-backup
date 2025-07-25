resource "aws_kms_key" "aws_backup_key" {
  description             = "AWS Backup KMS Key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.backup_key_policy.json
}

resource "aws_kms_alias" "backup_key" {
  name          = "alias/${var.name_prefix}/backup-key"
  target_key_id = aws_kms_key.aws_backup_key.key_id
}

resource "aws_kms_key_policy" "backup_key_policy" {
  key_id = aws_kms_key.aws_backup_key.id
  policy = data.aws_iam_policy_document.backup_key_policy.json
}

data "aws_iam_policy_document" "backup_key_policy" {
  #checkov:skip=CKV_AWS_109:See (CERSS-25168) for more info
  #checkov:skip=CKV_AWS_111:See (CERSS-25169) for more info
  statement {
    sid = "AllowBackupUseOfKey"
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
    actions   = ["kms:GenerateDataKey", "kms:Decrypt", "kms:Encrypt"]
    resources = ["*"]
  }
  statement {
    sid = "EnableIAMUserPermissions"
    principals {
      type        = "AWS"
      identifiers = concat(["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"], local.terraform_role_arns)
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
  statement {
    sid = "Allow attachment of persistent resources"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.backup_copy_vault_account_id}:root"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}
