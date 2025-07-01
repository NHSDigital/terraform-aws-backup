locals {
  resource_name_prefix            = "${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}-backup"
  deletion_allowed_principal_arns = var.deletion_allowed_principal_arns != null ? var.deletion_allowed_principal_arns : [var.terraform_role_arn]
}
