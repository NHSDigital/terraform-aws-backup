locals {
  resource_name_prefix = "${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}-backup"

  framework_arn_list = concat(
     [aws_backup_framework.main.arn],
     var.backup_plan_config_ebsvol.enable ? [aws_backup_framework.ebsvol[0].arn]:[],
     var.backup_plan_config_dynamodb.enable ? [aws_backup_framework.dynamodb[0].arn]:[]
  )
}
