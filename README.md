# AWS Backup

## Introduction

This repository intends to provide a simple and easy to consume solution for provisioning AWS Backup. It's aim is to give developers terraform modules that can be used in a source and destination account to create and manage AWS Backup vaults.

The following technologies are used:

* AWS
* Terraform

### Outstanding Questions

* The source module was initially created to support backups of S3 and DynamoDB. It should be possible to support other AWS services by setting the compliance_resource_types and selection_tag however it will require proper testing with different AWS services before use.

## Design

The repository consists of:

* Terraform modules to create the infrastructure required for AWS backup

### Infrastructure

A typical backup solution that utilises these modules will consist of a number of AWS resources:

* modules/source - Intended to be deployed to any account that has a requirement to utilise AWS Backup.
  * AWS Backup resources that could be provisioned
    * Vault
    * Backup plans
    * Restore testing
    * Vault policies
    * Backup KMS key
    * SNS topic for notifications
    * Backup framework for compliance
* modules/destination - Intended to be deployed to a dedicated backup AWS account used to maintain a replicated copy of vault recovery points from a source account
  * AWS Backup resources that could be provisioned
    * Vault
    * Vault policies
    * Vault lock

![AWS Architecture](./docs/diagrams/aws-architecture.png)

## Repository Structure

The repository consists of the following directories:

* `./docs`

  Stores files and assets related to the documentation.

* `./modules`

  Stores the infrastructure as code - a set of terraform modules.

## Developer Guide

### Source module

**Pre-Requisites**

The following resources will need to have already been provisioned or identified to be passed into the module as variables

* KMS Key used for encryption at rest of the SNS topic
* S3 bucket for compliance reports
* Destination vault (optional)
  * Only required if you intend utilise the destination module to copy recovery points to a dedicated backup account. You will need to provision a vault using the destination module prior to provisioning the source vault.

**Simple example**

Example of how the module can be used to provision the resources for AWS Backup using default variables

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

**More complex example - without enabling copy to a backup account**

Example of how the module can be used to provision the resources for AWS Backup and setting custom a backup plan but not copying recovery points to a destination backup account

```terraform

module "test_aws_backup" {
  source = "./modules/aws-backup"

  environment_name                   = "environment_name"
  bootstrap_kms_key_arn              = kms_key[0].arn
  project_name                       = "testproject"
  reports_bucket                     = "compliance-reports"
  terraform_role_arn                 = data.aws_iam_role.terraform_role.arn
  notifications_target_email_address = "backupnotifications@email.com"
  backup_plan_config                 = {
                                          "compliance_resource_types": [
                                            "S3"
                                          ],
                                          "rules": [
                                            {
                                              "lifecycle": {
                                                "delete_after": 35
                                              },
                                              "name": "daily_kept_5_weeks",
                                              "schedule": "cron(0 0 * * ? *)"
                                            }
                                          ],
                                          "selection_tag": "EnableBackup"
                                        }
}

```

**More complex example - with backup account copy**

Example of how the module can be used to provision the resources for AWS Backup and setting custom a backup plan and copying recovery points to a destination backup account

```terraform

module "test_aws_backup" {
  source = "./modules/aws-backup"

  backup_copy_vault_account_id       = "000123456789"
  backup_copy_vault_arn              = "arn:aws:backup:region:account-id:backup-vault:testvault"
  environment_name                   = "environment_name"
  bootstrap_kms_key_arn              = kms_key[0].arn
  project_name                       = "testproject"
  reports_bucket                     = "compliance-reports"
  terraform_role_arn                 = data.aws_iam_role.terraform_role.arn
  notifications_target_email_address = "backupnotifications@email.com"
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
                                          "selection_tag": "EnableBackup"
                                        }
}

```

### Destination module

**Pre-Requisites**

The following resources will need to have already been provisioned or identified to be passed into the module as variables

* KMS Key used to encrypt the vault
* Source AWS Account ID and name

**Example**

Example of how the module can be used to provision the resources for AWS Backup in a dedicated backup account

```terraform

module "test_backup_vault" {
  source                  = "./modules/aws_backup"
  source_account_name     = "test"
  account_id              = local.aws_accounts_ids["backup"]
  source_account_id       = local.aws_accounts_ids["test"]
  kms_key                 = aws_kms_key.backup_key.arn
  enable_vault_protection = true
}

```

## Usage

To customise the solution and apply it to your own use case take the following steps:

1. Analyse Requirements

   Identify the resources you want to backup, the schedule on which you need take backups and how long you need to retain the backups (the retention period).

2. Considerations

   Consider implmenting SCP policies to prevent any IAM entity from alerting  Vault Locks, Vault Access Policy and Vault Restore Points. 

   Consider what AWS Backup Vault Lock you want to enable and at what point you might want to move from governance to compliance mode - https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html

   Consider how you intend on testing backup and in particular how you will test that the destination vault is locked down sufficiently enough to ensure recovery points can not be interfered with.

3. Plan and Design

   Review the examples provided in the developer guide section of this README. Review and understand the modules variables, as you will need to customise and adapt them for your own environment.

4. Adapt and Implement

   Now it's time to implement the terraform infrastructure, specific to your environment by adapting the examples which have been provided and incorporating them into your existing terraform projects.

5. Deploy and Verify

   Deploy the terraform using your existing procedures and verify the resources have been provisioned as expected using the AWS console.