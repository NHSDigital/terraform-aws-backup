resource "aws_backup_vault_notifications" "backup_notification" {
  count             = local.enable_sns_notifications ? 1 : 0
  backup_vault_name = aws_backup_vault.main.name
  sns_topic_arn     = aws_sns_topic.backup[0].arn
  backup_vault_events = [
    "BACKUP_JOB_COMPLETED",
    "RESTORE_JOB_COMPLETED",
    "S3_BACKUP_OBJECT_FAILED",
    "S3_RESTORE_OBJECT_FAILED",
    "COPY_JOB_FAILED"
  ]
}
