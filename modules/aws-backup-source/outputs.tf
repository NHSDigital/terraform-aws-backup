output "backup_role_arn" {
  value       = aws_iam_role.backup.arn
  description = "ARN of the of the backup role"
}

output "backup_vault_arn" {
  value       = aws_backup_vault.main.arn
  description = "ARN of the of the Backup Vault"
}

output "backup_vault_name" {
  value       = aws_backup_vault.main.name
  description = "Name of the of the Backup Vault"
}

output "backup_vault_lag_arn" {
  value       = var.enable_logically_air_gapped_vault ? aws_backup_logically_air_gapped_vault.main[0].arn : null
  description = "ARN of the of the Logically Air-gapped Vault"
}

output "backup_vault_lag_name" {
  value       = var.enable_logically_air_gapped_vault ? aws_backup_logically_air_gapped_vault.main[0].name : null
  description = "Name of the of the Logically Air-gapped Vault"
}
