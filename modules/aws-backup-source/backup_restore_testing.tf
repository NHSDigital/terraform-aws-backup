resource "awscc_backup_restore_testing_plan" "backup_restore_testing_plan" {
  restore_testing_plan_name = var.name_prefix != null ? "${var.name_prefix}_backup_restore_testing_plan" : "backup_restore_testing_plan"
  schedule_expression       = var.restore_testing_plan_scheduled_expression
  start_window_hours        = var.restore_testing_plan_start_window
  recovery_point_selection = {
    algorithm             = var.restore_testing_plan_algorithm
    include_vaults        = [aws_backup_vault.main.arn]
    recovery_point_types  = var.restore_testing_plan_recovery_point_types
    selection_window_days = var.restore_testing_plan_selection_window_days
  }
}

resource "awscc_backup_restore_testing_selection" "backup_restore_testing_selection_dynamodb" {
  count                          = var.backup_plan_config_dynamodb.enable ? 1 : 0
  iam_role_arn                   = aws_iam_role.backup.arn
  protected_resource_type        = "DynamoDB"
  restore_testing_plan_name      = awscc_backup_restore_testing_plan.backup_restore_testing_plan.restore_testing_plan_name
  restore_testing_selection_name = "backup_restore_testing_selection_dynamodb"
  protected_resource_arns        = ["*"]
  protected_resource_conditions = {
    string_equals = [{
      key   = "aws:ResourceTag/${var.backup_plan_config_dynamodb.selection_tag}"
      value = "True"
    }]
  }
}


resource "awscc_backup_restore_testing_selection" "backup_restore_testing_selection_ebsvol" {
  count                          = var.backup_plan_config_ebsvol.enable ? 1 : 0
  iam_role_arn                   = aws_iam_role.backup.arn
  protected_resource_type        = "EBS"
  restore_testing_plan_name      = awscc_backup_restore_testing_plan.backup_restore_testing_plan.restore_testing_plan_name
  restore_testing_selection_name = "backup_restore_testing_selection_ebsvol"
  protected_resource_arns        = ["*"]
  protected_resource_conditions = {
    string_equals = [{
      key   = "aws:ResourceTag/${var.backup_plan_config_ebsvol.selection_tag}"
      value = "True"
    }]
  }
}

resource "awscc_backup_restore_testing_selection" "backup_restore_testing_selection_aurora" {
  count                          = var.backup_plan_config_aurora.enable ? 1 : 0
  iam_role_arn                   = aws_iam_role.backup.arn
  protected_resource_type        = "Aurora"
  restore_testing_plan_name      = awscc_backup_restore_testing_plan.backup_restore_testing_plan.restore_testing_plan_name
  restore_testing_selection_name = "backup_restore_testing_selection_aurora"
  protected_resource_arns        = ["*"]
  protected_resource_conditions = {
    string_equals = [{
      key   = "aws:ResourceTag/${var.backup_plan_config_aurora.selection_tag}"
      value = "True"
    }]
  }
  restore_metadata_overrides = local.aurora_overrides
}

resource "awscc_backup_restore_testing_selection" "backup_restore_testing_selection_parameter_store" {
  count                          = var.backup_plan_config_parameter_store.enable ? 1 : 0
  iam_role_arn                   = aws_iam_role.backup.arn
  protected_resource_type        = "SSMParameterStore"
  restore_testing_plan_name      = awscc_backup_restore_testing_plan.backup_restore_testing_plan.restore_testing_plan_name
  restore_testing_selection_name = "backup_restore_testing_selection_parameter_store"
  protected_resource_arns        = ["*"]
  protected_resource_conditions = {
    string_equals = [{
      key   = "aws:ResourceTag/${var.backup_plan_config_parameter_store.selection_tag}"
      value = "True"
    }]
  }
}
