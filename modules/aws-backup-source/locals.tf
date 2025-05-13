locals {
  resource_name_prefix = "${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}-backup"
  aurora_overrides     = jsondecode(var.backup_plan_config_aurora.restore_testing_overrides)
}
