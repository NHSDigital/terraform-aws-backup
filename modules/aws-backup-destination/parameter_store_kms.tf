data "aws_iam_policy_document" "kms_key_policy" {
  count = var.resources_in_same_account ? 1 : 0

  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.enable_cross_account_role_permissions ? ["add_statement"] : []

    content {
      sid    = "Allow Lambda Role from Source Account to Use Key"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${var.source_account_id}:role/parameter_store_lambda_encryption_role"]
      }
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = ["*"]
    }
  }
}

resource "aws_kms_key" "parameter_store_key" {
  count = var.resources_in_same_account ? 1 : 0

  description             = "KMS key for cross-account encryption of Parameter Store backups."
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms_key_policy[0].json
}

resource "aws_kms_alias" "parameter_store_alias" {
  count = var.resources_in_same_account ? 1 : 0

  name          = "alias/parameter-store-backup-key"
  target_key_id = aws_kms_key.parameter_store_key[0].key_id
}

output "parameter_store_kms_key_arn" {
  description = "The ARN of the KMS key created in the backup account."
  value       = var.resources_in_same_account ? aws_kms_key.parameter_store_key[0].arn : null
}

# -----

moved {
  from = data.aws_iam_policy_document.kms_key_policy
  to   = data.aws_iam_policy_document.kms_key_policy[0]
}

moved {
  from = aws_kms_key.parameter_store_key
  to   = aws_kms_key.parameter_store_key[0]
}

moved {
  from = aws_kms_alias.parameter_store_alias
  to   = aws_kms_alias.parameter_store_alias[0]
}
