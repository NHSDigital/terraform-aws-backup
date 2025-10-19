import json
import logging
import boto3
import base64
from botocore.exceptions import ClientError

# Initialize AWS clients
ssm_client = boto3.client('ssm')
kms_client = boto3.client('kms')
s3_client = boto3.client('s3')


logger = logging.getLogger()


def lambda_handler(event, context):
    """
    Retrieves Parameter Store values filtered by a tag, including all metadata
    for a perfect restoration. It encrypts the data using KMS and stores
    the encrypted blob in an S3 bucket (one file per parameter).
    """

    try:
        kms_key_id = event['kms_key_id']
        s3_bucket_name = event['s3_bucket_name']
        tag_key = event['tag_key']
        tag_value = event['tag_value']
    except KeyError as e:
        logger.error(f"Error: Missing required input in event: {e}", exc_info=True)
        return {
            'statusCode': 400,
            'body': json.dumps(f"Missing required input: {e}")
        }

    logger.info(f"Searching for parameters with tag: {tag_key}={tag_value}")
    parameter_names = []
    next_token = None

    while True:
        try:
            response = ssm_client.describe_parameters(
                ParameterFilters=[
                    {
                        'Key': 'tag-key',
                        'Option': 'Equals',
                        'Values': [tag_key]
                    },
                    {
                        'Key': 'tag-value',
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
            return {'statusCode': 500, 'body': json.dumps(f"SSM Error: {e.response['Error']['Message']}")}

    logger.info(f"Found {len(parameter_names)} parameters: {parameter_names}")

    if not parameter_names:
        logger.info("No parameters found with the specified tag.")
        return {'statusCode': 200, 'body': json.dumps("No parameters found.")}

    # --- 3. Process and Backup Each Parameter ---
    backup_results = []

    for param_name in parameter_names:
        try:
            # 3a. Retrieve full parameter details (including value)
            param_response = ssm_client.get_parameter(
                Name=param_name,
                WithDecryption=True
            )
            parameter = param_response['Parameter']

            # 3b. Retrieve additional metadata for perfect restoration

            # Get Tags
            tag_response = ssm_client.list_tags_for_resource(
                ResourceType='Parameter',
                ResourceId=param_name
            )

            # Get Policies (e.g., Expiration, Tier)
            policies_list = []
            try:
                policy_response = ssm_client.get_parameter_policies(
                    ParameterName=param_name,
                    WithDecryption=True
                )
                policies_list = policy_response.get('Policies', [])
            except ClientError as e:
                logger.error(f"Error retrieving policies for {param_name}: {e}", exc_info=True)
                # 'ParameterNotFound' is the error code when NO policies are present.
                if e.response['Error']['Code'] == 'ParameterNotFound':
                    pass  # Policy does not exist, which is fine
                else:
                    raise  # Re-raise if it's a different error

            # Construct the complete parameter object for backup
            backup_data = {
                'Name': parameter['Name'],
                'Type': parameter['Type'],
                'Value': parameter['Value'],  # Decrypted value
                'KeyId': parameter.get('KeyId'),  # KMS Key ARN for SecureString
                'Description': parameter.get('Description'),
                'Tags': tag_response.get('TagList', []),
                'Tier': parameter.get('Tier'),  # Parameter Tier (Standard/Advanced)
                'Policies': policies_list,  # Parameter Policies (e.g., Expiration, Rotation)
            }

            # 3c. Encrypt the complete parameter data using the specified KMS Key
            plain_text_data = json.dumps(backup_data)

            encrypt_response = kms_client.encrypt(
                KeyId=kms_key_id,
                Plaintext=plain_text_data.encode('utf-8')
            )

            # The ciphertext blob is a binary type, base64 encode it for safe storage
            encrypted_data = base64.b64encode(encrypt_response['CiphertextBlob']).decode('utf-8')

            # The final content to store in S3 is the base64-encoded encrypted blob
            s3_file_content = encrypted_data

            # Create a safe S3 key from the parameter name (stripping leading '/' and replacing internal '/')
            s3_key = f"{param_name.lstrip('/').replace('/', '_')}.encrypted"

            # 3d. Store the encrypted data in S3
            s3_client.put_object(
                Bucket=s3_bucket_name,
                Key=s3_key,
                Body=s3_file_content
            )

            logger.info(f"Successfully backed up '{param_name}' to s3://{s3_bucket_name}/{s3_key}")
            backup_results.append({
                'parameter_name': param_name,
                's3_key': s3_key,
                'status': 'SUCCESS'
            })

        except ClientError as e:
            error_message = f"Error processing parameter '{param_name}': {e.response['Error']['Message']}"
            logger.error(error_message, exc_info=True)
            backup_results.append({
                'parameter_name': param_name,
                'status': 'FAILED',
                'error': error_message
            })
        except Exception as e:
            error_message = f"An unexpected error occurred for '{param_name}': {str(e)}"
            logger.error(error_message, exc_info=True)
            backup_results.append({
                'parameter_name': param_name,
                'status': 'FAILED',
                'error': error_message
            })

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Parameter backup process complete.',
            'results': backup_results
        })
    }
