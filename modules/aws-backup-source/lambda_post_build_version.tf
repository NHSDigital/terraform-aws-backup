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

resource "aws_iam_role" "iam_for_lambda_post_build_version" {
  name               = "iam_for_lambda_post_build_version"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_post_build_version_permissions" {
  version = "2012-10-17"
  # NOTE: aws_iam_role.backup is assumed to be defined elsewhere.
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.backup.arn]
  }
}

resource "aws_iam_role_policy" "lambda_post_build_version_iam_permissions" {
  name   = "lambda_post_build_version_iam_permissions_policy"
  role   = aws_iam_role.iam_for_lambda_post_build_version.id
  policy = data.aws_iam_policy_document.lambda_post_build_version_permissions.json
}

data "archive_file" "lambda_post_build_version_zip" {
  type        = "zip"
  source_dir  = "${path.module}/resources/post_build_version/"
  output_path = "${path.module}/.terraform/archive_files/lambda_post_build_version.zip"
}

resource "aws_lambda_function" "lambda_post_build_version" {
  filename         = data.archive_file.lambda_post_build_version_zip.output_path
  source_code_hash = data.archive_file.lambda_post_build_version_zip.output_base64sha256
  function_name    = "post_build_version"
  role             = aws_iam_role.iam_for_lambda_post_build_version.arn
  handler          = "post_build_version.lambda_handler"
  runtime          = "python3.12"
  environment {
    variables = {
      AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
      MODULE_VERSION = var.module_version
      API_ENDPOINT   = var.api_endpoint
    }
  }
}

resource "aws_cloudwatch_event_rule" "aws_backup_event_rule" {
  name        = "post-build-version-rule"
  description = "Triggers the lambda on successful AWS Backup job completion."

  event_pattern = jsonencode({
    "source": ["aws.backup"],
    "detail-type": ["AWS Backup Job State Change"],
    "detail": {
      "state": ["COMPLETED"]
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.aws_backup_event_rule.name
  arn       = aws_lambda_function.lambda_post_build_version.arn
  target_id = "postBuildVersionLambdaTarget"
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventbridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_post_build_version.function_name
  principal     = "events.amazonaws.com"

  source_arn    = aws_cloudwatch_event_rule.aws_backup_event_rule.arn
}
