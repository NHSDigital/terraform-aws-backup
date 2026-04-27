locals {
  resource_name_prefix = var.name_prefix != null ? (var.include_environment_in_resource_names ? "${var.name_prefix}-${var.environment_name}" : var.name_prefix) : (var.include_environment_in_resource_names ? "${data.aws_region.current.id}-${data.aws_caller_identity.current.account_id}-${var.environment_name}-backup" : "${data.aws_region.current.id}-${data.aws_caller_identity.current.account_id}-backup")

  selection_tag_value_null_checked                 = (var.backup_plan_config.selection_tag_value == null) ? "True" : var.backup_plan_config.selection_tag_value
  selection_tag_value_aurora_null_checked          = (var.backup_plan_config_aurora.selection_tag_value == null) ? "True" : var.backup_plan_config_aurora.selection_tag_value
  selection_tag_value_dynamodb_null_checked        = (var.backup_plan_config_dynamodb.selection_tag_value == null) ? "True" : var.backup_plan_config_dynamodb.selection_tag_value
  selection_tag_value_ebsvol_null_checked          = (var.backup_plan_config_ebsvol.selection_tag_value == null) ? "True" : var.backup_plan_config_ebsvol.selection_tag_value
  selection_tag_value_parameter_store_null_checked = (var.backup_plan_config_parameter_store.selection_tag_value == null) ? "True" : var.backup_plan_config_parameter_store.selection_tag_value

  selection_tags_null_checked                 = (var.backup_plan_config.selection_tags == null) ? [{ "key" : var.backup_plan_config.selection_tag, "value" : local.selection_tag_value_null_checked }] : var.backup_plan_config.selection_tags
  selection_tags_aurora_null_checked          = (var.backup_plan_config_aurora.selection_tags == null) ? [{ "key" : var.backup_plan_config_aurora.selection_tag, "value" : local.selection_tag_value_aurora_null_checked }] : var.backup_plan_config_aurora.selection_tags
  selection_tags_dynamodb_null_checked        = (var.backup_plan_config_dynamodb.selection_tags == null) ? [{ "key" : var.backup_plan_config_dynamodb.selection_tag, "value" : local.selection_tag_value_dynamodb_null_checked }] : var.backup_plan_config_dynamodb.selection_tags
  selection_tags_ebsvol_null_checked          = (var.backup_plan_config_ebsvol.selection_tags == null) ? [{ "key" : var.backup_plan_config_ebsvol.selection_tag, "value" : local.selection_tag_value_ebsvol_null_checked }] : var.backup_plan_config_ebsvol.selection_tags
  selection_tags_parameter_store_null_checked = (var.backup_plan_config_parameter_store.selection_tags == null) ? [{ "key" : var.backup_plan_config_parameter_store.selection_tag, "value" : local.selection_tag_value_parameter_store_null_checked }] : var.backup_plan_config_parameter_store.selection_tags

  framework_arn_list = flatten(concat(
    var.backup_plan_config.enable ? [var.resources_in_same_account == "" ? aws_backup_framework.main[0].arn : aws_backup_framework.main[0].arn] : [],
    var.backup_plan_config_ebsvol.enable ? [var.resources_in_same_account == "" ? aws_backup_framework.ebsvol[0].arn : data.aws_backup_framework.ebsvol[0].arn] : [],
    var.backup_plan_config_dynamodb.enable ? [var.resources_in_same_account == "" ? aws_backup_framework.dynamodb[0].arn : data.aws_backup_framework.dynamodb[0].arn] : [],
    var.backup_plan_config_aurora.enable ? [var.resources_in_same_account == "" ? aws_backup_framework.aurora[0].arn : data.aws_backup_framework.aurora[0].arn] : [],
    var.backup_plan_config_parameter_store.enable ? [var.resources_in_same_account == "" ? aws_backup_framework.parameter_store[0].arn : data.aws_backup_framework.parameter_store[0].arn] : []
  ))

  aurora_overrides = var.backup_plan_config_aurora.restore_testing_overrides == null ? null : jsondecode(var.backup_plan_config_aurora.restore_testing_overrides)

  terraform_role_arns = length(var.terraform_role_arns) > 0 ? var.terraform_role_arns : [var.terraform_role_arn]
}
