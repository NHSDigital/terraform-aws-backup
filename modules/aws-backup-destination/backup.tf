resource "aws_backup_vault" "vault" {
  count = var.resources_in_same_account ? 1 : 0

  name        = var.name_prefix != null ? "${var.name_prefix}-backup-vault" : "${var.source_account_name}-backup-vault"
  kms_key_arn = var.kms_key
}

output "vault_arn" {
  value = var.resources_in_same_account ? aws_backup_vault.vault[0].arn : null
}

output "vault_name" {
  description = "The name of the backup vault."
  value       = var.resources_in_same_account ? aws_backup_vault.vault[0].name : null
}

# -----

moved {
  from = aws_backup_vault.vault
  to   = aws_backup_vault.vault[0]
}
