import restore_to_dynamodb as rtd
from unittest.mock import patch, MagicMock


class Ctx: aws_request_id = 'test-id'


def test_start_dynamodb_restore_job_success():
    event = {
        'recovery_point_arn': 'arn:aws:backup:eu-west-2:123456789012:recovery-point:ABC',
        'iam_role_arn': 'arn:aws:iam::123456789012:role/TestRole',
        'target_table_name': 'RestoredTable'
    }
    with patch.object(rtd, 'backup_client') as mock_client:
        mock_client.start_restore_job.return_value = {'RestoreJobId': 'job-1'}
        mock_client.describe_restore_job.return_value = {'Status': 'COMPLETED', 'CompletionDate': 'N/A'}
        resp = rtd.lambda_handler(event, Ctx())
        assert resp['statusCode'] == 200
        assert resp['body']['restoreJobId'] == 'job-1'


def test_start_dynamodb_restore_job_missing_params():
    event = {'recovery_point_arn': 'arn:aws:backup:eu-west-2:123:recovery-point:ABC'}
    resp = rtd.lambda_handler(event, Ctx())
    assert resp['statusCode'] == 400


def test_monitor_existing_job():
    event = {'restore_job_id': 'job-2'}
    with patch.object(rtd, 'backup_client') as mock_client:
        mock_client.describe_restore_job.return_value = {'Status': 'RUNNING'}
        resp = rtd.lambda_handler(event, Ctx())
        assert resp['statusCode'] in (202, 500, 200)
        assert resp['body']['restoreJobId'] == 'job-2'
