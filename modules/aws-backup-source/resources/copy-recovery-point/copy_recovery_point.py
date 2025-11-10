import os
import logging
import boto3
import traceback
import time
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

backup_client = boto3.client("backup")

TERMINAL_STATES = {"COMPLETED", "FAILED", "ABORTED"}
WAIT_DELAY_SECONDS = 30  # single place to adjust the one-off wait introduced by event.wait


def _http_status_for_state(state: str) -> int:
    if state == "COMPLETED":
        return 200
    if state == "CREATED":
        return 201
    if state == "RUNNING":
        return 202
    if state in {"FAILED", "ABORTED"}:
        return 500
    return 202


def _parse_vault_name(vault_arn: str) -> str:
    # arn:aws:backup:region:account:backup-vault:VaultName
    try:
        return vault_arn.split(":backup-vault:")[-1]
    except Exception:
        raise ValueError("Unable to parse backup vault name from ARN")


def _build_copy_job_params(recovery_point_arn: str, source_vault_arn: str, destination_vault_arn: str, assume_role_arn: str | None, context) -> dict:
    return {
        "RecoveryPointArn": recovery_point_arn,
        "DestinationBackupVaultArn": source_vault_arn,
        "SourceBackupVaultName": _parse_vault_name(destination_vault_arn),
        "IdempotencyToken": context.aws_request_id,
        **({"IamRoleArn": assume_role_arn} if assume_role_arn else {})
    }


def _start_copy_job(request_params: dict) -> dict:
    logger.info(f"Starting copy job for recovery_point_arn={request_params.get('RecoveryPointArn')}")
    try:
        resp = backup_client.start_copy_job(**request_params)
        logger.info(f"Copy job started: {resp.get('CopyJobId')}")
        return {
            "copy_job_id": resp.get("CopyJobId"),
            "creation_date": resp.get("CreationDate"),
            "is_parent": resp.get("IsParent"),
        }
    except ClientError as e:
        logger.error(f"Failed to start copy job: {e}", exc_info=True)
        raise


def _describe_copy_job(copy_job_id: str) -> dict:
    logger.info(f"Describing copy job: {copy_job_id}")
    try:
        resp = backup_client.describe_copy_job(CopyJobId=copy_job_id)
        cj = resp.get("CopyJob", {})
        logger.info(f"Copy job state: {cj.get('State')}")
        return {
            "copy_job_id": cj.get("CopyJobId"),
            "state": cj.get("State"),
            "status_message": cj.get("StatusMessage"),
            "source_recovery_point_arn": cj.get("SourceRecoveryPointArn"),
            "destination_recovery_point_arn": cj.get("DestinationRecoveryPointArn"),
            "completion_date": cj.get("CompletionDate"),
        }
    except ClientError as e:
        logger.error(f"Failed to describe copy job {copy_job_id}: {e}", exc_info=True)
        raise


def lambda_handler(event, context):
    logger.info(f"Lambda invoked with event: {event}")
    recovery_point_arn = event.get("recovery_point_arn")
    copy_job_id = event.get("copy_job_id")

    destination_vault_arn = os.environ.get("DESTINATION_VAULT_ARN")
    source_vault_arn = os.environ.get("SOURCE_VAULT_ARN")
    assume_role_arn = os.environ.get("ASSUME_ROLE_ARN")

    wait_flag = bool(event.get("wait", False))

    if copy_job_id:
        try:
            if wait_flag:
                logger.info(f"Wait flag set; sleeping {WAIT_DELAY_SECONDS}s before polling copy job state")
                time.sleep(WAIT_DELAY_SECONDS)
            details = _describe_copy_job(copy_job_id)
            logger.info(f"Describe copy job result: {details}")
            status_code = _http_status_for_state(details.get("state"))
            return {
                "statusCode": status_code,
                "body": details,
            }
        except Exception as e:
            logger.error(f"Error describing copy job: {str(e)}", exc_info=True)
            return {
                "statusCode": 500,
                "body": {"message": f"Error describing copy job: {str(e)}"},
            }

    if not recovery_point_arn:
        logger.error("Missing recovery_point_arn for starting a copy job")
        return {
            "statusCode": 400,
            "body": {"message": "Missing recovery_point_arn for starting a copy job"},
        }

    try:
        params = _build_copy_job_params(recovery_point_arn, source_vault_arn, destination_vault_arn, assume_role_arn, context)
        start_details = _start_copy_job(params)
        if wait_flag:
            logger.info(f"Wait flag set; sleeping {WAIT_DELAY_SECONDS}s before first status describe after start")
            time.sleep(WAIT_DELAY_SECONDS)
        description = _describe_copy_job(start_details["copy_job_id"])  # Status snapshot after optional wait
        logger.info(f"Copy job started and described: {description}")
        status_code = _http_status_for_state(description.get("state"))
        return {
            "statusCode": status_code,
            "body": {
                "message": "Copy job started",
                "copy_job": description,
            },
        }
    except Exception as e:
        logger.error(f"Failed to start copy job: {str(e)}", exc_info=True)
        return {"statusCode": 500, "body": {"message": f"Failed to start copy job: {str(e)}"}}
