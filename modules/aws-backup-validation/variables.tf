variable "enable" {
  description = "Whether to deploy restore validation components."
  type        = bool
  default     = true
}

variable "name_prefix" {
  description = "Prefix for created resources (state machine, lambda, etc)."
  type        = string
  default     = "backup-restore-validation"
}

variable "restore_testing_plan_arn" {
  description = "ARN of the AWS Backup Restore Testing Plan to filter events."
  type        = string
}

variable "resource_types" {
  description = "List of resource types we will attempt to validate (e.g. [\"RDS\", \"Aurora\", \"DynamoDB\", \"S3\"])."
  type        = list(string)
  default     = []
}

variable "validation_config_json" {
  description = "Raw JSON string of validation configuration to be stored in SSM Parameter for the Lambda validator."
  type        = string
  default     = "{}"
}

variable "lambda_runtime" {
  description = "Runtime for validator lambda."
  type        = string
  default     = "nodejs20.x"
}

variable "lambda_timeout" {
  description = "Timeout in seconds for validator lambda."
  type        = number
  default     = 60
}

variable "log_retention_days" {
  description = "CloudWatch log retention for validator lambda."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags to apply to created resources."
  type        = map(string)
  default     = {}
}
