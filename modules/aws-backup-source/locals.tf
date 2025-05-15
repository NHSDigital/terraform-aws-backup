locals {
  resource_name_prefix                      = var.name_prefix != null ? var.name_prefix : "${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}-backup"
  selection_tag_value_null_checked          = (var.backup_plan_config.selection_tag_value == null) ? "True" : var.backup_plan_config.selection_tag_value
  selection_tag_value_dynamodb_null_checked = (var.backup_plan_config_dynamodb.selection_tag_value == null) ? "True" : var.backup_plan_config_dynamodb.selection_tag_value
  selection_tags_null_adjusted              = (var.backup_plan_config.selection_tags == null) ? [{ "key" : "${var.backup_plan_config.selection_tag}", "value" : "${local.selection_tag_value_null_checked}" }] : var.backup_plan_config.selection_tags
  selection_tags_dynamodb_null_checked      = (var.backup_plan_config_dynamodb.selection_tags == null) ? [{ "key" : "${var.backup_plan_config_dynamodb.selection_tag}", "value" : "${local.selection_tag_value_dynamodb_null_checked}" }] : var.backup_plan_config_dynamodb.selection_tags
}
