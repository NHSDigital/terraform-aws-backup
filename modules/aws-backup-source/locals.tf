locals {
  selection_tag_value_null_checked          = (var.backup_plan_config.selection_tag_value == null) ? "True" : var.backup_plan_config.selection_tag_value
  selection_tag_value_dynamodb_null_checked = (var.backup_plan_config_dynamodb.selection_tag_value == null) ? "True" : var.backup_plan_config_dynamodb.selection_tag_value
  selection_tags_null_checked               = (var.backup_plan_config.selection_tags == null) ? [{ "key" : var.backup_plan_config.selection_tag, "value" : local.selection_tag_value_null_checked }] : var.backup_plan_config.selection_tags
  selection_tags_dynamodb_null_checked      = (var.backup_plan_config_dynamodb.selection_tags == null) ? [{ "key" : var.backup_plan_config_dynamodb.selection_tag, "value" : local.selection_tag_value_dynamodb_null_checked }] : var.backup_plan_config_dynamodb.selection_tags
  selection_tag_value_ebsvol_null_checked   = (var.backup_plan_config_ebsvol.selection_tag_value == null) ? "True" : var.backup_plan_config_ebsvol.selection_tag_value
  selection_tags_ebsvol_null_checked        = (var.backup_plan_config_ebsvol.selection_tags == null) ? [{ "key" : var.backup_plan_config_ebsvol.selection_tag, "value" : local.selection_tag_value_ebsvol_null_checked }] : var.backup_plan_config_ebsvol.selection_tags
  framework_arn_list = flatten(concat(
    [aws_backup_framework.main.arn],
    var.backup_plan_config_ebsvol.enable ? [aws_backup_framework.ebsvol[0].arn] : [],
    var.backup_plan_config_dynamodb.enable ? [aws_backup_framework.dynamodb[0].arn] : []
  ))
}
