variable "project_name" {
  description = "The name of the project this relates to."
  type        = string
}

variable "environment_name" {
  description = "The name of the environment where AWS Backup is configured."
  type        = string
}

variable "notifications_target_email_address" {
  description = "The email address to which backup notifications will be sent via SNS."
  type        = string
  default     = ""
}

variable "bootstrap_kms_key_arn" {
  description = "The ARN of the bootstrap KMS key used for encryption at rest of the SNS topic."
  type        = string
}

variable "reports_bucket" {
  description = "Bucket to drop backup reports into"
  type        = string
}

variable "terraform_role_arn" {
  description = "ARN of Terraform role used to deploy to account (deprecated, please swap to terraform_role_arns)"
  type        = string
  default     = ""

  validation {
    condition     =  var.terraform_role_arn == ""
    error_message = "Warning: 'terraform_role_arn' is deprecated and should not be used."
  }
}

variable "terraform_role_arns" {
  description = "ARN of Terraform roles used to deploy to account, defaults to caller arn if list is empty"
  type        = list(string)
  default     = []
}

variable "deletion_allowed_principal_arns" {
  description = "List of ARNs of principals allowed to delete backups."
  type        = list(string)
  default     = null
  nullable    = true
}

variable "restore_testing_plan_algorithm" {
  description = "Algorithm of the Recovery Selection Point"
  type        = string
  default     = "LATEST_WITHIN_WINDOW"
}

variable "restore_testing_plan_start_window" {
  description = "Start window from the scheduled time during which the test should start"
  type        = number
  default     = 1
}

variable "restore_testing_plan_scheduled_expression" {
  description = "Scheduled Expression of Recovery Selection Point"
  type        = string
  default     = "cron(0 1 ? * SUN *)"
}

variable "restore_testing_plan_recovery_point_types" {
  description = "Recovery Point Types"
  type        = list(string)
  default     = ["SNAPSHOT"]
}

variable "restore_testing_plan_selection_window_days" {
  description = "Selection window days"
  type        = number
  default     = 7
}

variable "backup_copy_vault_arn" {
  description = "The ARN of the destination backup vault for cross-account backup copies."
  type        = string
  default     = ""
}

variable "backup_copy_vault_account_id" {
  description = "The account id of the destination backup vault for allowing restores back into the source account."
  type        = string
  default     = ""
}

variable "backup_plan_config" {
  description = "Configuration for backup plans"
  type = object({
    selection_tag       = string
    selection_tag_value = optional(string)
    selection_tags = optional(list(object({
      key   = optional(string)
      value = optional(string)
    })))
    compliance_resource_types = list(string)
    rules = list(object({
      name                     = string
      schedule                 = string
      completion_window        = optional(number)
      enable_continuous_backup = optional(bool)
      lifecycle = object({
        delete_after       = optional(number)
        cold_storage_after = optional(number)
      })
      copy_action = optional(object({
        delete_after = optional(number)
      }))
    }))
  })
  default = {
    selection_tag             = "BackupLocal"
    selection_tag_value       = "True"
    selection_tags            = []
    compliance_resource_types = ["S3"]
    rules = [
      {
        name     = "daily_kept_5_weeks"
        schedule = "cron(0 0 * * ? *)"
        lifecycle = {
          delete_after = 35
        }
        copy_action = {
          delete_after = 365
        }
      },
      {
        name     = "weekly_kept_3_months"
        schedule = "cron(0 1 ? * SUN *)"
        lifecycle = {
          delete_after = 90
        }
        copy_action = {
          delete_after = 365
        }
      },
      {
        name     = "monthly_kept_7_years"
        schedule = "cron(0 2 1  * ? *)"
        lifecycle = {
          cold_storage_after = 30
          delete_after       = 2555
        }
        copy_action = {
          delete_after = 365
        }
      },
      {
        name                     = "point_in_time_recovery"
        schedule                 = "cron(0 5 * * ? *)"
        enable_continuous_backup = true
        lifecycle = {
          delete_after = 35
        }
        copy_action = {
          delete_after = 365
        }
      }
    ]
  }
}

variable "backup_plan_config_dynamodb" {
  description = "Configuration for backup plans with dynamodb"
  type = object({
    enable              = bool
    selection_tag       = string
    selection_tag_value = optional(string)
    selection_tags = optional(list(object({
      key   = optional(string)
      value = optional(string)
    })))
    compliance_resource_types = list(string)
    rules = optional(list(object({
      name                     = string
      schedule                 = string
      completion_window        = optional(number)
      enable_continuous_backup = optional(bool)
      lifecycle = object({
        delete_after       = number
        cold_storage_after = optional(number)
      })
      copy_action = optional(object({
        delete_after = optional(number)
      }))
    })))
  })
  default = {
    enable                    = true
    selection_tag             = "BackupDynamoDB"
    selection_tag_value       = "True"
    selection_tags            = []
    compliance_resource_types = ["DynamoDB"]
    rules = [
      {
        name     = "dynamodb_daily_kept_5_weeks"
        schedule = "cron(0 0 * * ? *)"
        lifecycle = {
          delete_after = 35
        }
        copy_action = {
          delete_after = 365
        }
      },
      {
        name     = "dynamodb_weekly_kept_3_months"
        schedule = "cron(0 1 ? * SUN *)"
        lifecycle = {
          delete_after = 90
        }
        copy_action = {
          delete_after = 365
        }
      },
      {
        name     = "dynamodb_monthly_kept_7_years"
        schedule = "cron(0 2 1  * ? *)"
        lifecycle = {
          cold_storage_after = 30
          delete_after       = 2555
        }
        copy_action = {
          delete_after = 365
        }
      }
    ]
  }
}

variable "name_prefix" {
  description = "Name prefix for vault resources"
  type        = string
  validation {
    condition     = can(regex("^[^0-9]*$", var.name_prefix))
    error_message = "The name_prefix must not contain any numbers."
  }
}

variable "backup_plan_config_ebsvol" {
  description = "Configuration for backup plans with EBS"
  type = object({
    enable              = bool
    selection_tag       = string
    selection_tag_value = optional(string)
    selection_tags = optional(list(object({
      key   = optional(string)
      value = optional(string)
    })))
    compliance_resource_types = list(string)
    rules = optional(list(object({
      name                     = string
      schedule                 = string
      enable_continuous_backup = optional(bool)
      lifecycle = object({
        delete_after       = number
        cold_storage_after = optional(number)
      })
      copy_action = optional(object({
        delete_after = optional(number)
      }))
    })))
  })
  default = {
    enable                    = true
    selection_tag             = "BackupEBSVol"
    compliance_resource_types = ["EBS"]
    rules = [
      {
        name     = "ebsvol_daily_kept_5_weeks"
        schedule = "cron(0 0 * * ? *)"
        lifecycle = {
          delete_after = 35
        }
        copy_action = {
          delete_after = 365
        }
      },
      {
        name     = "ebsvol_weekly_kept_3_months"
        schedule = "cron(0 1 ? * SUN *)"
        lifecycle = {
          delete_after = 90
        }
        copy_action = {
          delete_after = 365
        }
      },
      {
        name     = "ebsvol_monthly_kept_7_years"
        schedule = "cron(0 2 1  * ? *)"
        lifecycle = {
          cold_storage_after = 30
          delete_after       = 2555
        }
        copy_action = {
          delete_after = 365
        }
      }
    ]
  }
}

variable "backup_plan_config_aurora" {
  description = "Configuration for backup plans with aurora"
  type = object({
    enable                    = bool
    selection_tag             = string
    compliance_resource_types = list(string)
    restore_testing_overrides = optional(string)
    rules = optional(list(object({
      name                     = string
      schedule                 = string
      enable_continuous_backup = optional(bool)
      lifecycle = object({
        delete_after       = number
        cold_storage_after = optional(number)
      })
      copy_action = optional(object({
        delete_after = optional(number)
      }))
    })))
  })
  default = {
    enable                    = true
    selection_tag             = "BackupAurora"
    compliance_resource_types = ["Aurora"]
    rules = [
      {
        name     = "aurora_daily_kept_5_weeks"
        schedule = "cron(0 0 * * ? *)"
        lifecycle = {
          delete_after = 35
        }
        copy_action = {
          delete_after = 365
        }
      },
      {
        name     = "aurora_weekly_kept_3_months"
        schedule = "cron(0 1 ? * SUN *)"
        lifecycle = {
          delete_after = 90
        }
        copy_action = {
          delete_after = 365
        }
      },
      {
        name     = "aurora_monthly_kept_7_years"
        schedule = "cron(0 2 1  * ? *)"
        lifecycle = {
          cold_storage_after = 30
          delete_after       = 2555
        }
        copy_action = {
          delete_after = 365
        }
      }
    ]
  }
}

variable "iam_role_permissions_boundary" {
  description = "Optional permissions boundary ARN for backup role"
  type        = string
  default     = "" # Empty by default
}
