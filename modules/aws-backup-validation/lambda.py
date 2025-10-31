import json
import os
import boto3
import hashlib

ssm = boto3.client('ssm')
backup = boto3.client('backup')
secrets = boto3.client('secretsmanager')
rds_data = boto3.client('rds-data')
dynamodb = boto3.client('dynamodb')
s3 = boto3.client('s3')

CONFIG_PARAM_NAME = os.environ.get('CONFIG_PARAM_NAME')

_cached_config = None

def load_config():
    global _cached_config
    if _cached_config is not None:
        return _cached_config
    if not CONFIG_PARAM_NAME:
        _cached_config = {}
        return _cached_config
    resp = ssm.get_parameter(Name=CONFIG_PARAM_NAME)
    _cached_config = json.loads(resp['Parameter']['Value'])
    return _cached_config

def handler(event, context):
    # Event expected from Step Functions state machine
    restore_job_id = event.get('detail', {}).get('restoreJobId') or event.get('restoreJobId')
    resource_type = event.get('detail', {}).get('resourceType') or event.get('resourceType')
    created_arn = event.get('detail', {}).get('createdResourceArn') or event.get('createdResourceArn')

    config = load_config()
    result = {"status": "SKIPPED", "message": f"No validator for {resource_type}"}

    try:
        if resource_type in ("RDS", "Aurora"):
            result = validate_rds_like(resource_type, created_arn, config.get('rds') or config.get('aurora'))
        elif resource_type == "DynamoDB":
            result = validate_dynamodb(created_arn, config.get('dynamodb'))
        elif resource_type == "S3":
            result = validate_s3(created_arn, config.get('s3'))
    except Exception as exc:  # noqa
        result = {"status": "FAILED", "message": f"Unhandled validator error: {exc}"}

    return result

def validate_rds_like(resource_type, arn, cfg):
    if not cfg or not cfg.get('sql_checks'):
        return {"status": "SKIPPED", "message": "No sql_checks configured"}
    failures = []
    for chk in cfg['sql_checks']:
        stmt = chk['statement']
        db = chk['database']
        # Placeholder: In real implementation we would look up secret and cluster endpoint
        try:
            # rds-data call would require secretArn + resourceArn for serverless Aurora or HTTP endpoint; omitted here
            pass
        except Exception as exc:  # noqa
            failures.append(f"{db}: {exc}")
    if failures:
        return {"status": "FAILED", "message": "; ".join(failures)[:1000]}
    return {"status": "SUCCESSFUL", "message": "All RDS/Aurora checks passed (placeholder)"}

def validate_dynamodb(arn, cfg):
    if not cfg or not cfg.get('tables'):
        return {"status": "SKIPPED", "message": "No dynamodb tables configured"}
    # Placeholder logic only
    return {"status": "SUCCESSFUL", "message": "DynamoDB validation placeholder"}

def validate_s3(arn, cfg):
    if not cfg or not cfg.get('buckets'):
        return {"status": "SKIPPED", "message": "No s3 buckets configured"}
    return {"status": "SUCCESSFUL", "message": "S3 validation placeholder"}
