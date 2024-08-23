provider  "aws" {
  alias  = "source"
  region = "eu-west-2"
}

provider "aws" {
  alias  = "destination"
  region = "eu-west-2"
  assume_role {
    role_arn = local.destination_terraform_role_arn
  }
}

variable "source_terraform_role_arn" {
  description = "ARN of the terraform role in the source account"
  type        = string
  default     = "arn:aws:iam::000000000000:role/terraform-role"
}

variable "destination_terraform_role_arn" {
  description = "ARN of the terraform role in the destination account"
  type        = string
  default     = "arn:aws:iam::000000000000:role/terraform-role"
}

locals {
  # Adjust these as required
  project_name = "my-shiny-project"
  environment_name = "dev"

  source_account_id = aws.source_caller_identity.current.account_id
  destination_account_id = aws.destination_caller_identity.current.account_id

  # Adjust this to the ARN of the terraform role in the source account
  source_terraform_role_arn = var.source_terraform_role_arn
  # Adjust this to the ARN of the terraform role in the destination account
  destination_terraform_role_arn = var.destination_terraform_role_arn
}



# First, we create an S3 bucket for compliance reports.

resource "aws_s3_bucket" "backup_reports" {
  bucket_prefix        = "${local.project_name}-backup-reports"
}

# Now we have to configure access to the report bucket. You may already have a module for creating
# S3 buckets with more refined access rules, which you may prefer to use.

resource "aws_s3_bucket_ownership_controls" "backup_reports" {
  bucket = aws_s3_bucket.backup_reports.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "backup_reports" {
  depends_on = [aws_s3_bucket_ownership_controls.backup_reports]

  bucket = aws_s3_bucket.backup_reports.id
  acl    = "private"
}

# We need KMS keys for a couple of things. First we need a key for the SNS topic that will be used
# for notifications from AWS Backup. This key will be used to encrypt the messages sent to the topic
# before they are sent to the subscribers, but isn't needed by the recipients of the messages.

# First we need some contextual data
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Now we can define the key itself
resource "aws_kms_key" "backup_notifications" {
  description             = "KMS key for AWS Backup notifications"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Sid    = "Enable IAM User Permissions"
        Principal = {
          AWS = "arn:aws:iam::${local.source_account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      },
      {
        Effect    = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action    = ["kms:GenerateDataKey*", "kms:Decrypt"]
        Resource  = "*"
      },
    ]
  })
}

# Now we need a key for the backup vaults. This key will be used to encrypt the backups themselves.
# We need one per vault (on the assumption that each vault will be in a different account).

resource "aws_kms_key" "source_backup_key" {
  description             = "KMS key for AWS Backup vaults"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Sid    = "Enable IAM User Permissions"
        Principal = {
          AWS = "arn:aws:iam::${local.source_account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_key" "destination_backup_key" {
  provider                = aws.destination
  description             = "KMS key for AWS Backup vaults"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Sid    = "Enable IAM User Permissions"
        Principal = {
          AWS = "arn:aws:iam::${local.destination_account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      }
    ]
  })
}

# Now we can deploy the source and destination modules, referencing the resources we've created above.

module "source" {
  source = "../modules/aws-backup-source"

  backup_copy_vault_account_id       = local.destination_account_id
  backup_copy_vault_arn              = module.destination.vault_arn
  environment_name                   = local.environment_name
  bootstrap_kms_key_arn              = aws_kms_key.backup_notifications.arn
  project_name                       = local.project_name
  reports_bucket                     = aws_s3_bucket.backup_reports.bucket
  terraform_role_arn                 = local.source_terraform_role_arn

  backup_plan_config                 = {
                                        "compliance_resource_types": [
                                          "S3"
                                        ],
                                        "rules": [
                                          {
                                            "copy_action": {
                                              "delete_after": 365
                                            },
                                            "lifecycle": {
                                              "delete_after": 35
                                            },
                                            "name": "daily_kept_5_weeks",
                                            "schedule": "cron(0 0 * * ? *)"
                                          }
                                        ],
                                        "selection_tag": "NHSE-Enable-Backup"
                                      }
}

module "destination" {
  providers = { aws = aws.destination }
  source = "../modules/aws-backup-destination"

  source_account_name     = "source"
  account_id              = local.destination_account_id
  source_account_id       = local.source_account_id
  kms_key                 = aws_kms_key.destination_backup_key.arn
  enable_vault_protection = false
}
