data "archive_file" "validator_zip" {
  type        = "zip"
  source_file = "${path.module}/dist/index.js"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_ssm_parameter" "config" {
  name  = local.ssm_param_name
  type  = "String"
  value = var.validation_config_json
  tags  = var.tags
}

resource "aws_lambda_function" "validator" {
  function_name    = local.validator_lambda_name
  role             = aws_iam_role.validator_lambda.arn
  runtime          = var.lambda_runtime
  handler          = "index.handler"
  filename         = data.archive_file.validator_zip.output_path
  source_code_hash = data.archive_file.validator_zip.output_base64sha256
  timeout          = var.lambda_timeout
  environment {
    variables = {
      CONFIG_PARAM_NAME = aws_ssm_parameter.config.name
    }
  }
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "validator" {
  name              = "/aws/lambda/${aws_lambda_function.validator.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}
