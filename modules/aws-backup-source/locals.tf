locals {
  resource_name_prefix                      = var.name_prefix != null ? var.name_prefix : "${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}-backup"
  selection_tag_value_null_checked          = (var.backup_plan_config.selection_tag_value == null) ? "True" : var.backup_plan_config.selection_tag_value
  selection_tag_value_dynamodb_null_checked = (var.backup_plan_config_dynamodb.selection_tag_value == null) ? "True" : var.backup_plan_config_dynamodb.selection_tag_value
  selection_tags_null_checked               = (var.backup_plan_config.selection_tags == null) ? [{ "key" : var.backup_plan_config.selection_tag, "value" : local.selection_tag_value_null_checked }] : var.backup_plan_config.selection_tags
  selection_tags_dynamodb_null_checked      = (var.backup_plan_config_dynamodb.selection_tags == null) ? [{ "key" : var.backup_plan_config_dynamodb.selection_tag, "value" : local.selection_tag_value_dynamodb_null_checked }] : var.backup_plan_config_dynamodb.selection_tags
  selection_tag_value_ebsvol_null_checked   = (var.backup_plan_config_ebsvol.selection_tag_value == null) ? "True" : var.backup_plan_config_ebsvol.selection_tag_value
  selection_tags_ebsvol_null_checked        = (var.backup_plan_config_ebsvol.selection_tags == null) ? [{ "key" : var.backup_plan_config_ebsvol.selection_tag, "value" : local.selection_tag_value_ebsvol_null_checked }] : var.backup_plan_config_ebsvol.selection_tags
  selection_tag_value_efs_null_checked      = (var.backup_plan_config_efs.selection_tags == null) ? [{ "key" : var.backup_plan_config_efs.selection_tag, "value" : local.selection_tag_value_efs_null_checked }] : var.backup_plan_config_efs.selection_tags
  framework_arn_list = flatten(concat(
    [aws_backup_framework.main.arn],
    var.backup_plan_config_ebsvol.enable ? [aws_backup_framework.ebsvol[0].arn] : [],
    var.backup_plan_config_dynamodb.enable ? [aws_backup_framework.dynamodb[0].arn] : [],
    var.backup_plan_config_aurora.enable ? [aws_backup_framework.aurora[0].arn] : [],
    var.backup_plan_config_efs.enable ? [aws_backup_framework.ebsvol[0].arn] : [],
  ))
  aurora_overrides    = var.backup_plan_config_aurora.restore_testing_overrides == null ? null : jsondecode(var.backup_plan_config_aurora.restore_testing_overrides)
  terraform_role_arns = var.terraform_role_arns != [] ? var.terraform_role_arns : [var.terraform_role_arn]
}
