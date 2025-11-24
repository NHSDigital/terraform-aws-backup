import os
import unittest
from unittest.mock import patch
import restore_to_rds as rds


class TestRestoreToRDS(unittest.TestCase):

        @patch.dict(os.environ, {
            'IAM_ROLE_ARN': 'arn:aws:iam::123456789012:role/BackupRole',
            'POLL_INTERVAL_SECONDS': '1',
            'MAX_WAIT_MINUTES': '0'
        })
        @patch.object(rds, 'backup_client')
        @patch.object(rds, 'sts_client')
        def test_start_restore_success(self, mock_sts, mock_backup):
            mock_sts.get_caller_identity.return_value = {'Account': '123456789012'}
            mock_backup.describe_restore_job.return_value = {
                'Status': 'COMPLETED',
                'PercentDone': '100.00%',
                'CompletionDate': rds.time.gmtime()
            }
            mock_backup.start_restore_job.return_value = {'RestoreJobId': 'job-123'}
            event = {
                'recovery_point_arn': 'arn:aws:backup:eu-west-2:123456789012:recovery-point:ABC',
                'db_instance_identifier': 'restored-db'
            }
            context = type('ctx', (), {'aws_request_id': 'req-1'})
            resp = rds.lambda_handler(event, context)
            self.assertEqual(resp['statusCode'], 200)
            self.assertEqual(resp['body']['restoreJobId'], 'job-123')
            mock_backup.start_restore_job.assert_called_once()

        @patch.dict(os.environ, {
            'IAM_ROLE_ARN': 'arn:aws:iam::123456789012:role/BackupRole'
        })
        def test_missing_required_params(self):
            event = {'recovery_point_arn': 'arn:aws:backup:eu-west-2:123456789012:recovery-point:ABC'}
            context = type('ctx', (), {'aws_request_id': 'req-2'})
            resp = rds.lambda_handler(event, context)
            self.assertEqual(resp['statusCode'], 400)

        @patch.dict(os.environ, {
            'POLL_INTERVAL_SECONDS': '30',
            'MAX_WAIT_MINUTES': '10'
        })
        def test_missing_iam_role_env(self):
            event = {
                'recovery_point_arn': 'arn:aws:backup:eu-west-2:123456789012:recovery-point:ABC',
                'db_instance_identifier': 'restored-db'
            }
            context = type('ctx', (), {'aws_request_id': 'req-3'})
            resp = rds.lambda_handler(event, context)
            self.assertEqual(resp['statusCode'], 500)
            self.assertIn('IAM_ROLE_ARN', resp['body']['message'])

        @patch.dict(os.environ, {
            'IAM_ROLE_ARN': 'arn:aws:iam::123456789012:role/BackupRole'
        })
        @patch.object(rds, 'sts_client')
        def test_cross_account_blocked(self, mock_sts):
            mock_sts.get_caller_identity.return_value = {'Account': '999999999999'}
            event = {
                'recovery_point_arn': 'arn:aws:backup:eu-west-2:123456789012:recovery-point:ABC',
                'db_instance_identifier': 'restored-db'
            }
            context = type('ctx', (), {'aws_request_id': 'req-4'})
            resp = rds.lambda_handler(event, context)
            self.assertEqual(resp['statusCode'], 400)
            self.assertIn('recovery_point_account', resp['body'])

        @patch.dict(os.environ, {
            'IAM_ROLE_ARN': 'arn:aws:iam::123456789012:role/BackupRole',
            'POLL_INTERVAL_SECONDS': '1',
            'MAX_WAIT_MINUTES': '0'
        })
        @patch.object(rds, 'backup_client')
        @patch.object(rds, 'sts_client')
        def test_copy_source_tags_flag(self, mock_sts, mock_backup):
            mock_sts.get_caller_identity.return_value = {'Account': '123456789012'}
            mock_backup.describe_restore_job.return_value = {
                'Status': 'COMPLETED',
                'PercentDone': '100.00%',
                'CompletionDate': rds.time.gmtime()
            }
            mock_backup.start_restore_job.return_value = {'RestoreJobId': 'job-456'}
            event = {
                'recovery_point_arn': 'arn:aws:backup:eu-west-2:123456789012:recovery-point:DEF',
                'db_instance_identifier': 'restored-db-2',
                'copy_source_tags_to_restored_resource': True
            }
            context = type('ctx', (), {'aws_request_id': 'req-5'})
            resp = rds.lambda_handler(event, context)
            self.assertEqual(resp['statusCode'], 200)
            called_args = mock_backup.start_restore_job.call_args[1]
            self.assertTrue(called_args.get('CopySourceTagsToRestoredResource'))

if __name__ == '__main__':
    unittest.main()
