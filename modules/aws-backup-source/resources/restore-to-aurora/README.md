# restore-to-aurora Lambda

Restores an Aurora cluster from an AWS Backup recovery point.

## Event Input

- `recovery_point_arn` (required): ARN of the Aurora recovery point
- `iam_role_arn` (required): IAM role ARN for restore
- `db_cluster_identifier` (required): New DB cluster identifier
- `db_subnet_group_name` (optional): Subnet group
- `vpc_security_group_ids` (optional): List of security group IDs
- `restore_metadata_overrides` (optional): Dict of additional/override metadata
- `restore_job_id` (optional): If present, polls status of this job

## Environment Variables

- `POLL_INTERVAL_SECONDS` (default: 30)
- `MAX_WAIT_MINUTES` (default: 15)

## Usage

- Start a restore: provide required fields
- Poll a job: provide `restore_job_id`

See module README for deployment and variable configuration.
