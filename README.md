# AWS Backup

## Introduction

This module is to address the Engineering Red Line [Cloud-6](https://nhs.sharepoint.com/sites/X26_EngineeringCOE/SitePages/Red-lines.aspx#cloud-infrastructure).  It provides both a business-as-usual backup facility and the ability to recover from ransomware attacks with a logically airgapped backup[^1] in a separate AWS account.

This repository intends to provide a simple and easy to consume solution for provisioning AWS Backup with terraform. The headline features we aim to provide are:

* Immutable storage of persistent data for disaster recovery, with no possibility of human error or malicious tampering.
* Backup and restore within an AWS account, supporting all AWS services that AWS Backup supports.
* Backup and restore to a separate account, allowing for recovery from a situation where the original account is compromised.
* Customisable backup plans to allow for different retention periods and schedules appropriate to the data and product.
* Notifications to alert on backup failures and successes, and reporting for wider visibility.

This solution does not intend to provide backup and restoration of application code or executable assets.  It is *only* for persistent data storage of data that you cannot afford to lose, and typically this will be data that you cannot recreate from another source.

Similarly there is no mechanism within this solution to ensure that any schema versions or data formats are compatible with the live version of the application when it is restored.  You may wish to include an application version tag in your backups to ensure that you can identify a viable version of the application to restore the data to.

Setting retention periods and backup schedules will need the input of your Information Asset Owner.  We can't set a default that will apply to all situations.  We must not hold data for longer than we have legal rights to do so, and we must also minimise the storage cost; however we must also ensure that we can restore data to a point in time that is useful to the business.  Further, to comply fully with [Cloud-6](https://nhs.sharepoint.com/sites/X26_EngineeringCOE/SitePages/Red-lines.aspx#cloud-infrastructure) you will need to test the restoration process. Ransomware often targets backups and seeks not to be discovered. The immutability of the backups provided by this blueprint is a strong defence against this, but to avoid losing all your uncompromised backups, you will need your restoration testing cycle to be _shorter_ than the retention period.  That will guarantee that any ransomware compromise is discovered before all uncompromised backups are deleted.  If your retention period was six months, for instance, you might want to test restoration every two months to ensure that even if one restoration test is missed, there is still an opportunity to catch ransomware before your last good backup expires.

Today, the AWS services supported by these modules are:

* S3
* DynamoDB

The terraform structure allows any service supported by AWS Backup to be added in the future, so if you find that you need to apply this module to a new service, you will find that you can do so but we need you to contribute those changes back to this repository.

There is some terminology that is important to understand when working with AWS Backup vaults. It uses the terms "governance mode" and "compliance mode". In governance mode, a backup vault can be deleted, and mistakes can be fixed. In compliance mode, the backup vault is locked and cannot be deleted. Mistakes persist. The default mode is governance mode.

DO NOT SWITCH TO COMPLIANCE MODE UNTIL YOU ARE CERTAIN THAT YOU WANT TO LOCK THE VAULT.

A "compliance mode" vault that has passed a cooling-off period is intentionally impossible to delete. This is a feature, not a bug: we want to ensure that the stored data cannot be tampered with by an attacker or their malware, even in the face of collusion. This is good for data that you cannot afford to lose, but it is bad if you have misconfigured retention periods.

Again: DO NOT SWITCH TO COMPLIANCE MODE UNTIL YOU ARE CERTAIN THAT YOU WANT TO LOCK THE VAULT.

### Infrastructure

The code provided here is divided into two modules: `modules/source`, and `modules/destination`. The `source` module is to deploy to any account holding data that needs to be backed up and restored. The `destination` module is to configure a dedicated AWS account to maintain a replicated copy of vault recovery points from the source account: it holds a backup of the backup.  You will need both of these accounts provisioned ahead of time to use the full solution, but you can test the source and destination modules within the same account to check that the resources are provisioned correctly.

These modules will deploy a number of AWS resources:

* In the source account:
  * Vault
  * Backup plans
  * Restore testing
  * Vault policies
  * Backup KMS key
  * SNS topic for notifications
  * Backup framework for compliance
* modules/destination
  * Vault
  * Vault policies
  * Vault lock

![AWS Architecture](./docs/diagrams/aws-architecture.png)

Note that there are always two vaults.  In most restoration cases you should only need the `source` vault, so there is no need to copy data from the second, `destination` vault.  The latter is only used in the case of a disaster recovery scenario where the source account is compromised beyond use. As such the recovery time and recovery point objectives you will care about for situations in which the second vault is used should take this into account.

## Developer Guide

This guide will walk you through the set-up and deployment of the AWS Backup solution in a typical project.  This first implementation will only consider backing up S3 buckets.  It relies on the configuration in `examples/aws-backups.tf` to supply pre-requisite resources that are outside what the actual backup modules provide.  You may find that you need to change details in that file to harmonise with your project's structure and policies, but it is provided as a working example.

You will need:

* The ARN of an IAM role in each account that allows terraform to create the resources.  This role should have the `AdministratorAccess` policy attached.
* The target email address for notifications of backup success and failure.  For testing you can use a personal account, but this must be changed to a distribution list for a production deployment.

The terraform example in `examples/aws-backups.tf` uses the IAM roles to identify the source and destination accounts. You will need to supply the two ARNs in your deployment pipeline.  If you already have an `$AWS_ROLE_ARN` environment variable for your `source` account configured, supply an `$AWS_BACKUP_ROLE_ARN` for the `destination` account.  Remember that these ARNs must be treated as secrets so as not to risk leaking the AWS account IDs.

I will assume that your project uses the [repository template structure](https://github.com/nhs-england-tools/repository-template).  In that structure, the terraform configuration is in the `infrastructure/modules` and `infrastructure/environments` directories.  The `modules` directory contains the reusable modules, and the `environments` directory contains the environment-specific configuration.  If this does not match your project structure, you will need to adapt the instructions accordingly.  I will also assume that you are applying this configuration to your `dev` environment, which would be found in the `infrastructure/environments/dev` directory, with `infrastructure/environments/dev/main.tf` as an entry-point.

Copy the `modules/source` and `modules/destination` directories into your `infrastructure/modules` directory, giving you `infrastructure/modules/aws-backup-source` and `infrastructure/modules/aws-backup-destination`.

To set which resources will be backed up by AWS Backup, you need to tag them with the tag `NHSE-Enable-Backup`.  So do that now: in your *existing* terraform configuration, add the tag to the resources that you want to back up, and apply it.  For example, if you want to back up an S3 bucket, you would add the tag to the bucket resource:

```terraform
resource "aws_s3_bucket" "my_precious_bucket" {
  bucket = "my-precious-bucket"

  tags = {
    "NHSE-Enable-Backup" = "True"
  }
}
```

Now copy the file `examples/aws-backups.tf` to your project as `infrastructure/environments/dev/aws-backups.tf`.  Read it and make sure you understand the comments.

TODO: confirm that we can mix and match the source and destination IAM roles when using OIDC auth.

## Usage

To customise the solution and apply it to your own use case take the following steps:

1. Analyse Requirements

   Identify the resources you want to backup, the schedule on which you need take backups and how long you need to retain the backups (the retention period).

2. Considerations

   Consider implmenting SCP policies to prevent any IAM entity from alerting  Vault Locks, Vault Access Policy and Vault Restore Points.

   Consider what [AWS Backup Vault Lock](https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html) you want to enable and at what point you might want to move from governance to compliance mode.

   Consider how you intend on testing backup and in particular how you will test that the destination vault is locked down sufficiently enough to ensure recovery points can not be interfered with.

3. Plan and Design

   Review the examples provided in the developer guide section of this README. Review and understand the modules variables, as you will need to customise and adapt them for your own environment.

4. Adapt and Implement

   Now it's time to implement the terraform infrastructure, specific to your environment by adapting the examples which have been provided and incorporating them into your existing terraform projects.

5. Deploy and Verify

   Deploy the terraform using your existing procedures and verify the resources have been provisioned as expected using the AWS console.

[^1]: While this blueprint was being written, AWS released [logically air-gapped vaults](https://docs.aws.amazon.com/aws-backup/latest/devguide/logicallyairgappedvault.html) to AWS Backup. This solution does not use that feature because at time of writing it lacks support for some critical use cases.  It is reasonable to assume that at some point a future release of this blueprint will switch to it, as it will allow a reduction of complexity and cost.
