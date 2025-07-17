resource "aws_backup_vault" "main" {
  name        = "${var.name_prefix}-vault"
  kms_key_arn = aws_kms_key.aws_backup_key.arn
}
