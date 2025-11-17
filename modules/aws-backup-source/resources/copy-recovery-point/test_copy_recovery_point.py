import copy_recovery_point as crp
from unittest.mock import patch, MagicMock

class Ctx: aws_request_id = 'test-id'

def test_build_copy_job_params_correct_mapping():
    """Test that destination and source vault ARNs are correctly mapped in parameters"""
    recovery_point_arn = "arn:aws:backup:eu-west-2:123456789012:recovery-point:test"
    source_vault_arn = "arn:aws:backup:eu-west-2:123456789012:backup-vault:source-vault"
    destination_vault_arn = "arn:aws:backup:eu-west-2:987654321098:backup-vault:dest-vault"
    assume_role_arn = "arn:aws:iam::987654321098:role/test-role"

    params = crp._build_copy_job_params(
        recovery_point_arn,
        source_vault_arn,
        destination_vault_arn,
        assume_role_arn,
        Ctx()
    )

    # Critical: DestinationBackupVaultArn should be the destination vault ARN
    assert params["DestinationBackupVaultArn"] == destination_vault_arn
    # SourceBackupVaultName should be parsed from source vault ARN
    assert params["SourceBackupVaultName"] == "source-vault"
    assert params["RecoveryPointArn"] == recovery_point_arn
    assert params["IamRoleArn"] == assume_role_arn

def test_start_copy_job_with_arn():
    event = {"recovery_point_arn": "arn:aws:backup:eu-west-2:123456789012:recovery-point:ABC"}
    with patch.object(crp, '_get_backup_client') as get_client:
        mock_client = MagicMock()
        get_client.return_value = mock_client
        mock_client.start_copy_job.return_value = {"CopyJobId": "job-1", "CreationDate": 0, "IsParent": False}
        mock_client.describe_copy_job.return_value = {"CopyJob": {"CopyJobId": "job-1", "State": "CREATED"}}
        resp = crp.lambda_handler(event, Ctx())
        assert resp['statusCode'] in (200, 201)
        assert resp['body']['copy_job']['copy_job_id'] == 'job-1'

def test_poll_copy_job():
    event = {"copy_job_id": "job-2"}
    with patch.object(crp, '_get_backup_client') as get_client:
        mock_client = MagicMock()
        get_client.return_value = mock_client
        mock_client.describe_copy_job.return_value = {"CopyJob": {"CopyJobId": "job-2", "State": "RUNNING"}}
        resp = crp.lambda_handler(event, Ctx())
        assert resp['statusCode'] in (200, 202)
        assert resp['body']['state'] == 'RUNNING'

def test_wait_flag_applies_sleep_on_start():
    event = {"recovery_point_arn": "arn:aws:backup:eu-west-2:123456789012:recovery-point:XYZ", "wait": True}
    with patch.object(crp, '_get_backup_client') as get_client, patch('time.sleep') as sleep_mock:
        mock_client = MagicMock()
        get_client.return_value = mock_client
        mock_client.start_copy_job.return_value = {"CopyJobId": "job-w", "CreationDate": 0, "IsParent": False}
        mock_client.describe_copy_job.return_value = {"CopyJob": {"CopyJobId": "job-w", "State": "RUNNING"}}
        resp = crp.lambda_handler(event, Ctx())
        sleep_mock.assert_called_with(30)
        assert resp['body']['copy_job']['copy_job_id'] == 'job-w'

def test_wait_flag_applies_sleep_on_poll():
    event = {"copy_job_id": "job-p", "wait": True}
    with patch.object(crp, '_get_backup_client') as get_client, patch('time.sleep') as sleep_mock:
        mock_client = MagicMock()
        get_client.return_value = mock_client
        mock_client.describe_copy_job.return_value = {"CopyJob": {"CopyJobId": "job-p", "State": "RUNNING"}}
        resp = crp.lambda_handler(event, Ctx())
        sleep_mock.assert_called_with(30)
        assert resp['body']['copy_job_id'] == 'job-p' or resp['body']['state'] == 'RUNNING'

def test_get_backup_client_uses_default_client():
    # Should not attempt STS assume; returns module-level client
    client = crp._get_backup_client('ignored')
    assert client is crp._default_backup_client
