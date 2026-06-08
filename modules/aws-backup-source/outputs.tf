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

output "backup_sns_topic_arn" {
  value       = local.enable_sns_notifications ? aws_sns_topic.backup[0].arn : null
  description = "ARN of SNS topic to which the Backup events are being send to"
}

