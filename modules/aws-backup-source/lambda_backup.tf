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

resource "aws_iam_role" "iam_for_lambda_parameter_store_backup" {
  name               = "${var.name_prefix}_iam_for_lambda_parameter_store_backup"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_parameter_store_backup_permissions" {
  version = "2012-10-17"
  statement {
    effect    = "Allow"
    actions   = [
      "iam:PassRole"
    ]
    resources = [aws_iam_role.backup.arn]
  }

  statement {
    effect    = "Allow"
    actions   = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "lambda_parameter_store_backup_iam_permissions" {
  name   = "${var.name_prefix}_lambda_parameter_store_backup_iam_permissions_policy"
  role   = aws_iam_role.iam_for_lambda_parameter_store_backup.id
  policy = data.aws_iam_policy_document.lambda_post_build_version_permissions.json
}

data "archive_file" "lambda_parameter_store_backup_zip" {
  type        = "zip"
  source_dir  = "${path.module}/resources/parameter_store_backup/"
  output_path = "${path.module}/.terraform/archive_files/lambda_parameter_store_backup.zip"
}

resource "aws_lambda_function" "lambda_parameter_store_backup" {
  filename         = data.archive_file.lambda_parameter_store_backup_zip.output_path
  source_code_hash = data.archive_file.lambda_parameter_store_backup_zip.output_base64sha256
  function_name    = "${var.name_prefix}-parameter_store_backup"
  role             = aws_iam_role.iam_for_lambda_parameter_store_backup.arn
  handler          = "parameter_store_backup.lambda_handler"
  runtime          = "python3.12"
  environment {
    variables = {
    }
  }
}

resource "aws_cloudwatch_event_rule" "aws_backup_event_rule" {
  name        = "${var.name_prefix}-parameter-store-backup-rule"
  description = "Triggers the ECR Backup lambda."

  schedule_expression = "cron(${var.parameter_store_lambda_backup_cron})"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.aws_backup_event_rule.name
  arn       = aws_lambda_function.lambda_post_build_version.arn
  target_id = "${var.name_prefix}parameterStoreBackupLambdaTarget"
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "${var.name_prefix}AllowExecutionFromEventbridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_parameter_store_backup.function_name
  principal     = "events.amazonaws.com"

  source_arn    = aws_cloudwatch_event_rule.aws_backup_event_rule.arn
}

resource "aws_cloudwatch_log_group" "parameter_store_backup" {
  name              = "/aws/lambda/${var.name_prefix}-parameter-store-backup"
  retention_in_days = 30
}
