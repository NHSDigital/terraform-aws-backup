# make sure $AWS_PROFILE is set and you've done the `aws sso login` dance

variable "terraform_apply_role_name" {
  description = "The name of the role that terraform will assume to apply changes"
}

variable "app_name" {
  description = "The name of the application"
}

variable "env" {
  description = "The name of the environment"
}

locals {
  prefix = "${var.app_name}-${var.env}"
}

resource "aws_iam_policy" "source_account_backup_permissions" {
  name = "${local.prefix}-source-account-backup-permissions"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "backup:ListBackupPlans",
          "backup:CreateBackupPlan",
          "backup:DeleteBackupPlan",
          "backup:DescribeBackupPlan",
          "backup:UpdateBackupPlan",
          "backup:GetBackupPlan",
          "backup:CreateReportPlan",
          "backup:DeleteReportPlan",
          "backup:DescribeReportPlan",
          "backup:UpdateReportPlan",
          "backup:ListReportPlans",
          "backup:TagResource",
          "backup:ListTags",
          "backup:CreateFramework",
          "backup:DeleteFramework",
          "backup:DescribeFramework",
          "backup:ListFrameworks",
          "backup:CreateBackupVault",
          "backup:DeleteBackupVault",
          "backup:DescribeBackupVault",
          "backup:ListBackupVaults",
          "backup:PutBackupVaultAccessPolicy",
          "backup:GetBackupVaultAccessPolicy",
          "backup:CreateBackupSelection",
          "backup:GetBackupSelection",
          "backup:DeleteBackupSelection",
          "backup:CreateRestoreTestingPlan",
          "backup:DeleteRestoreTestingPlan",
          "backup:GetRestoreTestingPlan",
          "backup:ListRestoreTestingPlans",
          "backup:UpdateRestoreTestingPlan"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "backup-storage:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "kms:ListKeys",
          "kms:DescribeKey",
          "kms:DeleteKey",
          "kms:CreateKey",
          "kms:ListAliases",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:TagResource"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "source_account_backup_permissions" {
  policy_arn = aws_iam_policy.source_account_backup_permissions.arn
  role       = var.terraform_apply_role_name
}
