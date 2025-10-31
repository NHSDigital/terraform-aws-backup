locals {
  validator_lambda_name = "${var.name_prefix}-validator"
  state_machine_name    = "${var.name_prefix}-state-machine"
  ssm_param_name        = "/${var.name_prefix}/config"
}

resource "aws_iam_role" "validator_lambda" {
  name               = "${local.validator_lambda_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect = "Allow"
    principals { type = "Service" identifiers = ["lambda.amazonaws.com"] }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "validator_basic" {
  name = "${local.validator_lambda_name}-basic"
  role = aws_iam_role.validator_lambda.id
  policy = data.aws_iam_policy_document.validator_policy.json
}

data "aws_iam_policy_document" "validator_policy" {
  statement {
    sid     = "Logs"
    effect  = "Allow"
    actions = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*" ]
  }
  statement {
    sid     = "DescribeRestoreJob"
    effect  = "Allow"
    actions = ["backup:DescribeRestoreJob", "backup:PutRestoreValidationResult"]
    resources = ["*"]
  }
  statement {
    sid     = "GetConfig"
    effect  = "Allow"
    actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParameterHistory"]
    resources = ["arn:aws:ssm:*:*:parameter${local.ssm_param_name}"]
  }
  # Add minimal read for services (extend if needed by resource type validators)
  statement {
    sid     = "RDSData"
    effect  = "Allow"
    actions = ["rds-data:ExecuteStatement"]
    resources = ["*"]
  }
  statement {
    sid     = "DynamoRead"
    effect  = "Allow"
    actions = ["dynamodb:DescribeTable", "dynamodb:GetItem"]
    resources = ["*"]
  }
  statement {
    sid     = "S3Head"
    effect  = "Allow"
    actions = ["s3:HeadObject", "s3:GetObject"]
    resources = ["*"]
  }
  statement {
    sid     = "SecretsRead"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "state_machine" {
  name               = "${local.state_machine_name}-role"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "sfn_assume" {
  statement {
    effect = "Allow"
    principals { type = "Service" identifiers = ["states.amazonaws.com"] }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "state_machine_policy" {
  name = "${local.state_machine_name}-policy"
  role = aws_iam_role.state_machine.id
  policy = data.aws_iam_policy_document.state_machine_policy.json
}

data "aws_iam_policy_document" "state_machine_policy" {
  statement {
    sid     = "InvokeValidator"
    effect  = "Allow"
    actions = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.validator.arn]
  }
  statement {
    sid     = "BackupCalls"
    effect  = "Allow"
    actions = ["backup:DescribeRestoreJob", "backup:PutRestoreValidationResult"]
    resources = ["*"]
  }
  statement {
    sid     = "Logs"
    effect  = "Allow"
    actions = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*" ]
  }
}
