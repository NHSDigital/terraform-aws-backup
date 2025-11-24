"""Lambda to start or monitor an AWS Backup RDS restore job.

Modes:
1. START: event supplies recovery_point_arn + db_instance_identifier (+ optional metadata) → starts restore.
2. MONITOR: event supplies restore_job_id → polls until terminal state or timeout.

Parallels restore_to_s3 implementation for consistency (env-driven IAM role, polling loop, unified response).
"""
import os
import logging
import boto3
import time
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

backup_client = boto3.client('backup')
sts_client = boto3.client('sts')

FINAL_STATES = ['COMPLETED', 'FAILED', 'ABORTED']


def get_job_status(restore_job_id):
    try:
        job_details = backup_client.describe_restore_job(RestoreJobId=restore_job_id)
        return job_details['Status'], job_details
    except ClientError as e:
        logger.error(f"Error checking job status for {restore_job_id}: {e.response['Error']['Message']}")
        return 'FAILED', {'StatusMessage': f"API Error during status check: {e.response['Error']['Message']}"}
    except Exception as e:
        logger.error(f"Unexpected error checking job status: {str(e)}")
        return 'FAILED', {'StatusMessage': f"Unexpected error: {str(e)}"}


def wait_for_job(restore_job_id, wait_seconds, max_wait_minutes):
    max_checks = int((max_wait_minutes * 60) / wait_seconds)
    current_status = 'PENDING'
    logger.info(f"Polling restore job {restore_job_id} for up to {max_wait_minutes} minutes...")
    for i in range(max_checks):
        if current_status in FINAL_STATES:
            logger.info(f"Job reached final status: {current_status}")
            break
        if i > 0:
            logger.info(f"Waiting {wait_seconds} seconds... (Check {i + 1}/{max_checks})")
            time.sleep(wait_seconds)
        current_status, job_details = get_job_status(restore_job_id)
        percent_done = job_details.get('PercentDone', '0.00%')
        logger.info(f"Current Status: {current_status} ({percent_done} complete)")
    final_status, final_details = get_job_status(restore_job_id)
    return final_status, final_details


def lambda_handler(event, context):
    try:
        wait_seconds = int(os.environ.get('POLL_INTERVAL_SECONDS', '30'))
        max_wait_minutes = int(os.environ.get('MAX_WAIT_MINUTES', '10'))
    except ValueError:
        return {
            'statusCode': 400,
            'body': {'message': 'Config Error: POLL_INTERVAL_SECONDS or MAX_WAIT_MINUTES must be integers.'}
        }

    restore_job_id = event.get('restore_job_id')
    if restore_job_id:
        logger.info(f"Mode: MONITOR - Tracking existing restore job: {restore_job_id}")
        final_status, final_details = wait_for_job(restore_job_id, wait_seconds, max_wait_minutes)
        return _format_response(restore_job_id, final_status, final_details, max_wait_minutes)

    # Start new restore job
    logger.info(f"Mode: START - Initiating new RDS restore job. Event: {event}")
    recovery_point_arn = event.get('recovery_point_arn')
    iam_role_arn = os.environ.get('IAM_ROLE_ARN')
    db_instance_identifier = event.get('db_instance_identifier')
    db_instance_class = event.get('db_instance_class')
    db_subnet_group_name = event.get('db_subnet_group_name')
    vpc_security_group_ids = event.get('vpc_security_group_ids')
    restore_metadata_overrides = event.get('restore_metadata_overrides', {})

    if not all([recovery_point_arn, db_instance_identifier]):
        return {
            'statusCode': 400,
            'body': {'message': 'Missing required parameters: recovery_point_arn, db_instance_identifier.'}
        }
    if not iam_role_arn:
        return {
            'statusCode': 500,
            'body': {'message': 'Configuration error: IAM_ROLE_ARN environment variable not set.'}
        }

    # Enforce same-account restore (recovery point copy expected beforehand)
    try:
        if recovery_point_arn:
            rp_account_id = recovery_point_arn.split(':')[4]
            caller_account_id = sts_client.get_caller_identity()['Account']
            if rp_account_id != caller_account_id:
                return {
                    'statusCode': 400,
                    'body': {
                        'message': 'Recovery point account mismatch; copy to local vault via copy-recovery-point Lambda before RDS restore.',
                        'recovery_point_account': rp_account_id,
                        'lambda_account': caller_account_id
                    }
                }
    except Exception as e:
        logger.warning(f"Account validation skipped: {e}")

    # Build Metadata for RDS restore
    metadata = {
        'DBInstanceIdentifier': db_instance_identifier
    }
    if db_instance_class:
        metadata['DBInstanceClass'] = db_instance_class
    if db_subnet_group_name:
        metadata['DBSubnetGroupName'] = db_subnet_group_name
    if vpc_security_group_ids:
        if isinstance(vpc_security_group_ids, list):
            metadata['VpcSecurityGroupIds'] = ','.join(vpc_security_group_ids)
        else:
            metadata['VpcSecurityGroupIds'] = vpc_security_group_ids
    # Merge in any overrides
    metadata.update(restore_metadata_overrides)

    copy_source_tags = event.get('copy_source_tags_to_restored_resource', False)

    try:
        start_args = {
            'RecoveryPointArn': recovery_point_arn,
            'Metadata': metadata,
            'IamRoleArn': iam_role_arn,
            'IdempotencyToken': context.aws_request_id,
            'ResourceType': 'RDS'
        }
        if isinstance(copy_source_tags, bool) and copy_source_tags:
            start_args['CopySourceTagsToRestoredResource'] = True
        start_response = backup_client.start_restore_job(**start_args)
        restore_job_id = start_response['RestoreJobId']
        logger.info(f"Started RDS restore job: {restore_job_id}")
    except ClientError as e:
        error_message = f"Failed to start RDS restore job: {e.response['Error']['Message']}"
        logger.error(error_message, exc_info=True)
        return {'statusCode': 500, 'body': {'message': error_message}}

    final_status, final_details = wait_for_job(restore_job_id, wait_seconds, max_wait_minutes)
    return _format_response(restore_job_id, final_status, final_details, max_wait_minutes)

def _format_response(restore_job_id, final_status, final_details, max_wait_minutes):
    if final_status == 'COMPLETED':
        status_code = 200
        message = 'Restore job completed successfully.'
    elif final_status in ['FAILED', 'ABORTED']:
        status_code = 500
        message = f'Restore job failed/aborted. Message: {final_details.get("StatusMessage", "N/A")}'
    else:
        status_code = 202
        message = f'Restore job still running after max wait ({max_wait_minutes} mins). Final check status: {final_status}.'
    completion_raw = final_details.get('CompletionDate', 'N/A')
    if completion_raw == 'N/A':
        completion_formatted = 'N/A'
    else:
        completion_formatted = completion_raw.isoformat() if hasattr(completion_raw, 'isoformat') else str(completion_raw)
    return {
        'statusCode': status_code,
        'body': {
            'message': message,
            'restoreJobId': restore_job_id,
            'finalStatus': final_status,
            'completionDate': completion_formatted
        }
    }
