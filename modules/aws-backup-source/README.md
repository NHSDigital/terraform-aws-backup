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

| Name                                                                                                                                                                       | Description | Type | Default | Required |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|------|---------|:--------:|
| <a name="input_backup_copy_vault_account_id"></a> [backup\_copy\_vault\_account\_id](#input\_backup\_copy\_vault\_account\_id)                                             | The account id of the destination backup vault for allowing restores back into the source account. | `string` | `""` |    no    |
| <a name="input_backup_copy_vault_arn"></a> [backup\_copy\_vault\_arn](#input\_backup\_copy\_vault\_arn)                                                                    | The ARN of the destination backup vault for cross-account backup copies. | `string` | `""` |    no    |
| <a name="input_backup_plan_config"></a> [backup\_plan\_config](#input\_backup\_plan\_config)                                                                               | Configuration for backup plans | <pre>object({<br/>    selection_tag       = string<br/>    selection_tag_value = optional(string)<br/>    selection_tags = optional(list(object({<br/>      key   = optional(string)<br/>      value = optional(string)<br/>    })))<br/>    compliance_resource_types = list(string)<br/>    rules = list(object({<br/>      name                     = string<br/>      schedule                 = string<br/>      enable_continuous_backup = optional(bool)<br/>      lifecycle = object({<br/>        delete_after       = optional(number)<br/>        cold_storage_after = optional(number)<br/>      })<br/>      copy_action = optional(object({<br/>        delete_after = optional(number)<br/>      }))<br/>    }))<br/>  })</pre> | <pre>{<br/>  "compliance_resource_types": [<br/>    "S3"<br/>  ],<br/>  "rules": [<br/>    {<br/>      "copy_action": {<br/>        "delete_after": 365<br/>      },<br/>      "lifecycle": {<br/>        "delete_after": 35<br/>      },<br/>      "name": "daily_kept_5_weeks",<br/>      "schedule": "cron(0 0 * * ? *)"<br/>    },<br/>    {<br/>      "copy_action": {<br/>        "delete_after": 365<br/>      },<br/>      "lifecycle": {<br/>        "delete_after": 90<br/>      },<br/>      "name": "weekly_kept_3_months",<br/>      "schedule": "cron(0 1 ? * SUN *)"<br/>    },<br/>    {<br/>      "copy_action": {<br/>        "delete_after": 365<br/>      },<br/>      "lifecycle": {<br/>        "cold_storage_after": 30,<br/>        "delete_after": 2555<br/>      },<br/>      "name": "monthly_kept_7_years",<br/>      "schedule": "cron(0 2 1  * ? *)"<br/>    },<br/>    {<br/>      "copy_action": {<br/>        "delete_after": 365<br/>      },<br/>      "enable_continuous_backup": true,<br/>      "lifecycle": {<br/>        "delete_after": 35<br/>      },<br/>      "name": "point_in_time_recovery",<br/>      "schedule": "cron(0 5 * * ? *)"<br/>    }<br/>  ],<br/>  "selection_tag": "BackupLocal",<br/>  "selection_tag_value": "True",<br/>  "selection_tags": []<br/>}</pre> |    no    |
| <a name="input_backup_plan_config_dynamodb"></a> [backup\_plan\_config\_dynamodb](#input\_backup\_plan\_config\_dynamodb)                                                  | Configuration for backup plans with dynamodb | <pre>object({<br/>    enable              = bool<br/>    selection_tag       = string<br/>    selection_tag_value = optional(string)<br/>    selection_tags = optional(list(object({<br/>      key   = optional(string)<br/>      value = optional(string)<br/>    })))<br/>    compliance_resource_types = list(string)<br/>    rules = optional(list(object({<br/>      name                     = string<br/>      schedule                 = string<br/>      enable_continuous_backup = optional(bool)<br/>      lifecycle = object({<br/>        delete_after       = number<br/>        cold_storage_after = optional(number)<br/>      })<br/>      copy_action = optional(object({<br/>        delete_after = optional(number)<br/>      }))<br/>    })))<br/>  })</pre> | <pre>{<br/>  "compliance_resource_types": [<br/>    "DynamoDB"<br/>  ],<br/>  "enable": true,<br/>  "rules": [<br/>    {<br/>      "copy_action": {<br/>        "delete_after": 365<br/>      },<br/>      "lifecycle": {<br/>        "delete_after": 35<br/>      },<br/>      "name": "dynamodb_daily_kept_5_weeks",<br/>      "schedule": "cron(0 0 * * ? *)"<br/>    },<br/>    {<br/>      "copy_action": {<br/>        "delete_after": 365<br/>      },<br/>      "lifecycle": {<br/>        "delete_after": 90<br/>      },<br/>      "name": "dynamodb_weekly_kept_3_months",<br/>      "schedule": "cron(0 1 ? * SUN *)"<br/>    },<br/>    {<br/>      "copy_action": {<br/>        "delete_after": 365<br/>      },<br/>      "lifecycle": {<br/>        "cold_storage_after": 30,<br/>        "delete_after": 2555<br/>      },<br/>      "name": "dynamodb_monthly_kept_7_years",<br/>      "schedule": "cron(0 2 1  * ? *)"<br/>    }<br/>  ],<br/>  "selection_tag": "BackupDynamoDB",<br/>  "selection_tag_value": "True",<br/>  "selection_tags": []<br/>}</pre> |    no    |
| <a name="input_backup_plan_config_aurora"></a> [backup_plan_config_aurora](#input_backup_plan_config_aurora)                                                               | Configuration for backup plans with aurora | <pre>object({<br> enable = bool<br> selection_tag = string<br> compliance_resource_types = list(string)<br> restore_testing_overrides = optional(string)<br> rules = optional(list(object({<br> name = string<br> schedule = string<br> enable_continuous_backup = optional(bool)<br> lifecycle = object({<br> delete_after = number<br> cold_storage_after = optional(number)<br> })<br> copy_action = optional(object({<br> delete_after = optional(number)<br> }))<br> })))<br> })</pre> | <pre>{<br> "compliance_resource_types": [<br> "Aurora"<br> ],<br> "enable": true,<br> "restore_testing_overrides" : "{\"dbsubnetgroupname\": \"test-subnet\"}",<br> "rules": [<br> {<br> "copy_action": {<br> "delete_after": 365<br> },<br> "lifecycle": {<br> "delete_after": 35<br> },<br> "name": "aurora_daily_kept_5_weeks",<br> "schedule": "cron(0 0 * * ? *)"<br> },<br> {<br> "copy_action": {<br> "delete_after": 365<br> },<br> "lifecycle": {<br> "delete_after": 90<br> },<br> "name": "aurora_weekly_kept_3_months",<br> "schedule": "cron(0 1 ? * SUN *)"<br> },<br> {<br> "copy_action": {<br> "delete_after": 365<br> },<br> "lifecycle": {<br> "cold_storage_after": 30,<br> "delete_after": 2555<br> },<br> "name": "aurora_monthly_kept_7_years",<br> "schedule": "cron(0 2 1 * ? *)"<br> }<br> ],<br> "selection_tag": "BackupAurora"<br>}</pre> |    no    |
| <a name="input_parameter_store_backup_config"></a> [parameter_store_backup_config](#input_backup_plan_config_parameter_store)                                              | Configuration for the scheduled Lambda function to backup tagged Parameter Store parameters to S3.            | <pre>object({ enable = bool selection_tag = string selection_tag_value = optional(string) selection_tags = optional(list(object({ key = optional(string) value = optional(string) }))) lambda_backup_cron = optional(string) lambda_timeout_seconds = optional(number) air_gapped_kms_key_arn = optional(string) s3_bucket_name = optional(string) rules = optional(list(object({ name = string schedule = string completion_window = optional(number) enable_continuous_backup = optional(bool) lifecycle = object({ delete_after = number cold_storage_after = optional(number) }) copy_action = optional(object({ delete_after = optional(number) })) }))) })</pre>     | <pre>{ "air_gapped_kms_key_arn": "", "enable": true, "lambda_backup_cron": "cron(0 6 * * ? *)", "lambda_timeout_seconds": 300, "rules": [ { "copy_action": { "delete_after": 365 }, "lifecycle": { "delete_after": 35 }, "name": "daily_kept_5_weeks", "schedule": "cron(0 0 * * ? *)" }, { "copy_action": { "delete_after": 365 }, "lifecycle": { "delete_after": 90 }, "name": "weekly_kept_3_months", "schedule": "cron(0 1 ? * SUN *)" }, { "copy_action": { "delete_after": 365 }, "lifecycle": { "cold_storage_after": 30, "delete_after": 2555 }, "name": "monthly_kept_7_years", "schedule": "cron(0 2 1 * ? *)" }, { "copy_action": { "delete_after": 365 }, "enable_continuous_backup": true, "lifecycle": { "delete_after": 35 }, "name": "point_in_time_recovery", "schedule": "cron(0 5 * * ? *)" } ], "s3_bucket_name": "", "selection_tag": "BackupParameterStore", "selection_tag_value": "True", "selection_tags": [] }</pre>        |    no    |
| <a name="input_bootstrap_kms_key_arn"></a> [bootstrap\_kms\_key\_arn](#input\_bootstrap\_kms\_key\_arn)                                                                    | The ARN of the bootstrap KMS key used for encryption at rest of the SNS topic. | `string` | n/a |   yes    |
| <a name="input_environment_name"></a> [environment\_name](#input\_environment\_name)                                                                                       | The name of the environment where AWS Backup is configured. | `string` | n/a |   yes    |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix)                                                                                                      | Optional name prefix for vault resources | `string` | `null` |    no    |
| <a name="input_notifications_target_email_address"></a> [notifications\_target\_email\_address](#input\_notifications\_target\_email\_address)                             | The email address to which backup notifications will be sent via SNS. | `string` | `""` |    no    |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name)                                                                                                   | The name of the project this relates to. | `string` | n/a |   yes    |
| <a name="input_reports_bucket"></a> [reports\_bucket](#input\_reports\_bucket)                                                                                             | Bucket to drop backup reports into | `string` | n/a |   yes    |
| <a name="input_restore_testing_plan_algorithm"></a> [restore\_testing\_plan\_algorithm](#input\_restore\_testing\_plan\_algorithm)                                         | Algorithm of the Recovery Selection Point | `string` | `"LATEST_WITHIN_WINDOW"` |    no    |
| <a name="input_restore_testing_plan_recovery_point_types"></a> [restore\_testing\_plan\_recovery\_point\_types](#input\_restore\_testing\_plan\_recovery\_point\_types)    | Recovery Point Types | `list(string)` | <pre>[<br/>  "SNAPSHOT"<br/>]</pre> |    no    |
| <a name="input_restore_testing_plan_scheduled_expression"></a> [restore\_testing\_plan\_scheduled\_expression](#input\_restore\_testing\_plan\_scheduled\_expression)      | Scheduled Expression of Recovery Selection Point | `string` | `"cron(0 1 ? * SUN *)"` |    no    |
| <a name="input_restore_testing_plan_selection_window_days"></a> [restore\_testing\_plan\_selection\_window\_days](#input\_restore\_testing\_plan\_selection\_window\_days) | Selection window days | `number` | `7` |    no    |
| <a name="input_restore_testing_plan_start_window"></a> [restore\_testing\_plan\_start\_window](#input\_restore\_testing\_plan\_start\_window)                              | Start window from the scheduled time during which the test should start | `number` | `1` |    no    |
| <a name="input_terraform_role_arn"></a> [terraform\_role\_arn](#input\_terraform\_role\_arn)                                                                               | ARN of Terraform role used to deploy to account | `string` | n/a |   yes    |

## Outputs

No outputs.
<!-- END_TF_DOCS -->

## Restoration State Machine (Preview)

When `restore_state_machine_enable = true` a Step Functions state machine named `<prefix>-restore-workflow` (or the value of `restore_state_machine_name_override`) is deployed. It orchestrates:

1. Copy of a recovery point from the destination vault back into the source vault (requires `lambda_copy_recovery_point_enable`).
2. Sequential restore operations for one or more targets (currently supported: `S3`, `RDS`).
3. Polling until completion for each restore job.

### Input Contract

Execution input example:

```json
{
  "recovery_point_arn": "arn:aws:backup:eu-west-2:123456789012:recovery-point:11112222-3333-4444-5555-666677778888",
  "desired_targets": [
    {
      "type": "S3",
      "destination_s3_bucket": "my-restore-bucket",
      "iam_role_arn": "arn:aws:iam::123456789012:role/BackupRestoreRole"
    },
    {
      "type": "RDS",
      "iam_role_arn": "arn:aws:iam::123456789012:role/BackupRestoreRole",
      "db_instance_identifier": "restored-db-1",
      "db_instance_class": "db.t3.medium",
      "db_subnet_group_name": "my-subnet-group",
      "vpc_security_group_ids": ["sg-0123456789abcdef0"],
      "restore_metadata_overrides": {"AllocatedStorage": "20"}
    }
  ]
}
```

Each target object is sent to the corresponding Lambda. Additional resource types (DynamoDB, Aurora) will be added once their restore Lambdas exist in the module.

### Output

Aggregated per-target results are available under `$.restore_targets` in the execution output.

### Notes

- If a required Lambda is disabled the execution will fail at that Task state.
- Validation Lambda integration is planned but not yet included.
- Poll intervals controlled by `restore_state_machine_wait_seconds`.

