import json
import boto3
import logging
import os

# Initialize AWS Backup client and logger
backup_client = boto3.client('backup')
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Create a Secrets Manager client
region_name = os.environ.get('AWS_REGION')

aws_account_id = os.environ.get('aws_account_id')
backup_account_id = os.environ.get('backup_account_id')
backup_copy_vault_arn = os.environ.get('backup_copy_vault_arn')
backup_role_arn = os.environ.get('backup_role_arn')
destination_vault_retention_period = int(os.environ.get('destination_vault_retention_period'))

def lambda_handler(event, context):
    # Log the incoming event for debugging purposes
    logger.info(f"Received Event: {json.dumps(event)}")

    # Extract the recovery point ARN from the event
    recovery_point_arn = event['detail']['serviceEventDetails']['recoveryPointArn']
    source_vault_name = event['detail']['serviceEventDetails']['backupVaultName']
    logger.info(f"Detected new recovery point in vault {source_vault_name}: {recovery_point_arn}")

    # Start the copy job to the destination vault in another AWS account
    backup_client.start_copy_job(
        RecoveryPointArn=recovery_point_arn,
        SourceBackupVaultName=source_vault_name,
        DestinationBackupVaultArn=backup_copy_vault_arn,
        IamRoleArn=backup_role_arn,
        Lifecycle={
            'DeleteAfterDays': destination_vault_retention_period
        }
    )

    return {
        'statusCode': 200,
        'body': json.dumps('Copy job started successfully.')
    }
