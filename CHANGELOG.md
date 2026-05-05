# Changelog

## [v1.4.3] (2026-05-05)

### Improvements

- Update Copilot instructions to not run Trivy (#115)
- Bump actions/checkout from 3 to 6 (#121)

## [v1.4.2] (2026-03-16)

### Features

- Add cross-account copy recovery point Lambda with IAM role in destination module (#102)
- Add S3 restore Lambda (`restore_to_s3`) with Terraform wiring and unit tests (#91)

### Bug Fixes

- Fix `name_prefix` IAM condition by replacing failing `coalesce` call with plain comparisons (#108)
- Fix nullable type alignment in `backup_plan_config_parameter_store` variable (#112)

### Improvements

- Apply `terraform fmt` auto-formatting across modules and examples (#112)

## [v1.4.1] (2025-11-13)

### Features

- Post release version lambda (#83)

### Bug Fixes

- Correct duplicate terraform module resource name (#97)

## [v1.4.0] (2025-11-04)

### Features

- Add support for parameter store backup through S3 bucket restoration (#87)
- Add vault name to the terraform module outputs (#80)

### Bug Fixes

- Correct documentation (#88)
- Update documentation for covered services (#81)

## [v1.3.0] (2025-07-24)

### Features

- Allow multiple destination vaults per account (#49)
- Allow multiple terraform roles to update the backup vault policy (#51)
- Configure the manual deletion control (#57)
- Consume directly from github (#57)
- Allow recent hashicorp/aws provider versions (#58)
- Add aurora support (#59)
- Add validation for destination and source name prefix variables (#62)

### Bug Fixes

- Correct completion_widow typo (#45)
- Don't error on missing `terraform_role_arn` (#65)
- Allow null `name_prefix` (#68)
- Selection tag defaults preserved (#69)
- Correctly handle unset `terraform_role_arns` (#70, #73)

## [v1.2.0] (2025-07-10)

### Features

- Document s3/dynamo terraform state, simplify example (#22)
- Update copyright year (#23)
- Add open source collateral (#24)
- Add a CODEOWNERS file (#27)
- Allow arbitrary tags when selecting resources for backup (#33)
- namespace resources to allow more than one vault per source account (#34)
- EBS support (#39)
- Add completion window option to the backup plan (#41)

### Bug Fixes

- Resolved SNS notification KMS permissions for AWS Backup service role (#29)
- Give rights for AWSServiceRoleForBackupReports to write to the report bucket (#28)
- Specify terraform and provider minimum versions (#34)
- Reduce churn in report plans (#38)
- Grant KMS permissions for RDS cross-account copies (#40)
- Fixed cyclic KMS key policy by using wildcard resource scoping (#44)
- Reduce backup policy churn from temporary roles (#47)

## [v1.1.0] (2024-09-26)

### Features

- Complete module renaming (`modules/source` → `modules/aws-backup-source`, etc.) for clarity
- Added fully worked example with passed-in resources in `examples/aws-backups.tf`
- Added S3 bucket versioning requirements documentation

- ### Bug Fixes

- Removed v1.1.0 signposts from documentation
- Fixed cyclic KMS key policy issue

### Documentation

- Major README.md rewrite with clearer structure and usage instruction
- Added detailed backup/restore testing guidance and procedural notes

## v1.0.0

Initial prerelease. Not for direct consumption.
