resource "aws_backup_vault" "vault" {
  name        = var.name_prefix != null ? "${var.name_prefix}-backup-vault" : "${var.source_account_name}-backup-vault"
  kms_key_arn = var.kms_key
}

output "vault_arn" {
  value = aws_backup_vault.vault.arn
}

output "vault_name" {
  description = "The name of the backup vault."
  value       = aws_backup_vault.vault.name
}
