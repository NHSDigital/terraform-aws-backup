variable "enable" {
  type        = bool
  default     = true
  description = "Whether to create manual validation orchestration resources."
}

variable "name_prefix" {
  type        = string
  description = "Prefix used for naming resources (e.g. project-env)."
}

variable "backup_vault_name" {
  type        = string
  description = "Name of the backup vault containing recovery points to restore for manual tests."
}

variable "restore_role_arn" {
  type        = string
  description = "IAM role ARN used by the restore job if a specific role is required (optional)."
  default     = null
}

variable "validation_lambda_arn" {
  type        = string
  description = "Customer-provided Lambda ARN that performs validation after manual restore completes."
}

variable "resource_type" {
  type        = string
  description = "AWS Backup resource type for manual restore (e.g. S3, DynamoDB, RDS)."
}

variable "target_bucket_name" {
  type        = string
  description = "For S3 restores: name of the destination S3 bucket that the restore will produce or populate. Used only in the example orchestrator logic."
  default     = null
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to created resources."
}
