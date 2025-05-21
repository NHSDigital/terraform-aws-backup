module "eventbridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "3.14.3"

  create_bus  = false
  create_role = false

  rules = {
    "Cross-Account-Copy-Job" = {
      description = "Identify when a new recovery point is created in the intermediary vault"
      event_pattern = jsonencode(
        {
          "source" : ["aws.backup"],
          "account" : ["${data.aws_caller_identity.current.account_id}"],
          "region" : ["eu-west-2"],
          "detail" : {
            "eventName" : ["RecoveryPointCreated"]
            "serviceEventDetails" : {
              "backupVaultName" : [{ "wildcard" : "*-intermediary-vault" }]
            }
          }
        }
      )
      enabled = true
    }
  }

  targets = {
    "Cross-Account-Copy-Job" = [
      {
        name = "start_cross_account_copy_job"
        arn  = "arn:aws:lambda:eu-west-2:${data.aws_caller_identity.current.account_id}:function:start_cross_account_copy_job"
      }
    ]
  }
}