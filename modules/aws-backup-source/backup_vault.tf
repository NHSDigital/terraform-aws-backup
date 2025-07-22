resource "aws_backup_vault" "main" {
  name        = "${var.name_prefix}-vault"
  kms_key_arn = aws_kms_key.aws_backup_key.arn
}

resource "aws_backup_vault" "intermediary-vault" {
  count       = var.backup_plan_config_rds.enable ? 1 : 0
  name        = "${var.name_prefix}-intermediary-vault"
  kms_key_arn = aws_kms_key.aws_backup_key.arn
}
