locals {
  manual_validation_name = "${var.name_prefix}-manual-restore-validation"
}

resource "aws_iam_role" "orchestrator" {
  count = var.enable ? 1 : 0
  name               = "${local.manual_validation_name}-orchestrator"
  assume_role_policy = data.aws_iam_policy_document.orchestrator_assume.json
}

data "aws_iam_policy_document" "orchestrator_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# NOTE: Permissions are intentionally broad placeholders; should be tightened.
# Includes: listing recovery points, starting restore job, describing restore job,
# invoking customer validation Lambda, writing logs, optional S3 read.

data "aws_iam_policy_document" "orchestrator" {
  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    sid = "BackupCore"
    actions = [
      "backup:ListRecoveryPointsByBackupVault",
      "backup:StartRestoreJob",
      "backup:DescribeRestoreJob",
      "backup:PutRestoreValidationResult"
    ]
    resources = ["*"]
  }

  statement {
    sid = "InvokeValidator"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [var.validation_lambda_arn]
  }

  statement {
    sid = "S3ReadOptional"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:HeadObject"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "orchestrator" {
  count  = var.enable ? 1 : 0
  name   = "${local.manual_validation_name}-policy"
  policy = data.aws_iam_policy_document.orchestrator.json
}

resource "aws_iam_role_policy_attachment" "orchestrator" {
  count      = var.enable ? 1 : 0
  role       = aws_iam_role.orchestrator[0].name
  policy_arn = aws_iam_policy.orchestrator[0].arn
}
