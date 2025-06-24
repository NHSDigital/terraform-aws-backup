data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda_copy_job" {
  count              = var.backup_plan_config_rds.enable ? 1 : 0
  name               = "iam_for_cross_account_copy_job_lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_copy_job_permissions" {
  version = "2012-10-17"
  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.aws_backup_key.arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "backup:StartCopyJob",
      "backup:DescribeRecoveryPoint",
      "backup:ListRecoveryPointsByBackupVault"
    ]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.backup.arn]
  }
}

resource "aws_iam_role_policy_attachment" "lambda_role_policy_attachment" {
  count      = var.backup_plan_config_rds.enable ? 1 : 0
  role       = aws_iam_role.iam_for_lambda_copy_job[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "cross_account_iam_permissions" {
  count  = var.backup_plan_config_rds.enable ? 1 : 0
  name   = "cross_account_iam_permissions_policy"
  role   = aws_iam_role.iam_for_lambda_copy_job[0].id
  policy = data.aws_iam_policy_document.lambda_copy_job_permissions.json
}

data "archive_file" "start_cross_account_copy_job_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/resources"
  output_path = "${path.module}/.terraform/archive_files/start_cross_account_copy_job_lambda.zip"
}

resource "aws_lambda_function" "start_cross_account_copy_job_lambda" {
  count            = var.backup_plan_config_rds.enable ? 1 : 0
  filename         = data.archive_file.start_cross_account_copy_job_lambda_zip.output_path
  source_code_hash = data.archive_file.start_cross_account_copy_job_lambda_zip.output_base64sha256
  function_name    = "start_cross_account_copy_job"
  role             = aws_iam_role.iam_for_lambda_copy_job[0].arn
  handler          = "start_cross_account_copy_job.lambda_handler"
  runtime          = "python3.12"
  environment {
    variables = {
      aws_account_id                     = data.aws_caller_identity.current.account_id,
      backup_account_id                  = var.backup_copy_vault_account_id,
      backup_copy_vault_arn              = var.backup_copy_vault_arn,
      backup_role_arn                    = aws_iam_role.backup.arn,
      destination_vault_retention_period = var.destination_vault_retention_period
    }
  }
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count       = var.backup_plan_config_rds.enable ? 1 : 0
  statement_id  = "AllowExecutionFromEventbridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_cross_account_copy_job_lambda[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = "arn:aws:events:eu-west-2:${data.aws_caller_identity.current.account_id}:rule/Cross-Account-Copy-Job-rule"
}
