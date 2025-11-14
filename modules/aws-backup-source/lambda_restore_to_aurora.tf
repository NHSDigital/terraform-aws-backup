data "archive_file" "lambda_restore_to_aurora_zip" {
  count       = var.lambda_restore_to_aurora_enable ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/resources/restore-to-aurora/"
  output_path = "${path.module}/.terraform/archive_files/lambda_restore_to_aurora.zip"
}

resource "aws_iam_role" "iam_for_lambda_restore_to_aurora" {
  count = var.lambda_restore_to_aurora_enable ? 1 : 0
  name  = "${var.name_prefix}-lambda-restore-to-aurora-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "iam_policy_for_lambda_restore_to_aurora" {
  count = var.lambda_restore_to_aurora_enable ? 1 : 0
  name  = "${var.name_prefix}-lambda-restore-to-aurora-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
        Effect   = "Allow"
      },
      {
        Action = ["backup:StartRestoreJob", "backup:DescribeRestoreJob"]
        Resource = "*"
        Effect   = "Allow"
      },
      {
        Action = "iam:PassRole"
        Resource = aws_iam_role.iam_for_lambda_restore_to_aurora[0].arn
        Condition = { StringEquals = { "iam:PassedToService" : "backup.amazonaws.com" } }
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_restore_to_aurora_policy_attach" {
  count      = var.lambda_restore_to_aurora_enable ? 1 : 0
  role       = aws_iam_role.iam_for_lambda_restore_to_aurora[0].name
  policy_arn = aws_iam_policy.iam_policy_for_lambda_restore_to_aurora[0].arn
}

resource "aws_lambda_function" "lambda_restore_to_aurora" {
  count            = var.lambda_restore_to_aurora_enable ? 1 : 0
  function_name    = "${var.name_prefix}_lambda-restore-to-aurora"
  role             = aws_iam_role.iam_for_lambda_restore_to_aurora[0].arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_restore_to_aurora_zip[0].output_path
  source_code_hash = data.archive_file.lambda_restore_to_aurora_zip[0].output_base64sha256
  timeout          = var.lambda_restore_to_aurora_max_wait_minutes * 60
  environment {
    variables = {
      POLL_INTERVAL_SECONDS = var.lambda_restore_to_aurora_poll_interval_seconds
      MAX_WAIT_MINUTES      = var.lambda_restore_to_aurora_max_wait_minutes
    }
  }
}
