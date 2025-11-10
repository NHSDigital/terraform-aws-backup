import copy_recovery_point as crp
from unittest.mock import patch, MagicMock

class Ctx: aws_request_id = 'test-id'

def test_start_copy_job_with_arn():
    event = {"recovery_point_id": "arn:aws:backup:eu-west-2:123456789012:recovery-point:ABC"}
    with patch.object(crp, 'backup_client') as mock_client:
        mock_client.start_copy_job.return_value = {"CopyJobId": "job-1", "CreationDate": 0, "IsParent": False}
        mock_client.describe_copy_job.return_value = {"CopyJob": {"CopyJobId": "job-1", "State": "CREATED"}}
        resp = crp.lambda_handler(event, Ctx())
        assert resp['statusCode'] == 200
        assert resp['body']['copy_job']['copy_job_id'] == 'job-1'

def test_poll_copy_job():
    event = {"copy_job_id": "job-2"}
    with patch.object(crp, 'backup_client') as mock_client:
        mock_client.describe_copy_job.return_value = {"CopyJob": {"CopyJobId": "job-2", "State": "RUNNING"}}
        resp = crp.lambda_handler(event, Ctx())
        assert resp['statusCode'] == 200
        assert resp['body']['state'] == 'RUNNING'

def test_wait_flag_applies_sleep_on_start():
    event = {"recovery_point_arn": "arn:aws:backup:eu-west-2:123456789012:recovery-point:XYZ", "wait": True}
    with patch.object(crp, 'backup_client') as mock_client, patch('time.sleep') as sleep_mock:
        mock_client.start_copy_job.return_value = {"CopyJobId": "job-w", "CreationDate": 0, "IsParent": False}
        mock_client.describe_copy_job.return_value = {"CopyJob": {"CopyJobId": "job-w", "State": "RUNNING"}}
        resp = crp.lambda_handler(event, Ctx())
        sleep_mock.assert_called_with(30)
        assert resp['body']['copy_job']['copy_job_id'] == 'job-w'

def test_wait_flag_applies_sleep_on_poll():
    event = {"copy_job_id": "job-p", "wait": True}
    with patch.object(crp, 'backup_client') as mock_client, patch('time.sleep') as sleep_mock:
        mock_client.describe_copy_job.return_value = {"CopyJob": {"CopyJobId": "job-p", "State": "RUNNING"}}
        resp = crp.lambda_handler(event, Ctx())
        sleep_mock.assert_called_with(30)
        assert resp['body']['copy_job_id'] == 'job-p' or resp['body']['state'] == 'RUNNING'
