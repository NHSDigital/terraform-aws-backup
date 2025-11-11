data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid = "Enable IAM User Permissions"
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
      sid = "Allow Lambda Role from Source Account to Use Key"
      effect = "Allow"
      principals {
        type = "AWS"
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

  dynamic "statement" {
    for_each = var.enable_cross_account_vault_access ? ["allow_backup_key_ops"] : []

    content {
      sid    = "AllowCrossAccountBackupKeyOperations"
      effect = "Allow"
      principals {
        type = "AWS"
        identifiers = [
          try(aws_iam_role.copy_recovery_point[0].arn, ""),
          "arn:aws:iam::${var.source_account_id}:role/aws-service-role/backup.amazonaws.com/AWSServiceRoleForBackup"
        ]
      }
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = var.enable_cross_account_vault_access ? ["allow_backup_grants"] : []

    content {
      sid    = "AllowCrossAccountBackupGrants"
      effect = "Allow"
      principals {
        type = "AWS"
        identifiers = [
          try(aws_iam_role.copy_recovery_point[0].arn, ""),
          "arn:aws:iam::${var.source_account_id}:role/aws-service-role/backup.amazonaws.com/AWSServiceRoleForBackup"
        ]
      }
      actions = [
        "kms:CreateGrant"
      ]
      resources = ["*"]
      condition {
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = ["true"]
      }
    }
  }

  # Additional explicit cross-account backup role permissions mirroring example policy structure
  dynamic "statement" {
    for_each = var.enable_cross_account_vault_access ? ["add_explicit_backup_key_ops"] : []
    content {
      sid    = "AllowCrossAccountBackupKeyOperationsExplicit"
      effect = "Allow"
      principals {
        type = "AWS"
        identifiers = [
          try(aws_iam_role.copy_recovery_point[0].arn, ""),
          "arn:aws:iam::${var.source_account_id}:role/aws-service-role/backup.amazonaws.com/AWSServiceRoleForBackup"
        ]
      }
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = var.enable_cross_account_vault_access ? ["add_explicit_backup_grants"] : []
    content {
      sid    = "AllowCrossAccountBackupGrantsExplicit"
      effect = "Allow"
      principals {
        type = "AWS"
        identifiers = [
          try(aws_iam_role.copy_recovery_point[0].arn, ""),
          "arn:aws:iam::${var.source_account_id}:role/aws-service-role/backup.amazonaws.com/AWSServiceRoleForBackup"
        ]
      }
      actions = ["kms:CreateGrant"]
      resources = ["*"]
      condition {
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = ["true"]
      }
    }
  }
}

resource "aws_kms_key" "parameter_store_key" {
  description             = "KMS key for cross-account encryption of Parameter Store backups."
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms_key_policy.json
}

resource "aws_kms_alias" "parameter_store_alias" {
  name          = "alias/parameter-store-backup-key"
  target_key_id = aws_kms_key.parameter_store_key.key_id
}

output "parameter_store_kms_key_arn" {
  description = "The ARN of the KMS key created in the backup account."
  value       = aws_kms_key.parameter_store_key.arn
}
