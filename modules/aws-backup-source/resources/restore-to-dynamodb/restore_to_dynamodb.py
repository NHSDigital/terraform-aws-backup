import os
import logging
import boto3
import time
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

backup_client = boto3.client('backup')

FINAL_STATES = ['COMPLETED', 'FAILED', 'ABORTED']


def _get_status(restore_job_id):
    try:
        details = backup_client.describe_restore_job(RestoreJobId=restore_job_id)
        return details.get('Status'), details
    except ClientError as e:
        logger.error(f"Error describing DynamoDB restore job {restore_job_id}: {e.response['Error']['Message']}")
        return 'FAILED', {'StatusMessage': f"API Error: {e.response['Error']['Message']}"}
    except Exception as e:
        logger.error(f"Unexpected error describing DynamoDB restore job {restore_job_id}: {str(e)}")
        return 'FAILED', {'StatusMessage': f"Unexpected error: {str(e)}"}


def _poll(restore_job_id, wait_seconds, max_wait_minutes):
    max_checks = int((max_wait_minutes * 60) / wait_seconds)
    status = 'PENDING'
    logger.info(f"Polling DynamoDB restore job {restore_job_id} up to {max_wait_minutes} minutes")
    for i in range(max_checks):
        if status in FINAL_STATES:
            break
        if i > 0:
            time.sleep(wait_seconds)
        status, details = _get_status(restore_job_id)
        logger.info(f"Status check {i+1}/{max_checks}: {status} ({details.get('PercentDone','0.00%')})")
    return _get_status(restore_job_id)


def lambda_handler(event, context):
    try:
        wait_seconds = int(os.environ.get('POLL_INTERVAL_SECONDS', '30'))
        max_wait_minutes = int(os.environ.get('MAX_WAIT_MINUTES', '10'))
    except ValueError:
        return {'statusCode': 400, 'body': {'message': 'Config Error: POLL_INTERVAL_SECONDS or MAX_WAIT_MINUTES must be integers.'}}

    restore_job_id = event.get('restore_job_id')
    if restore_job_id:
        logger.info(f"Mode: MONITOR DynamoDB restore job {restore_job_id}")
        final_status, final_details = _poll(restore_job_id, wait_seconds, max_wait_minutes)
        return _format_response(restore_job_id, final_status, final_details, max_wait_minutes)

    logger.info(f"Mode: START DynamoDB restore job. Event: {event}")
    recovery_point_arn = event.get('recovery_point_arn')
    iam_role_arn = event.get('iam_role_arn')
    target_table_name = event.get('target_table_name')
    restore_metadata_overrides = event.get('restore_metadata_overrides', {})
    copy_source_tags = bool(event.get('copy_source_tags', False))

    if not all([recovery_point_arn, iam_role_arn, target_table_name]):
        return {'statusCode': 400, 'body': {'message': 'Missing required parameters: recovery_point_arn, iam_role_arn, target_table_name.'}}

    metadata = {
        'targetTableName': target_table_name
    }
    metadata.update(restore_metadata_overrides)

    try:
        start_resp = backup_client.start_restore_job(
            RecoveryPointArn=recovery_point_arn,
            Metadata=metadata,
            IamRoleArn=iam_role_arn,
            IdempotencyToken=context.aws_request_id,
            ResourceType='DynamoDB',
            **({'CopySourceTagsToRestoredResource': True} if copy_source_tags else {})
        )
        restore_job_id = start_resp['RestoreJobId']
        logger.info(f"Started DynamoDB restore job {restore_job_id}")
    except ClientError as e:
        msg = f"Failed to start DynamoDB restore job: {e.response['Error']['Message']}"
        logger.error(msg, exc_info=True)
        return {'statusCode': 500, 'body': {'message': msg}}

    final_status, final_details = _poll(restore_job_id, wait_seconds, max_wait_minutes)
    return _format_response(restore_job_id, final_status, final_details, max_wait_minutes)


def _format_response(restore_job_id, final_status, final_details, max_wait_minutes):
    if final_status == 'COMPLETED':
        status_code = 200
        message = 'Restore job completed successfully.'
    elif final_status in ['FAILED', 'ABORTED']:
        status_code = 500
        message = f"Restore job failed/aborted. Message: {final_details.get('StatusMessage', 'N/A')}"
    else:
        status_code = 202
        message = f"Restore job still running after max wait ({max_wait_minutes} mins). Final check status: {final_status}."
    completion_date = final_details.get('CompletionDate', 'N/A')
    if completion_date != 'N/A' and hasattr(completion_date, 'isoformat'):
        completion_date = completion_date.isoformat()
    return {
        'statusCode': status_code,
        'body': {
            'message': message,
            'restoreJobId': restore_job_id,
            'finalStatus': final_status,
            'completionDate': completion_date
        }
    }
