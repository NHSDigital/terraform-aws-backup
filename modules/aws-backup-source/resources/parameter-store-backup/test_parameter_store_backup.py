import unittest
from unittest.mock import patch, MagicMock
import os
from parameter_store_backup import load_configuration, discover_parameters, process_and_backup_parameter

class TestParameterStoreBackup(unittest.TestCase):

    @patch.dict(os.environ, {
        'KMS_KEY_ARN': 'test-kms-key',
        'PARAMETER_STORE_BUCKET_NAME': 'test-bucket',
        'TAG_KEY': 'test-key',
        'TAG_VALUE': 'test-value'
    })
    def test_load_configuration(self):
        config = load_configuration()
        self.assertEqual(config['kms_key_id'], 'test-kms-key')
        self.assertEqual(config['s3_bucket_name'], 'test-bucket')
        self.assertEqual(config['tag_key'], 'test-key')
        self.assertEqual(config['tag_value'], 'test-value')

    @patch('boto3.client')
    def test_discover_parameters(self, mock_boto_client):
        mock_ssm_client = MagicMock()
        mock_ssm_client.describe_parameters.return_value = {
            'Parameters': [{'Name': 'param1'}, {'Name': 'param2'}],
            'NextToken': ''
        }
        mock_boto_client.return_value = mock_ssm_client

        parameters = discover_parameters(mock_ssm_client, 'test-key', 'test-value')
        self.assertEqual(parameters, ['param1', 'param2'])
        mock_ssm_client.describe_parameters.assert_called_once()

    @patch('boto3.client')
    def test_process_and_backup_parameter_success(self, mock_boto_client):
        mock_ssm_client = MagicMock()
        mock_kms_client = MagicMock()
        mock_s3_client = MagicMock()

        mock_ssm_client.get_parameter.return_value = {
            'Parameter': {
                'Name': 'param1',
                'Type': 'String',
                'Value': 'test-value'
            }
        }
        mock_ssm_client.list_tags_for_resource.return_value = {'TagList': []}
        mock_kms_client.encrypt.return_value = {'CiphertextBlob': b'encrypted-data'}

        result = process_and_backup_parameter(
            mock_ssm_client,
            mock_kms_client,
            mock_s3_client,
            'param1',
            'test-kms-key',
            'test-bucket'
        )

        self.assertEqual(result['status'], 'SUCCESS')
        self.assertEqual(result['parameter_name'], 'param1')
        mock_ssm_client.get_parameter.assert_called_once_with(Name='param1', WithDecryption=True)
        mock_kms_client.encrypt.assert_called_once()
        mock_s3_client.put_object.assert_called_once()

    @patch('boto3.client')
    def test_process_and_backup_parameter_failure(self, mock_boto_client):
        mock_ssm_client = MagicMock()
        mock_kms_client = MagicMock()
        mock_s3_client = MagicMock()

        mock_ssm_client.get_parameter.side_effect = Exception("SSM error")

        result = process_and_backup_parameter(
            mock_ssm_client,
            mock_kms_client,
            mock_s3_client,
            'param1',
            'test-kms-key',
            'test-bucket'
        )

        self.assertEqual(result['status'], 'FAILED')
        self.assertIn('error', result)
        mock_ssm_client.get_parameter.assert_called_once_with(Name='param1', WithDecryption=True)


if __name__ == '__main__':
    unittest.main()
