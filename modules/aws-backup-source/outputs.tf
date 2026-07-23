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

output "lambda_copy_recovery_point_to_s3_arn" {
  value       = try(aws_lambda_function.lambda_copy_recovery_point_to_s3[0].arn, null)
  description = "ARN of the of the lambda function to copy recovery point to s3. Lambda only created if lambda_copy_recovery_point_enable is true"
}

output "lambda_restore_to_s3_arn" {
  value       = try(aws_lambda_function.lambda_restore_to_s3[0].arn, null)
  description = "ARN of the of the lambda function to restore to s3. Lambda only created if lambda_restore_to_s3_enable is true"
}
