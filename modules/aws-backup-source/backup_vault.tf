resource "aws_backup_vault" "main" {
  count = var.resources_in_same_account == "" ? 1 : 0

  name        = "${local.resource_name_prefix}-vault"
  kms_key_arn = aws_kms_key.aws_backup_key.arn
}

moved {
  from = aws_backup_vault.main
  to   = aws_backup_vault.main[0]
}
