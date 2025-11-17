data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "backup" {
  name                 = "${var.project_name}BackupRole"
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  permissions_boundary = length(var.iam_role_permissions_boundary) > 0 ? var.iam_role_permissions_boundary : null
}

resource "aws_iam_role_policy_attachment" "backup" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup.name
}

resource "aws_iam_role_policy_attachment" "restore" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role       = aws_iam_role.backup.name
}

resource "aws_iam_role_policy_attachment" "s3_restore" {
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Restore"
  role       = aws_iam_role.backup.name
}

resource "aws_iam_role_policy_attachment" "s3_backup" {
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup"
  role       = aws_iam_role.backup.name
}

# Cross-account copy permissions for AWS Backup service to write to destination vault
resource "aws_iam_role_policy" "backup_cross_account_copy" {
  name  = "${var.project_name}BackupCrossAccountCopyPolicy"
  role  = aws_iam_role.backup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "backup:CopyIntoBackupVault",
          "backup:DescribeRecoveryPoint",
          "backup:GetRecoveryPointRestoreMetadata",
          "backup:ListRecoveryPointsByBackupVault",
          "backup:StartCopyJob",
          "backup:ListBackupVaults",
          "backup:ListBackupJobs",
          "backup:ListCopyJobs",
          "backup:DescribeCopyJob"
        ]
        Resource = [
          var.backup_vault_arn, # Source vault
          var.backup_copy_vault_arn # Destination vault
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [
          var.kms_key_arn, # Source KMS key
          var.backup_copy_kms_key_arn # Destination KMS key
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = [
          var.kms_key_arn, # Source KMS key
          var.backup_copy_kms_key_arn # Destination KMS key
        ]
        Condition = {
          StringLike = {
            "kms:ViaService" = "backup.*.amazonaws.com"
          }
        }
      }
    ]
  })
}
