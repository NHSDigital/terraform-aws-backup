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
			type        = "Service"
			identifiers = ["backup.amazonaws.com"]
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

	statement {
		effect = "Allow"
		actions = ["backup:*"]
		resources = ["arn:aws:backup:${var.region}:${var.account_id}:recovery-point:*"]
	}

	statement {
		effect    = "Allow"
		actions   = ["backup:*"]
		resources = ["*"]
	}

	# Pass this role to AWS Backup service when invoking StartCopyJob with IamRoleArn
	statement {
		effect = "Allow"
		actions = ["iam:PassRole"]
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

