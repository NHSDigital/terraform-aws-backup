resource "aws_backup_vault" "main" {
  name        = "${local.resource_name_prefix}-vault"
  kms_key_arn = aws_kms_key.aws_backup_key.arn
}

resource "aws_backup_vault" "intermediary-vault" {
  name        = "${local.resource_name_prefix}-intermediary-vault"
  kms_key_arn = aws_kms_key.aws_backup_key.arn
}