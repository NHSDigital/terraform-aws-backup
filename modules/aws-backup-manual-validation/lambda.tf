locals {
  orchestrator_src_dir = "${path.module}/src"
}

resource "aws_cloudwatch_log_group" "orchestrator" {
  count             = var.enable ? 1 : 0
  name              = "/aws/lambda/${aws_lambda_function.orchestrator[0].function_name}"
  retention_in_days = 30
}

# We keep a pre-built JS file for simplicity; user can rebuild if modifying.
# (If a build step is desired, integrate external build pipeline.)

data "archive_file" "orchestrator" {
  type        = "zip"
  source_file = "${path.module}/dist/orchestrator.js"
  output_path = "${path.module}/dist/orchestrator.zip"
}

resource "aws_lambda_function" "orchestrator" {
  count         = var.enable ? 1 : 0
  function_name = "${var.name_prefix}-manual-restore-orchestrator"
  role          = aws_iam_role.orchestrator[0].arn
  handler       = "orchestrator.handler"
  runtime       = "nodejs20.x"
  filename      = data.archive_file.orchestrator.output_path
  source_code_hash = data.archive_file.orchestrator.output_base64sha256
  timeout       = 900
  memory_size   = 256

  environment {
    variables = {
      BACKUP_VAULT_NAME = var.backup_vault_name
      RESOURCE_TYPE     = var.resource_type
      VALIDATOR_LAMBDA  = var.validation_lambda_arn
      TARGET_BUCKET     = var.target_bucket_name
    }
  }
  tags = var.tags
}

output "manual_restore_orchestrator_lambda_arn" {
  value       = try(aws_lambda_function.orchestrator[0].arn, null)
  description = "ARN of the manual restore orchestrator lambda"
}
