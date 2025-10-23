import os
import json
import base64
import logging
import boto3
from botocore.exceptions import ClientError


logger = logging.getLogger()
logger.setLevel(logging.INFO)


def load_configuration():
    """Reads and validates environment variables."""
    try:
        config = {
            'kms_key_id': os.environ['KMS_KEY_ARN'],
            's3_bucket_name': os.environ['PARAMETER_STORE_BUCKET_NAME'],
            'tag_key': os.environ['TAG_KEY'],
            'tag_value': os.environ['TAG_VALUE']
        }
        return config
    except KeyError as e:
        logger.error(f"Error: Missing required env vars: {e}", exc_info=True)
        raise ValueError(f"Missing required env vars: {e}")


def discover_parameters(ssm_client, tag_key, tag_value):
    """Paginates through SSM to find all parameter names matching the tag."""
    logger.info(f"Searching for parameters with tag: {tag_key}={tag_value}")
    parameter_names = []
    next_token = ''

    while True:
        try:
            response = ssm_client.describe_parameters(
                ParameterFilters=[
                    {
                        'Key': f'tag:{tag_key}',
                        'Option': 'Equals',
                        'Values': [tag_value]
                    }
                ],
                MaxResults=50,
                NextToken=next_token
            )

            for parameter in response.get('Parameters', []):
                parameter_names.append(parameter['Name'])

            next_token = response.get('NextToken')
            if not next_token:
                break

        except ClientError as e:
            logger.error(f"Error listing parameters: {e}", exc_info=True)
            raise ClientError(e.response, 'DescribeParameters')

    logger.info(f"Found {len(parameter_names)} parameters: {parameter_names}")
    return parameter_names


def process_and_backup_parameter(ssm_client, kms_client, s3_client, param_name, kms_key_id, s3_bucket_name):
    """
    Retrieves, encrypts, and stores a single parameter's complete metadata and value.
    Returns a result dict for tracking success/failure.
    """
    try:
        param_response = ssm_client.get_parameter(
            Name=param_name,
            WithDecryption=True
        )
        parameter = param_response['Parameter']

        tag_response = ssm_client.list_tags_for_resource(
            ResourceType='Parameter',
            ResourceId=param_name
        )

        backup_data = {
            'Name': parameter['Name'],
            'Type': parameter['Type'],
            'Value': parameter['Value'],  # Decrypted value
            'KeyId': parameter.get('KeyId'),
            'Description': parameter.get('Description'),
            'Tags': tag_response.get('TagList', []),
            'Tier': parameter.get('Tier'),
            'Policies': param_response.get('Policies', []),
            'DataType': parameter.get('DataType')
        }

        plain_text_data = json.dumps(backup_data)

        encrypt_response = kms_client.encrypt(
            KeyId=kms_key_id,
            Plaintext=plain_text_data.encode('utf-8')
        )

        encrypted_data_b64 = base64.b64encode(encrypt_response['CiphertextBlob']).decode('utf-8')

        s3_key = f"{param_name.lstrip('/').replace('/', '_')}.encrypted"

        s3_client.put_object(
            Bucket=s3_bucket_name,
            Key=s3_key,
            Body=encrypted_data_b64
        )

        logger.info(f"Successfully backed up '{param_name}' to s3://{s3_bucket_name}/{s3_key}")
        return {
            'parameter_name': param_name,
            's3_key': s3_key,
            'status': 'SUCCESS'
        }

    except ClientError as e:
        error_message = f"Error processing parameter '{param_name}': {e.response['Error']['Message']}"
        logger.error(error_message, exc_info=True)
        return {
            'parameter_name': param_name,
            'status': 'FAILED',
            'error': error_message
        }
    except Exception as e:
        error_message = f"An unexpected error occurred for '{param_name}': {str(e)}"
        logger.error(error_message, exc_info=True)
        return {
            'parameter_name': param_name,
            'status': 'FAILED',
            'error': error_message
        }


def lambda_handler(event, context):
    """
    The main handler. Coordinates configuration loading, parameter discovery,
    and backup processing.
    """
    backup_results = []

    ssm_client = boto3.client('ssm')
    kms_client = boto3.client('kms')
    s3_client = boto3.client('s3')

    try:
        config = load_configuration()

        parameter_names = discover_parameters(
            ssm_client,
            config['tag_key'],
            config['tag_value']
        )

        if not parameter_names:
            logger.info("No parameters found with the specified tag.")
            return {'statusCode': 200, 'body': json.dumps("No parameters found.")}

        for param_name in parameter_names:
            result = process_and_backup_parameter(
                ssm_client,
                kms_client,
                s3_client,
                param_name,
                config['kms_key_id'],
                config['s3_bucket_name']
            )
            backup_results.append(result)

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Parameter backup process complete.',
                'results': backup_results
            })
        }

    except ValueError as e:
        return {
            'statusCode': 400,
            'body': json.dumps(str(e))
        }
    except ClientError as e:
        return {
            'statusCode': 500,
            'body': json.dumps(f"SSM Error during discovery: {e.response['Error']['Message']}")
        }
    except Exception as e:
        logger.error(f"Unexpected error in handler: {e}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps(f"An unexpected error occurred: {str(e)}")
        }
