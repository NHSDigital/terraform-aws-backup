resource "aws_backup_vault" "main" {
  name        = "${local.resource_name_prefix}-vault"
  kms_key_arn = aws_kms_key.aws_backup_key.arn
}

resource "aws_backup_logically_air_gapped_vault" "main" {
  count              = var.enable_logically_air_gapped_vault ? 1 : 0
  name               = "${local.resource_name_prefix}-lag-vault"
  min_retention_days = var.vault_lock_min_retention_days
  max_retention_days = var.vault_lock_max_retention_days
}
