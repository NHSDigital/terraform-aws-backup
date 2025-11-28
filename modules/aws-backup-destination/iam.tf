#############################################
# Cross-account role for copy-recovery-point
# Created only when enable_cross_account_vault_access = true
#############################################

locals {
  copy_recovery_role_name = coalesce(var.name_prefix, "") != "" ? "${var.name_prefix}-copy-recovery-point" : "copy-recovery-point"
}

data "aws_iam_policy_document" "copy_recovery_point_assume" {
  count = var.enable_cross_account_vault_access ? 1 : 0

  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.source_account_id}:root"]
    }
    actions = ["sts:AssumeRole"]
  }

  # Allow AWS Backup service to assume when executing StartCopyJob in this account
  statement {
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "backup.amazonaws.com",
        "rds.amazonaws.com"
      ]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "copy_recovery_point" {
  count              = var.enable_cross_account_vault_access ? 1 : 0
  name               = local.copy_recovery_role_name
  assume_role_policy = data.aws_iam_policy_document.copy_recovery_point_assume[0].json
  description        = "Role assumed by source account lambda to start and describe AWS Backup copy jobs, also passed to AWS Backup service for execution"
  tags = {
    ModuleComponent = "aws-backup-destination"
    Purpose         = "copy-recovery-point-cross-account"
  }
}

data "aws_iam_policy_document" "copy_recovery_point_permissions" {
  count = var.enable_cross_account_vault_access ? 1 : 0

  # Start copy job (resource-level supports recoveryPoint*)
  statement {
    effect = "Allow"
    actions = [
      "backup:StartCopyJob"
    ]
    # Recovery points originate from the source account; allow any recovery point ARN pattern for that account & any region used via var.region
    resources = ["arn:aws:backup:${var.region}:${var.account_id}:recovery-point:*"]
  }

  # Describe copy job (no resource-level restriction)
  statement {
    sid    = "BackupServicePermissions"
    effect = "Allow"
    actions = [
      "backup:StartCopyJob",
      "backup:CopyIntoBackupVault",
      "backup:DescribeCopyJob",
      "backup:DescribeBackupVault",
      "backup:DescribeRecoveryPoint",
      "backup:DescribeBackupJob",
      "backup:GetBackupVaultAccessPolicy",
      "backup:StopBackupJob",
      "backup:ListRecoveryPointsByBackupVault",
      "backup:ListCopyJobs",
      "backup:GetRecoveryPointRestoreMetadata",
      "backup:UpdateRecoveryPointLifecycle",
      "backup:PutBackupVaultAccessPolicy",
      "backup:ListRecoveryPointsByResource",
      "backup:GetBackupPlan",
      "backup:ListBackupJobs",
      "backup:TagResource",
      "backup:UntagResource",
      "backup:ListTags",
      "backup:ListBackupVaults",
      "backup:CreateBackupVault",
      "backup:GetBackupVaultNotifications",
      "backup:PutBackupVaultNotifications",
      "backup:DescribeProtectedResource",
      "backup:ListProtectedResources"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CopyBackupPermissions"
    effect = "Allow"
    actions = [
      "backup:CopyIntoBackupVault",
      "backup:CopyFromBackupVault"
    ]
    resources = [
      "arn:aws:backup:${var.region}:${var.account_id}:recovery-point:*",
      "arn:aws:backup:${var.region}:${var.account_id}:backup-vault:${aws_backup_vault.vault.name}",
      "arn:aws:backup:${var.region}:${var.source_account_id}:backup-vault:*",
      "arn:aws:rds:${var.region}:${var.account_id}:*",
      "arn:aws:rds:${var.region}:${var.source_account_id}:*",
      "arn:aws:s3:${var.region}:${var.account_id}:*",
      "arn:aws:s3:${var.region}:${var.source_account_id}:*",
      "arn:aws:dynamodb:${var.region}:${var.account_id}:table/*",
      "arn:aws:dynamodb:${var.region}:${var.source_account_id}:table/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:volume/*",
      "arn:aws:ec2:${var.region}:${var.source_account_id}:volume/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:snapshot/*",
      "arn:aws:ec2:${var.region}:${var.source_account_id}:snapshot/*",
      "arn:aws:efs:${var.region}:${var.account_id}:file-system/*",
      "arn:aws:efs:${var.region}:${var.source_account_id}:file-system/*"
    ]
  }

  statement {
    sid    = "RDSPermissions"
    effect = "Allow"
    actions = [
      "rds:CopyDBSnapshot",
      "rds:DescribeDBSnapshots",
      "rds:ModifyDBSnapshotAttribute",
      "rds:DescribeDBInstances",
      "rds:DescribeDBClusters",
      "rds:CopyDBClusterSnapshot",
      "rds:DescribeDBClusterSnapshots",
      "rds:AddTagsToResource",
      "rds:ListTagsForResource"
    ]
    resources = [
      "arn:aws:rds:${var.region}:${var.account_id}:db:*",
      "arn:aws:rds:${var.region}:${var.account_id}:snapshot:*",
      "arn:aws:rds:${var.region}:${var.account_id}:cluster:*",
      "arn:aws:rds:${var.region}:${var.account_id}:cluster-snapshot:*",
      "arn:aws:rds:${var.region}:${var.source_account_id}:db:*",
      "arn:aws:rds:${var.region}:${var.source_account_id}:snapshot:*",
      "arn:aws:rds:${var.region}:${var.source_account_id}:cluster:*",
      "arn:aws:rds:${var.region}:${var.source_account_id}:cluster-snapshot:*"
    ]
  }

  statement {
    sid    = "BackupTagPermissions"
    effect = "Allow"
    actions = [
      "backup:TagResource"
    ]
    resources = [
      "arn:aws:backup:${var.region}:${var.account_id}:recovery-point:*"
    ]
  }

  statement {
    sid    = "KMSPermissions"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant",
      "kms:RetireGrant",
      "kms:ListGrants"
    ]
    resources = [
      "arn:aws:kms:${var.region}:${var.account_id}:key/*"
    ]
  }

  # Pass this role to AWS Backup service when invoking StartCopyJob with IamRoleArn
  statement {
    sid       = "IAMPermissions"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.copy_recovery_point[0].arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "copy_recovery_point_policy" {
  count  = var.enable_cross_account_vault_access ? 1 : 0
  name   = "${local.copy_recovery_role_name}-policy"
  role   = aws_iam_role.copy_recovery_point[0].id
  policy = data.aws_iam_policy_document.copy_recovery_point_permissions[0].json
}

output "copy_recovery_point_role_arn" {
  description = "ARN of role to assume from source account lambda (set ASSUME_ROLE_ARN to this). Only present if enabled."
  value       = try(aws_iam_role.copy_recovery_point[0].arn, null)
  depends_on  = [aws_iam_role.copy_recovery_point]
}
