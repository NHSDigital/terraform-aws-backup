import unittest
import os
import uuid
from unittest.mock import patch, MagicMock
import importlib
from datetime import datetime

from botocore.stub import Stubber, ANY


class TestS3RestoreLambda(unittest.TestCase):

    def setUp(self):
        """Set up standard environment variables and event structure."""
        os.environ['MAX_WAIT_MINUTES'] = '1'
        os.environ['POLL_INTERVAL_SECONDS'] = '10'

        self.event_start_job = {
            'destination_s3_bucket': 'test-restore-bucket',
            'recovery_point_arn': 'arn:aws:backup:us-east-1:123456789012:recovery-point:rp-abcdefg12345',
            'iam_role_arn': 'arn:aws:iam::123456789012:role/TestRestoreRole'
        }

        self.patcher_sleep = patch('restore_to_s3.time.sleep', return_value=None)
        self.mock_sleep = self.patcher_sleep.start()

    def tearDown(self):
        """Clean up mocks and environment variables."""
        self.patcher_sleep.stop()
        if 'restore_job_id' in os.environ:
            del os.environ['restore_job_id']

    def _create_mock_context(self):
        """Creates a mock Lambda context object with a request ID."""
        context = MagicMock()
        context.aws_request_id = 'test-request-id-123'
        return context

    def _get_describe_job_response(self, job_id, status, percent):
        """Helper to create a standard describe_restore_job response. FIX: Returns datetime object."""
        return {
            'RestoreJobId': job_id,
            'Status': status,
            'PercentDone': percent,
            'CompletionDate': datetime.now()
        }

    def _get_describe_job_params(self, job_id):
        """Helper to create expected parameters for describe_restore_job."""
        return {'RestoreJobId': job_id}

    def _get_start_job_expected_params(self):
        """Helper to get FIXED expected parameters for start_restore_job."""
        return {
            'RecoveryPointArn': self.event_start_job['recovery_point_arn'],
            'IamRoleArn': self.event_start_job['iam_role_arn'],
            'ResourceType': 'S3',
            'IdempotencyToken': ANY,
            'Metadata': ANY
        }

    def test_start_job_and_completes_successfully(self):
        """Tests starting a new job that completes successfully."""
        rest_mod = importlib.import_module('restore_to_s3')
        importlib.reload(rest_mod)
        lambda_handler, backup_client = rest_mod.lambda_handler, rest_mod.backup_client

        stubber = Stubber(backup_client)
        restore_job_id = str(uuid.uuid4())

        stubber.add_response(
            'start_restore_job',
            {'RestoreJobId': restore_job_id},
            self._get_start_job_expected_params()
        )

        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'PENDING', '0.00%'),
                             self._get_describe_job_params(restore_job_id))
        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'RUNNING', '10.00%'),
                             self._get_describe_job_params(restore_job_id))
        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'RUNNING', '25.00%'),
                             self._get_describe_job_params(restore_job_id))
        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'RUNNING', '40.00%'),
                             self._get_describe_job_params(restore_job_id))
        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'RUNNING', '50.00%'),
                             self._get_describe_job_params(restore_job_id))
        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'RUNNING', '75.00%'),
                             self._get_describe_job_params(restore_job_id))
        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'COMPLETED', '100.00%'),
                             self._get_describe_job_params(restore_job_id))

        with stubber:
            response = lambda_handler(self.event_start_job, self._create_mock_context())
        stubber.deactivate()
        body = response['body']
        self.assertEqual(response['statusCode'], 200)
        self.assertEqual(body['restoreJobId'], restore_job_id)
        self.assertEqual(body['finalStatus'], 'COMPLETED')
        stubber.assert_no_pending_responses()

    def test_start_job_and_fails(self):
        """Tests starting a new job that runs and ultimately fails."""
        rest_mod = importlib.import_module('restore_to_s3')
        importlib.reload(rest_mod)
        lambda_handler, backup_client = rest_mod.lambda_handler, rest_mod.backup_client

        stubber = Stubber(backup_client)
        restore_job_id = str(uuid.uuid4())

        stubber.add_response('start_restore_job', {'RestoreJobId': restore_job_id},
                             self._get_start_job_expected_params())

        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'PENDING', '0.00%'),
                             self._get_describe_job_params(restore_job_id))
        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'FAILED', '10.00%'),
                             self._get_describe_job_params(restore_job_id))

        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'FAILED', '10.00%'),
                             self._get_describe_job_params(restore_job_id))

        with stubber:
            response = lambda_handler(self.event_start_job, self._create_mock_context())

        body = response['body']

        self.assertEqual(response['statusCode'], 500)
        self.assertEqual(body['restoreJobId'], restore_job_id)
        self.assertEqual(body['finalStatus'], 'FAILED')

    def test_monitor_existing_job_completes(self):
        """Tests monitoring an existing job until it completes."""
        rest_mod = importlib.import_module('restore_to_s3')
        importlib.reload(rest_mod)
        lambda_handler, backup_client = rest_mod.lambda_handler, rest_mod.backup_client

        stubber = Stubber(backup_client)
        restore_job_id = str(uuid.uuid4())
        event_monitor = {'restore_job_id': restore_job_id}

        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'RUNNING', '10.00%'),
                             self._get_describe_job_params(restore_job_id))
        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'RUNNING', '20.00%'),
                             self._get_describe_job_params(restore_job_id))
        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'RUNNING', '30.00%'),
                             self._get_describe_job_params(restore_job_id))
        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'RUNNING', '50.00%'),
                             self._get_describe_job_params(restore_job_id))
        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'RUNNING', '70.00%'),
                             self._get_describe_job_params(restore_job_id))
        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'RUNNING', '80.00%'),
                             self._get_describe_job_params(restore_job_id))
        stubber.add_response('describe_restore_job',
                             self._get_describe_job_response(restore_job_id, 'COMPLETED', '100.00%'),
                             self._get_describe_job_params(restore_job_id))

        with stubber:
            response = lambda_handler(event_monitor, self._create_mock_context())
        body = response['body']

        self.assertEqual(response['statusCode'], 200)
        self.assertEqual(body['restoreJobId'], restore_job_id)
        self.assertEqual(body['finalStatus'], 'COMPLETED')
        stubber.assert_no_pending_responses()

    def test_monitor_job_times_out(self):
        """Tests monitoring an existing job that hits the max wait time (1 minute / 60 polls)."""
        rest_mod = importlib.import_module('restore_to_s3')
        importlib.reload(rest_mod)
        lambda_handler, backup_client = rest_mod.lambda_handler, rest_mod.backup_client

        stubber = Stubber(backup_client)
        restore_job_id = str(uuid.uuid4())
        event_monitor = {'restore_job_id': restore_job_id}

        for i in range(10):
            stubber.add_response('describe_restore_job',
                                 self._get_describe_job_response(restore_job_id, 'RUNNING', f'{i * 10}%'),
                                 self._get_describe_job_params(restore_job_id))

        with stubber:
            response = lambda_handler(event_monitor, self._create_mock_context())

        body = response['body']

        self.assertEqual(response['statusCode'], 202)
        self.assertEqual(body['restoreJobId'], restore_job_id)
        self.assertEqual(body['finalStatus'], 'RUNNING')

    def test_start_job_missing_parameters(self):
        """Tests failing gracefully when required start parameters are missing."""
        rest_mod = importlib.import_module('restore_to_s3')
        importlib.reload(rest_mod)
        lambda_handler = rest_mod.lambda_handler

        event_missing = {
            'recovery_point_arn': 'arn:test',
            'iam_role_arn': 'arn:test'
        }

        response = lambda_handler(event_missing, self._create_mock_context())
        body = response['body']

        self.assertEqual(response['statusCode'], 400)
        self.assertIn('Missing required parameters', body['message'])

    def test_start_job_client_error(self):
        """Tests handling a ClientError when calling start_restore_job."""
        rest_mod = importlib.import_module('restore_to_s3')
        importlib.reload(rest_mod)
        lambda_handler, backup_client = rest_mod.lambda_handler, rest_mod.backup_client

        stubber = Stubber(backup_client)

        stubber.add_client_error(
            'start_restore_job',
            service_error_code='AccessDeniedException',
            service_message='Role cannot be assumed',
            http_status_code=403,
            expected_params=self._get_start_job_expected_params()
        )

        with stubber:
            response = lambda_handler(self.event_start_job, self._create_mock_context())

        body = response['body']

        self.assertEqual(response['statusCode'], 500)
        self.assertIn('Failed to start restore job', body['message'])
        self.assertIn('Role cannot be assumed', body['message'])
        self.assertNotIn('restoreJobId', body)


if __name__ == '__main__':
    unittest.main()
