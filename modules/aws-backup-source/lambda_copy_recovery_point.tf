data "archive_file" "lambda_copy_recovery_point_zip" {
  count       = var.lambda_copy_recovery_point_enable ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/resources/copy-recovery-point/"
  output_path = "${path.module}/.terraform/archive_files/lambda_copy_recovery_point.zip"
}

resource "aws_iam_role" "iam_for_lambda_copy_recovery_point" {
  count = var.lambda_copy_recovery_point_enable ? 1 : 0
  name  = "${local.resource_name_prefix}-lambda-copy-recovery-point-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "iam_policy_for_lambda_copy_recovery_point" {
  count = var.lambda_copy_recovery_point_enable ? 1 : 0
  name  = "${local.resource_name_prefix}-lambda-copy-recovery-point-policy"

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
          "backup:StartCopyJob",
          "backup:DescribeCopyJob",
          "backup:ListRecoveryPointsByBackupVault"
        ]
        Resource = "*"
        Effect   = "Allow"
      },
      {
        Action   = ["sts:AssumeRole"]
        Resource = var.lambda_copy_recovery_point_assume_role_arn == "" ? null : var.lambda_copy_recovery_point_assume_role_arn
        Effect    = var.lambda_copy_recovery_point_assume_role_arn == "" ? "Allow" : "Allow"
        Condition = var.lambda_copy_recovery_point_assume_role_arn == "" ? null : { StringEquals = { "aws:PrincipalArn" = var.lambda_copy_recovery_point_assume_role_arn } }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_copy_recovery_point_policy_attach" {
  count      = var.lambda_copy_recovery_point_enable ? 1 : 0
  role       = aws_iam_role.iam_for_lambda_copy_recovery_point[0].name
  policy_arn = aws_iam_policy.iam_policy_for_lambda_copy_recovery_point[0].arn
}

resource "aws_lambda_function" "lambda_copy_recovery_point" {
  count            = var.lambda_copy_recovery_point_enable ? 1 : 0
  function_name    = "${local.resource_name_prefix}_lambda-copy-recovery-point"
  role             = aws_iam_role.iam_for_lambda_copy_recovery_point[0].arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_copy_recovery_point_zip.output_path
  source_code_hash = data.archive_file.lambda_copy_recovery_point_zip.output_base64sha256
  timeout          = var.lambda_copy_recovery_point_max_wait_minutes * 60

  environment {
    variables = {
      POLL_INTERVAL_SECONDS       = var.lambda_copy_recovery_point_poll_interval_seconds
      MAX_WAIT_MINUTES            = var.lambda_copy_recovery_point_max_wait_minutes
      DESTINATION_VAULT_ARN       = var.lambda_copy_recovery_point_destination_vault_arn != "" ? var.lambda_copy_recovery_point_destination_vault_arn : var.backup_copy_vault_arn
      SOURCE_VAULT_ARN            = var.lambda_copy_recovery_point_source_vault_arn != "" ? var.lambda_copy_recovery_point_source_vault_arn : aws_backup_vault.main.arn
      ASSUME_ROLE_ARN             = var.lambda_copy_recovery_point_assume_role_arn
    }
  }
}
