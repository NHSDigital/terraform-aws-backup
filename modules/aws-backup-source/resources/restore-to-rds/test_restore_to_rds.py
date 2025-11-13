import unittest
import os
import uuid
from unittest.mock import patch, MagicMock
import importlib
from datetime import datetime
from botocore.stub import Stubber, ANY

class TestRDSRestoreLambda(unittest.TestCase):
    def setUp(self):
        os.environ['MAX_WAIT_MINUTES'] = '1'
        os.environ['POLL_INTERVAL_SECONDS'] = '1'
        self.event_start_job = {
            'recovery_point_arn': 'arn:aws:backup:us-east-1:123456789012:recovery-point:rp-abcdefg12345',
            'iam_role_arn': 'arn:aws:iam::123456789012:role/TestRestoreRole',
            'db_instance_identifier': 'test-restore-db'
        }
        self.patcher_sleep = patch('restore_to_rds.time.sleep', return_value=None)
        self.mock_sleep = self.patcher_sleep.start()
    def tearDown(self):
        self.patcher_sleep.stop()
    def _create_mock_context(self):
        context = MagicMock()
        context.aws_request_id = 'test-request-id-123'
        return context
    def _get_describe_job_response(self, job_id, status, percent):
        return {
            'RestoreJobId': job_id,
            'Status': status,
            'PercentDone': percent,
            'CompletionDate': datetime.now()
        }
    def _get_describe_job_params(self, job_id):
        return {'RestoreJobId': job_id}
    def _get_start_job_expected_params(self):
        return {
            'RecoveryPointArn': self.event_start_job['recovery_point_arn'],
            'IamRoleArn': self.event_start_job['iam_role_arn'],
            'ResourceType': 'RDS',
            'IdempotencyToken': ANY,
            'Metadata': ANY
        }
    def test_start_job_and_completes_successfully(self):
        rest_mod = importlib.import_module('restore_to_rds')
        importlib.reload(rest_mod)
        lambda_handler, backup_client = rest_mod.lambda_handler, rest_mod.backup_client
        stubber = Stubber(backup_client)
        restore_job_id = str(uuid.uuid4())
        stubber.add_response('start_restore_job', {'RestoreJobId': restore_job_id}, self._get_start_job_expected_params())
        # Add two describe_restore_job responses to match polling logic
        stubber.add_response('describe_restore_job', self._get_describe_job_response(restore_job_id, 'COMPLETED', '100.00%'), self._get_describe_job_params(restore_job_id))
        stubber.add_response('describe_restore_job', self._get_describe_job_response(restore_job_id, 'COMPLETED', '100.00%'), self._get_describe_job_params(restore_job_id))
        with stubber:
            response = lambda_handler(self.event_start_job, self._create_mock_context())
        body = response['body']
        self.assertEqual(response['statusCode'], 200)
        self.assertEqual(body['restoreJobId'], restore_job_id)
        self.assertEqual(body['finalStatus'], 'COMPLETED')
        stubber.assert_no_pending_responses()
    def test_start_job_missing_parameters(self):
        rest_mod = importlib.import_module('restore_to_rds')
        importlib.reload(rest_mod)
        lambda_handler = rest_mod.lambda_handler
        event_missing = {'recovery_point_arn': 'arn:test'}
        response = lambda_handler(event_missing, self._create_mock_context())
        body = response['body']
        self.assertEqual(response['statusCode'], 400)
        self.assertIn('Missing required parameters', body['message'])
if __name__ == '__main__':
    unittest.main()
