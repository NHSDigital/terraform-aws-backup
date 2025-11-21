import os
import logging
import json
import boto3
import time
from botocore.exceptions import ClientError


logger = logging.getLogger(__name__)


backup_client = boto3.client('backup')


FINAL_STATES = [
    'COMPLETED',
    'FAILED',
    'ABORTED'
]


def get_job_status(restore_job_id):
    """
    Checks the status of the specified restore job ID.
    Returns: Tuple (status, job_details)
    """
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
    """
    Polls the AWS Backup service until the restore job reaches a final state
    or the maximum wait time is exceeded.
    """
    max_checks = int((max_wait_minutes * 60) / wait_seconds)
    current_status = 'PENDING'

    logger.info(f"Starting to poll job {restore_job_id} for max {max_wait_minutes} minutes...")

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
    """
    Handles two modes: Start a new restore job OR monitor an existing one.
    Then, it waits for the job to complete.
    """

    try:
        wait_seconds = int(os.environ.get('POLL_INTERVAL_SECONDS', '30'))
        max_wait_minutes = int(os.environ.get('MAX_WAIT_MINUTES', '10'))
    except ValueError:
        return {
            'statusCode': 400,
            'body': {
                'message': 'Config Error: POLL_INTERVAL_SECONDS or MAX_WAIT_MINUTES must be integers.'
            }
        }

    try:
        iam_role_arn = os.environ.get('IAM_ROLE_ARN')
    except Exception as e:
        return {
            'statusCode': 500,
            'body': {
                'message': f'Error retrieving IAM_ROLE_ARN from environment: {str(e)}'
            }
        }

    job_id_from_event = event.get('restore_job_id')

    destination_s3_bucket = event.get('destination_s3_bucket')
    recovery_point_arn = event.get('recovery_point_arn')
    resource_type = 'S3'

    if job_id_from_event:
        restore_job_id = job_id_from_event
        logger.info(f"Mode: MONITOR - Tracking existing job: {restore_job_id}")
    else:
        logger.info("Mode: START - Initiating new restore job.")

        if not all([destination_s3_bucket, recovery_point_arn]):
            return {
                'statusCode': 400,
                'body': {
                    'message': 'Missing required parameters for starting a new job (destination_s3_bucket, recovery_point_arn).'
                }
            }

        try:
            start_response = backup_client.start_restore_job(
                RecoveryPointArn=recovery_point_arn,
                Metadata={'DestinationBucketName': destination_s3_bucket},
                IamRoleArn=iam_role_arn,
                IdempotencyToken=context.aws_request_id,
                ResourceType=resource_type
            )
            restore_job_id = start_response['RestoreJobId']
            logger.info(f"Successfully started new restore job: {restore_job_id}")

        except ClientError as e:
            error_message = f"Failed to start restore job: {e.response['Error']['Message']}"
            logger.error(error_message, exc_info=True)
            return {
                'statusCode': 500,
                'body': {
                    'message': error_message
                }
            }

    final_status, final_details = wait_for_job(restore_job_id, wait_seconds, max_wait_minutes)

    if final_status == 'COMPLETED':
        status_code = 200
        message = 'Restore job completed successfully.'
    elif final_status in ['FAILED', 'ABORTED']:
        status_code = 500
        message = f'Restore job failed/aborted. Message: {final_details.get("StatusMessage", "N/A")}'
    else:
        status_code = 202
        message = f'Restore job still running after max wait ({max_wait_minutes} mins). Final check status: {final_status}.'

    return {
        'statusCode': status_code,
        'body': {
            'message': message,
            'restoreJobId': restore_job_id,
            'finalStatus': final_status,
            'completionDate': final_details.get(
                'CompletionDate',
                'N/A'
            ).isoformat() if 'CompletionDate' in final_details and final_details['CompletionDate'] != 'N/A' else 'N/A'
        }
    }
