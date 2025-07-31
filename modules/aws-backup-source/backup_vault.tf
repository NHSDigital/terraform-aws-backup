resource "aws_backup_vault" "main" {
  name        = replace("${local.resource_name_prefix}-vault", "_", "-")
  kms_key_arn = aws_kms_key.aws_backup_key.arn
}
