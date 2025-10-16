import os
import json
import urllib.request
import urllib.parse
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

API_ENDPOINT = os.environ.get('API_ENDPOINT')
MODULE_VERSION = os.environ.get('MODULE_VERSION')
AWS_ACCOUNT_ID = os.environ.get('AWS_ACCOUNT_ID')
API_TOKEN = os.environ.get('API_TOKEN')


def lambda_handler(event, context):
    """
    Handles events from AWS EventBridge (triggered by AWS Backup job completion).
    It sends the module version information via HTTP POST to a configured API endpoint.

    Args:
        event (dict): The EventBridge event data, including AWS Backup job details.
        context (object): Lambda context runtime information.
    """
    logger.info(f"Received Event: {json.dumps(event)}")

    if not API_ENDPOINT or not MODULE_VERSION:
        logger.error("Configuration error: API_ENDPOINT or MODULE_VERSION environment variables are missing.")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'Configuration error.'})
        }

    payload = {
        "version": MODULE_VERSION,
        "awsAccount": AWS_ACCOUNT_ID
    }

    data = json.dumps(payload).encode('utf-8')
    headers = {
        'Content-Type': 'application/json',
        'Authorization': API_TOKEN
    }

    try:
        req = urllib.request.Request(API_ENDPOINT, data=data, headers=headers, method='POST')

        with urllib.request.urlopen(req) as response:
            response_body = response.read().decode('utf-8')
            logger.info(f"API Response Status: {response.status}")
            logger.info(f"API Response Body: {response_body}")

            if 200 <= response.status < 300:
                logger.info("Successfully posted module version.")
            else:
                raise Exception(f"API call failed with status: {response.status}")

        return {
            'statusCode': response.status,
            'body': json.dumps({'message': 'Version posted successfully.'})
        }

    except urllib.error.HTTPError as e:
        logger.error(f"HTTP Error posting version: {e.code} - {e.reason}")
        return {
            'statusCode': e.code,
            'body': json.dumps({'message': f'HTTP Error: {e.reason}'})
        }
    except urllib.error.URLError as e:
        logger.error(f"URL Error posting version (e.g., DNS failure, refused connection): {e.reason}")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': f'URL Error: {e.reason}'})
        }
    except Exception as e:
        logger.error(f"An unexpected error occurred during execution: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': f'Unexpected Error: {str(e)}'})
        }
