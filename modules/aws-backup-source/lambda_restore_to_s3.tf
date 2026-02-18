data "archive_file" "lambda_restore_to_s3_zip" {
  count       = var.lambda_restore_to_s3_enable ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/resources/restore-to-s3/"
  output_path = "${path.module}/.terraform/archive_files/lambda_restore_to_s3.zip"
}


resource "aws_iam_role" "iam_for_lambda_restore_to_s3" {
  count = var.lambda_restore_to_s3_enable ? 1 : 0
  name  = "${local.resource_name_prefix}-lambda-restore-to-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}


resource "aws_iam_policy" "iam_policy_for_lambda_restore_to_s3" {
  count = var.lambda_restore_to_s3_enable ? 1 : 0
  name  = "${local.resource_name_prefix}-lambda-restore-to-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
        Effect   = "Allow"
      },
      {
        Action = [
          "backup:StartRestoreJob",
          "backup:DescribeRestoreJob"
        ]
        Resource = "*"
        Effect   = "Allow"
      },
      {
        Action = "iam:PassRole"
        Resource = aws_iam_role.backup.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" : "backup.amazonaws.com"
          }
        }
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_restore_to_s3_policy_attach" {
  count      = var.lambda_restore_to_s3_enable ? 1 : 0
  role       = aws_iam_role.iam_for_lambda_restore_to_s3[0].name
  policy_arn = aws_iam_policy.iam_policy_for_lambda_restore_to_s3[0].arn
}


resource "aws_lambda_function" "lambda_restore_to_s3" {
  count            = var.lambda_restore_to_s3_enable ? 1 : 0
  function_name    = "${local.resource_name_prefix}_lambda-restore-to-s3"

  role             = aws_iam_role.iam_for_lambda_restore_to_s3[0].arn
  handler          = "restore_to_s3.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_restore_to_s3_zip[0].output_path
  source_code_hash = data.archive_file.lambda_restore_to_s3_zip[0].output_base64sha256
  timeout          = var.lambda_restore_to_s3_max_wait_minutes * 60

  environment {
    variables = {
      POLL_INTERVAL_SECONDS = var.lambda_restore_to_s3_poll_interval_seconds
      MAX_WAIT_MINUTES      = var.lambda_restore_to_s3_max_wait_minutes
      IAM_ROLE_ARN         = aws_iam_role.backup.arn
    }
  }
}
