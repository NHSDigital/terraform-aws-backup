output "backup_role_arn" {
  value       = aws_iam_role.backup.arn
  description = "ARN of the of the backup role"
}

output "backup_vault_arn" {
  value       =  var.resources_in_same_account == "" ? aws_backup_vault.main[0].arn : null
  description = "ARN of the of the vault"
}

output "backup_vault_name" {
  value       = var.resources_in_same_account == "" ? aws_backup_vault.main[0].name : null
  description = "Name of the of the vault"
}
