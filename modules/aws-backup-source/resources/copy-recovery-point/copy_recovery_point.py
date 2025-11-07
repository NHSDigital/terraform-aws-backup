import os
import logging
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

backup_client = boto3.client("backup")

TERMINAL_STATES = {"COMPLETED", "FAILED", "ABORTED"}


def _parse_vault_name(vault_arn: str) -> str:
    # arn:aws:backup:region:account:backup-vault:VaultName
    try:
        return vault_arn.split(":backup-vault:")[-1]
    except Exception:
        raise ValueError("Unable to parse backup vault name from ARN")


def _start_copy_job(recovery_point_arn: str, source_vault_arn: str, assume_role_arn: str | None, context) -> dict:
    request_params = {
        "RecoveryPointArn": recovery_point_arn,
        "DestinationBackupVaultArn": source_vault_arn,
        "SourceBackupVaultName": _parse_vault_name(os.environ.get("DESTINATION_VAULT_ARN")),
        "IamRoleArn": assume_role_arn if assume_role_arn else os.environ.get("ASSUME_ROLE_ARN") or "",
        "IdempotencyToken": context.aws_request_id,
    }
    if not request_params["IamRoleArn"]:
        request_params.pop("IamRoleArn")  # If role not required/remove empty

    try:
        resp = backup_client.start_copy_job(**request_params)
        return {
            "copy_job_id": resp.get("CopyJobId"),
            "creation_date": resp.get("CreationDate"),
            "is_parent": resp.get("IsParent"),
        }
    except ClientError as e:
        logger.error(f"Failed to start copy job: {e}")
        raise


def _describe_copy_job(copy_job_id: str) -> dict:
    try:
        resp = backup_client.describe_copy_job(CopyJobId=copy_job_id)
        cj = resp.get("CopyJob", {})
        return {
            "copy_job_id": cj.get("CopyJobId"),
            "state": cj.get("State"),
            "status_message": cj.get("StatusMessage"),
            "source_recovery_point_arn": cj.get("SourceRecoveryPointArn"),
            "destination_recovery_point_arn": cj.get("DestinationRecoveryPointArn"),
            "completion_date": cj.get("CompletionDate"),
        }
    except ClientError as e:
        logger.error(f"Failed to describe copy job {copy_job_id}: {e}")
        raise


def lambda_handler(event, context):
    recovery_point_arn = event.get("recovery_point_arn")
    copy_job_id = event.get("copy_job_id")

    destination_vault_arn = os.environ.get("DESTINATION_VAULT_ARN")
    source_vault_arn = os.environ.get("SOURCE_VAULT_ARN")
    assume_role_arn = os.environ.get("ASSUME_ROLE_ARN") or None

    if copy_job_id:
        try:
            details = _describe_copy_job(copy_job_id)
            return {
                "statusCode": 200,
                "body": details,
            }
        except Exception as e:
            return {
                "statusCode": 500,
                "body": {"message": f"Error describing copy job: {str(e)}"},
            }

    if not recovery_point_arn:
        return {
            "statusCode": 400,
            "body": {"message": "Missing recovery_point_arn for starting a copy job"},
        }

    try:
        start_details = _start_copy_job(recovery_point_arn, source_vault_arn, assume_role_arn, context)
        description = _describe_copy_job(start_details["copy_job_id"])  # Immediate status snapshot
        return {
            "statusCode": 200,
            "body": {
                "message": "Copy job started",
                "copy_job": description,
            },
        }
    except Exception as e:
        return {"statusCode": 500, "body": {"message": f"Failed to start copy job: {str(e)}"}}
