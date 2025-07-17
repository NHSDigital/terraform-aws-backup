# AWS Backup Module

The AWS Backup Module helps automates the setup of AWS Backup resources in a source account. It streamlines the process of creating, managing, and standardising backup configurations.

## Example

```terraform
module "test_aws_backup" {
  source = "./modules/aws-backup"

  environment_name                   = "environment_name"
  bootstrap_kms_key_arn              = kms_key[0].arn
  project_name                       = "testproject"
  reports_bucket                     = "compliance-reports"
  terraform_role_arn                 = data.aws_iam_role.terraform_role.arn
  name_prefix                        = "backup"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.5 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | ~> 1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5 |
| <a name="provider_awscc"></a> [awscc](#provider\_awscc) | ~> 1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_backup_framework.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_framework) | resource |
| [aws_backup_framework.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_framework) | resource |
| [aws_backup_plan.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_plan) | resource |
| [aws_backup_plan.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_plan) | resource |
| [aws_backup_selection.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection) | resource |
| [aws_backup_selection.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection) | resource |
| [aws_backup_vault.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault) | resource |
| [aws_backup_vault_notifications.backup_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_notifications) | resource |
| [aws_backup_vault_policy.vault_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_policy) | resource |
| [aws_iam_role.backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.restore](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.s3_backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.s3_restore](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.backup_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.aws_backup_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_sns_topic.backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_subscription.aws_backup_notifications_email_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [awscc_backup_restore_testing_plan.backup_restore_testing_plan](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/backup_restore_testing_plan) | resource |
| [awscc_backup_restore_testing_selection.backup_restore_testing_selection_dynamodb](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/backup_restore_testing_selection) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.allow_backup_to_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.backup_key_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.vault_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_roles.roles](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name                                                                                                                                                                       | Description                                                                                        | Type | Default | Required |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|------|---------|:--------:|
| <a name="input_backup_copy_vault_account_id"></a> [backup\_copy\_vault\_account\_id](#input\_backup\_copy\_vault\_account\_id)                                             | The account id of the destination backup vault for allowing restores back into the source account. | `string` | `""` | no |
| <a name="input_backup_copy_vault_arn"></a> [backup\_copy\_vault\_arn](#input\_backup\_copy\_vault\_arn)                                                                    | The ARN of the destination backup vault for cross-account backup copies.                           | `string` | `""` | no |
| <a name="input_backup_plan_config"></a> [backup\_plan\_config](#input\_backup\_plan\_config)                                                                               | Configuration for backup plans                                                                     | <pre>object({<br/>    selection_tag       = string<br/>    selection_tag_value = optional(string)<br/>    selection_tags = optional(list(object({<br/>      key   = optional(string)<br/>      value = optional(string)<br/>    })))<br/>    compliance_resource_types = list(string)<br/>    rules = list(object({<br/>      name                     = string<br/>      schedule                 = string<br/>      enable_continuous_backup = optional(bool)<br/>      lifecycle = object({<br/>        delete_after       = optional(number)<br/>        cold_storage_after = optional(number)<br/>      })<br/>      copy_action = optional(object({<br/>        delete_after = optional(number)<br/>      }))<br/>    }))<br/>  })</pre> | <pre>{<br/>  "compliance_resource_types": [<br/>    "S3"<br/>  ],<br/>  "rules": [<br/>    {<br/>      "copy_action": {<br/>        "delete_after": 365<br/>      },<br/>      "lifecycle": {<br/>        "delete_after": 35<br/>      },<br/>      "name": "daily_kept_5_weeks",<br/>      "schedule": "cron(0 0 * * ? *)"<br/>    },<br/>    {<br/>      "copy_action": {<br/>        "delete_after": 365<br/>      },<br/>      "lifecycle": {<br/>        "delete_after": 90<br/>      },<br/>      "name": "weekly_kept_3_months",<br/>      "schedule": "cron(0 1 ? * SUN *)"<br/>    },<br/>    {<br/>      "copy_action": {<br/>        "delete_after": 365<br/>      },<br/>      "lifecycle": {<br/>        "cold_storage_after": 30,<br/>        "delete_after": 2555<br/>      },<br/>      "name": "monthly_kept_7_years",<br/>      "schedule": "cron(0 2 1  * ? *)"<br/>    },<br/>    {<br/>      "copy_action": {<br/>        "delete_after": 365<br/>      },<br/>      "enable_continuous_backup": true,<br/>      "lifecycle": {<br/>        "delete_after": 35<br/>      },<br/>      "name": "point_in_time_recovery",<br/>      "schedule": "cron(0 5 * * ? *)"<br/>    }<br/>  ],<br/>  "selection_tag": "BackupLocal",<br/>  "selection_tag_value": "True",<br/>  "selection_tags": []<br/>}</pre> | no |
| <a name="input_backup_plan_config_dynamodb"></a> [backup\_plan\_config\_dynamodb](#input\_backup\_plan\_config\_dynamodb)                                                  | Configuration for backup plans with dynamodb                                                       | <pre>object({<br/>    enable              = bool<br/>    selection_tag       = string<br/>    selection_tag_value = optional(string)<br/>    selection_tags = optional(list(object({<br/>      key   = optional(string)<br/>      value = optional(string)<br/>    })))<br/>    compliance_resource_types = list(string)<br/>    rules = optional(list(object({<br/>      name                     = string<br/>      schedule                 = string<br/>      enable_continuous_backup = optional(bool)<br/>      lifecycle = object({<br/>        delete_after       = number<br/>        cold_storage_after = optional(number)<br/>      })<br/>      copy_action = optional(object({<br/>        delete_after = optional(number)<br/>      }))<br/>    })))<br/>  })</pre> | <pre>{<br/>  "compliance_resource_types": [<br/>    "DynamoDB"<br/>  ],<br/>  "enable": true,<br/>  "rules": [<br/>    {<br/>      "copy_action": {<br/>        "delete_after": 365<br/>      },<br/>      "lifecycle": {<br/>        "delete_after": 35<br/>      },<br/>      "name": "dynamodb_daily_kept_5_weeks",<br/>      "schedule": "cron(0 0 * * ? *)"<br/>    },<br/>    {<br/>      "copy_action": {<br/>        "delete_after": 365<br/>      },<br/>      "lifecycle": {<br/>        "delete_after": 90<br/>      },<br/>      "name": "dynamodb_weekly_kept_3_months",<br/>      "schedule": "cron(0 1 ? * SUN *)"<br/>    },<br/>    {<br/>      "copy_action": {<br/>        "delete_after": 365<br/>      },<br/>      "lifecycle": {<br/>        "cold_storage_after": 30,<br/>        "delete_after": 2555<br/>      },<br/>      "name": "dynamodb_monthly_kept_7_years",<br/>      "schedule": "cron(0 2 1  * ? *)"<br/>    }<br/>  ],<br/>  "selection_tag": "BackupDynamoDB",<br/>  "selection_tag_value": "True",<br/>  "selection_tags": []<br/>}</pre> | no |
| <a name="input_bootstrap_kms_key_arn"></a> [bootstrap\_kms\_key\_arn](#input\_bootstrap\_kms\_key\_arn)                                                                    | The ARN of the bootstrap KMS key used for encryption at rest of the SNS topic.                     | `string` | n/a | yes |
| <a name="input_environment_name"></a> [environment\_name](#input\_environment\_name)                                                                                       | The name of the environment where AWS Backup is configured.                                        | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix)                                                                                                      | Optional name prefix for vault resources                                                           | `string` | `null` | no |
| <a name="input_notifications_target_email_address"></a> [notifications\_target\_email\_address](#input\_notifications\_target\_email\_address)                             | The email address to which backup notifications will be sent via SNS.                              | `string` | `""` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name)                                                                                                   | The name of the project this relates to.                                                           | `string` | n/a | yes |
| <a name="input_reports_bucket"></a> [reports\_bucket](#input\_reports\_bucket)                                                                                             | Bucket to drop backup reports into                                                                 | `string` | n/a | yes |
| <a name="input_restore_testing_plan_algorithm"></a> [restore\_testing\_plan\_algorithm](#input\_restore\_testing\_plan\_algorithm)                                         | Algorithm of the Recovery Selection Point                                                          | `string` | `"LATEST_WITHIN_WINDOW"` | no |
| <a name="input_restore_testing_plan_recovery_point_types"></a> [restore\_testing\_plan\_recovery\_point\_types](#input\_restore\_testing\_plan\_recovery\_point\_types)    | Recovery Point Types                                                                               | `list(string)` | <pre>[<br/>  "SNAPSHOT"<br/>]</pre> | no |
| <a name="input_restore_testing_plan_scheduled_expression"></a> [restore\_testing\_plan\_scheduled\_expression](#input\_restore\_testing\_plan\_scheduled\_expression)      | Scheduled Expression of Recovery Selection Point                                                   | `string` | `"cron(0 1 ? * SUN *)"` | no |
| <a name="input_restore_testing_plan_selection_window_days"></a> [restore\_testing\_plan\_selection\_window\_days](#input\_restore\_testing\_plan\_selection\_window\_days) | Selection window days                                                                              | `number` | `7` | no |
| <a name="input_restore_testing_plan_start_window"></a> [restore\_testing\_plan\_start\_window](#input\_restore\_testing\_plan\_start\_window)                              | Start window from the scheduled time during which the test should start                            | `number` | `1` | no |
| <a name="input_terraform_role_arn"></a> [terraform\_role\_arns](#input\_terraform\_role\_arn)                                                                              | Deprecated, if this and terraform_role_arns not set, defualts to caller arn.                       | `string` | "" | no |
| <a name="input_terraform_role_arns"></a> [terraform\_role\_arns](#input\_terraform\_role\_arns)                                                                            | List of ARNs of Terraform roles used to deploy to account, if empty defaults to caller arn         | `string` | [] | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
