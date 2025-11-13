data "aws_iam_policy_document" "lambda_parameter_store_assume_role" {
  count = var.backup_plan_config_parameter_store.enable ? 1 : 0
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "lambda_parameter_store_backup_permissions" {
  count = var.backup_plan_config_parameter_store.enable ? 1 : 0
  version = "2012-10-17"
  statement {
    effect    = "Allow"
    actions   = [
      "iam:PassRole"
    ]
    resources = [aws_iam_role.iam_for_lambda_parameter_store_backup[0].arn]
  }

  statement {
    effect    = "Allow"
    actions   = [
      "ssm:DescribeParameters",
      "ssm:GetParametersByPath",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:ListTagsForResource"
    ]
    resources = ["arn:aws:ssm:*:*:*"]
  }

  statement {
    effect  = "Allow"
    actions   = [
      "tag:GetResources",
    ]
    resources = ["*"]
  }

  statement {
    effect  = "Allow"
    actions   = [
      "kms:Encrypt",
    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:ListBucket"
    ]
    resources = [
      "${aws_s3_bucket.parameter_store_backup_storage[0].arn}",
      "${aws_s3_bucket.parameter_store_backup_storage[0].arn}/*"
    ]
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

data "archive_file" "lambda_parameter_store_backup_zip" {
  count       = var.backup_plan_config_parameter_store.enable ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/resources/parameter-store-backup/"
  output_path = "${path.module}/.terraform/archive_files/lambda_parameter_store_backup.zip"
}


resource "aws_s3_bucket" "parameter_store_backup_storage" {
  count = var.backup_plan_config_parameter_store.enable ? 1 : 0
  bucket = "${local.resource_name_prefix}-parameter-store-backup"

  tags = {
    Environment                                               = var.environment_name
    Application                                               = var.project_name
    Name                                                      = "${local.resource_name_prefix}-parameter-store-backup"
    "${var.backup_plan_config_parameter_store.selection_tag}" = var.backup_plan_config_parameter_store.selection_tag_value != null ? var.backup_plan_config_parameter_store.selection_tag_value : "True"
  }

}

resource "aws_s3_bucket_versioning" "parameter_store_backup_versioning" {
  count  = var.backup_plan_config_parameter_store.enable ? 1 : 0
  bucket = aws_s3_bucket.parameter_store_backup_storage[count.index].id

  versioning_configuration {
    status = "Enabled"
  }
}

# The IAM role name is fixed as it is referenced in the KMS key policy in the backup destination account.
resource "aws_iam_role" "iam_for_lambda_parameter_store_backup" {
  count = var.backup_plan_config_parameter_store.enable ? 1 : 0
  name               = "parameter_store_lambda_encryption_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_parameter_store_assume_role[0].json
}

resource "aws_iam_role_policy" "lambda_parameter_store_backup_iam_permissions" {
  count  = var.backup_plan_config_parameter_store.enable ? 1 : 0
  name   = "${local.resource_name_prefix}_lambda_parameter_store_backup_iam_permissions_policy"
  role   = aws_iam_role.iam_for_lambda_parameter_store_backup[0].id
  policy = data.aws_iam_policy_document.lambda_parameter_store_backup_permissions[0].json
}

resource "aws_lambda_function" "lambda_parameter_store_backup" {
  count            = var.backup_plan_config_parameter_store.enable ? 1 : 0
  filename         = data.archive_file.lambda_parameter_store_backup_zip[0].output_path
  source_code_hash = data.archive_file.lambda_parameter_store_backup_zip[0].output_base64sha256
  function_name    = "${local.resource_name_prefix}-parameter_store_backup"
  role             = aws_iam_role.iam_for_lambda_parameter_store_backup[0].arn
  handler          = "parameter_store_backup.lambda_handler"
  runtime          = "python3.12"
  timeout          = var.backup_plan_config_parameter_store.lambda_timeout_seconds
  environment {
    variables = {
      KMS_KEY_ARN                 = var.destination_parameter_store_kms_key_arn
      PARAMETER_STORE_BUCKET_NAME = aws_s3_bucket.parameter_store_backup_storage[0].bucket
      TAG_KEY                     = var.backup_plan_config_parameter_store.selection_tag
      TAG_VALUE                   = var.backup_plan_config_parameter_store.selection_tag_value != null ? var.backup_plan_config_parameter_store.selection_tag_value : "True"
    }
  }
}

resource "aws_cloudwatch_event_rule" "aws_backup_parameter_store_event_rule" {
  count = var.backup_plan_config_parameter_store.enable ? 1 : 0
  name        = "${local.resource_name_prefix}-parameter-store-backup-rule"
  description = "Triggers the Parameter Store Backup lambda."

  schedule_expression = "cron(${var.backup_plan_config_parameter_store.lambda_backup_cron})"
}

resource "aws_cloudwatch_event_target" "lambda_parameter_store_target" {
  count     = var.backup_plan_config_parameter_store.enable ? 1 : 0
  rule      = aws_cloudwatch_event_rule.aws_backup_parameter_store_event_rule[0].name
  arn       = aws_lambda_function.lambda_parameter_store_backup[0].arn
  target_id = "${local.resource_name_prefix}parameterStoreBackupLambdaTarget"
}

resource "aws_lambda_permission" "lambda_parameter_store_allow_eventbridge" {
  count         = var.backup_plan_config_parameter_store.enable ? 1 : 0
  statement_id  = "${local.resource_name_prefix}AllowExecutionFromEventbridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_parameter_store_backup[0].function_name
  principal     = "events.amazonaws.com"

  source_arn    = aws_cloudwatch_event_rule.aws_backup_parameter_store_event_rule[0].arn
}

resource "aws_cloudwatch_log_group" "parameter_store_backup" {
  count             = var.backup_plan_config_parameter_store.enable ? 1 : 0
  name              = "/aws/lambda/${local.resource_name_prefix}-parameter-store-backup"
  retention_in_days = 30
}
