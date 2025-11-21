# Lambda Restore to S3

Facilitates restoring AWS Backup backed-up data to an S3 bucket.

The lambda function is designed to handle two main operations:

1. Initiating a restore job to an S3 bucket using a specified recovery point ARN.
2. Checking the status of an existing restore job using its job ID.

The lambda function will wait for the restore job to complete and return the final status after waiting for a period of time or if the restore job finishes.

## Event Contract

There are 2 entry points for this Lambda function:

The first is when to trigger a restore job.

```json
{
  "destination_s3_bucket": "...",
  "recovery_point_arn": "...",
  "iam_role_arn": "..."
}
```

The second is to trigger a status check on an existing restore job.

```json
{
  "restore_job_id": "..."
}
```

## Local Development

To run locally you would need to set up your environment with the necessary AWS credentials and permissions.
The python environment would also need to have boto3 installed.

## Run tests

To run the tests for this module, you can use the following command:

```bash
python test_restore_to_s3.py
```
