# Changelog

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
