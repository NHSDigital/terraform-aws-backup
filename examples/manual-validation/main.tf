terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" { type = string }
variable "name_prefix" { type = string }
variable "backup_vault_name" { type = string }
variable "restore_bucket" { type = string }

# Example customer validator lambda (upload dist bundle manually or integrate build pipeline).
resource "aws_lambda_function" "customer_validator" {
  function_name = "${var.name_prefix}-customer-s3-validator"
  role          = aws_iam_role.customer_validator.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = "./lambda_customer_validator.zip" # user supplied artifact
  source_code_hash = filebase64sha256("./lambda_customer_validator.zip")
  timeout       = 60
  environment {
    variables = {}
  }
}

resource "aws_iam_role" "customer_validator" {
  name               = "${var.name_prefix}-customer-s3-validator-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["lambda.amazonaws.com"] }
  }
}

resource "aws_iam_role_policy_attachment" "logs_attach_customer" {
  role       = aws_iam_role.customer_validator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "customer_s3_policy" {
  name   = "${var.name_prefix}-customer-s3-validator-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:HeadObject"]
        Resource = [
          "arn:aws:s3:::${var.restore_bucket}",
          "arn:aws:s3:::${var.restore_bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "customer_validator_attach" {
  role       = aws_iam_role.customer_validator.name
  policy_arn = aws_iam_policy.customer_s3_policy.arn
}

module "manual_validation" {
  source                = "../../modules/aws-backup-manual-validation"
  enable                = true
  name_prefix           = var.name_prefix
  backup_vault_name     = var.backup_vault_name
  resource_type         = "S3"
  validation_lambda_arn = aws_lambda_function.customer_validator.arn
  target_bucket_name    = var.restore_bucket
}

output "orchestrator_lambda" { value = module.manual_validation.orchestrator_lambda_arn }
