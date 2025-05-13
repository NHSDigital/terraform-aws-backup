output "backup_role_arn" {
  value       = aws_iam_role.backup.arn
  description = "ARN of the of the backup role"
}

output "backup_vault_arn" {
  value       = aws_backup_vault.main.arn
  description = "ARN of the of the vault"
}

output "backup_vault_name" {
  value       = aws_backup_vault.main.name
  description = "Name of the of the vault"
}
