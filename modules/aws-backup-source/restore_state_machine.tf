locals {
  restore_state_machine_name = coalesce(var.restore_state_machine_name_override, "${local.resource_name_prefix}-restore-workflow")
}

resource "aws_iam_role" "restore_state_machine" {
  count = var.restore_state_machine_enable ? 1 : 0
  name  = "${local.resource_name_prefix}-restore-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "restore_state_machine" {
  count = var.restore_state_machine_enable ? 1 : 0
  name  = "${local.resource_name_prefix}-restore-sfn-policy"
  role  = aws_iam_role.restore_state_machine[0].id

  # Minimum permissions: invoke the three restoration lambdas (if enabled) + CloudWatch Logs for execution history (implicit) handled by AWS.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = compact([
          try(aws_lambda_function.lambda_copy_recovery_point[0].arn, null),
          try(aws_lambda_function.lambda_restore_to_s3[0].arn, null),
          try(aws_lambda_function.lambda_restore_to_rds[0].arn, null)
        ])
      }
    ]
  })
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  restore_state_machine_definition = jsonencode({
    Comment = "Backup restoration orchestration: copy recovery point then restore to selected targets with optional validation",
    StartAt = "CopyRecoveryPoint",
    States = {
      CopyRecoveryPoint = {
        Type     = "Task",
        Resource = "arn:aws:states:::lambda:invoke",
        Parameters = {
          FunctionName = try(aws_lambda_function.lambda_copy_recovery_point[0].arn, "")
          Payload = {
            "recovery_point_arn.$" = "$.recovery_point_arn"
            wait                   = true
          }
        }
        ResultPath = "$.copy"
        Next       = "WaitForCopy"
      },
      WaitForCopy = {
        Type = "Wait",
        Seconds = var.restore_state_machine_wait_seconds,
        Next = "PollCopyStatus"
      },
      PollCopyStatus = {
        Type     = "Task",
        Resource = "arn:aws:states:::lambda:invoke",
        Parameters = {
          FunctionName = try(aws_lambda_function.lambda_copy_recovery_point[0].arn, "")
          Payload = {
            "copy_job_id.$" = "$.copy.Payload.body.copy_job.copy_job_id"
            wait            = true
          }
        }
        ResultPath = "$.copy"
        Next       = "CopyCompletionChoice"
      },
      CopyCompletionChoice = {
        Type = "Choice",
        Choices = [
          {
            Variable = "$.copy.Payload.body.state",
            StringEquals = "COMPLETED",
            Next = "PrepareRestoreTargets"
          },
          {
            Variable = "$.copy.Payload.body.state",
            StringEquals = "FAILED",
            Next = "CopyFailed"
          },
          {
            Variable = "$.copy.Payload.body.state",
            StringEquals = "ABORTED",
            Next = "CopyFailed"
          }
        ]
        Default = "WaitForCopy"
      },
      CopyFailed = {
        Type = "Fail",
        Error = "CopyJobFailed",
        Cause = "Recovery point copy failed"
      },
      PrepareRestoreTargets = {
        Type = "Pass",
        ResultPath = "$.targets",
        Result = {
          # Each item must indicate type and target-specific parameters expected by downstream Lambda.
          # Caller supplies desired_targets array in input; we filter to those with enabled lambdas.
          "Items.$" = "$.desired_targets"
        },
        Next = "RestoreTargetsMap"
      },
      RestoreTargetsMap = {
        Type = "Map",
        ItemsPath = "$.targets.Items",
        Parameters = {
          "target.$" = "$$.Map.Item.Value"
          "recovery_point_arn.$" = "$.copy.Payload.body.destination_recovery_point_arn"
        },
        Iterator = {
          StartAt = "RestoreChoice",
          States = {
            RestoreChoice = {
              Type = "Choice",
              Choices = [
                {
                  Variable = "$.target.type",
                  StringEquals = "S3",
                  Next = "RestoreS3"
                },
                {
                  Variable = "$.target.type",
                  StringEquals = "RDS",
                  Next = "RestoreRDS"
                }
              ],
              Default = "UnknownTypeFail"
            },
            RestoreS3 = {
              Type = "Task",
              Resource = "arn:aws:states:::lambda:invoke",
              Parameters = {
                FunctionName = try(aws_lambda_function.lambda_restore_to_s3[0].arn, "")
                Payload = {
                  "recovery_point_arn.$"  = "$.recovery_point_arn"
                  "destination_s3_bucket.$" = "$.target.destination_s3_bucket"
                  "iam_role_arn.$" = "$.target.iam_role_arn"
                }
              },
              ResultPath = "$.restore_result",
              Next = "S3Outcome"
            },
            S3Outcome = {
              Type = "Choice",
              Choices = [
                { Variable = "$.restore_result.Payload.body.finalStatus", StringEquals = "COMPLETED", Next = "SuccessPass" },
                { Variable = "$.restore_result.Payload.body.finalStatus", StringEquals = "FAILED", Next = "RestoreFailed" },
                { Variable = "$.restore_result.Payload.body.finalStatus", StringEquals = "ABORTED", Next = "RestoreFailed" }
              ],
              Default = "RestorePending"
            },
            RestorePending = {
              Type = "Wait",
              Seconds = var.restore_state_machine_wait_seconds,
              Next = "PollS3"
            },
            PollS3 = {
              Type = "Task",
              Resource = "arn:aws:states:::lambda:invoke",
              Parameters = {
                FunctionName = try(aws_lambda_function.lambda_restore_to_s3[0].arn, "")
                Payload = {
                  "restore_job_id.$" = "$.restore_result.Payload.body.restoreJobId"
                }
              },
              ResultPath = "$.restore_result",
              Next = "S3Outcome"
            },
            RestoreRDS = {
              Type = "Task",
              Resource = "arn:aws:states:::lambda:invoke",
              Parameters = {
                FunctionName = try(aws_lambda_function.lambda_restore_to_rds[0].arn, "")
                Payload = {
                  "recovery_point_arn.$" = "$.recovery_point_arn"
                  "iam_role_arn.$" = "$.target.iam_role_arn"
                  "db_instance_identifier.$" = "$.target.db_instance_identifier"
                  "db_instance_class.$" = "$.target.db_instance_class"
                  "db_subnet_group_name.$" = "$.target.db_subnet_group_name"
                  "vpc_security_group_ids.$" = "$.target.vpc_security_group_ids"
                  "restore_metadata_overrides.$" = "$.target.restore_metadata_overrides"
                }
              },
              ResultPath = "$.restore_result",
              Next = "RDSOutcome"
            },
            RDSOutcome = {
              Type = "Choice",
              Choices = [
                { Variable = "$.restore_result.Payload.body.finalStatus", StringEquals = "COMPLETED", Next = "SuccessPass" },
                { Variable = "$.restore_result.Payload.body.finalStatus", StringEquals = "FAILED", Next = "RestoreFailed" },
                { Variable = "$.restore_result.Payload.body.finalStatus", StringEquals = "ABORTED", Next = "RestoreFailed" }
              ],
              Default = "RestorePendingRDS"
            },
            RestorePendingRDS = {
              Type = "Wait",
              Seconds = var.restore_state_machine_wait_seconds,
              Next = "PollRDS"
            },
            PollRDS = {
              Type = "Task",
              Resource = "arn:aws:states:::lambda:invoke",
              Parameters = {
                FunctionName = try(aws_lambda_function.lambda_restore_to_rds[0].arn, "")
                Payload = {
                  "restore_job_id.$" = "$.restore_result.Payload.body.restoreJobId"
                }
              },
              ResultPath = "$.restore_result",
              Next = "RDSOutcome"
            },
            SuccessPass = { Type = "Pass", End = true },
            RestoreFailed = { Type = "Fail", Error = "RestoreFailed", Cause = "Resource restore failed" },
            UnknownTypeFail = { Type = "Fail", Error = "UnknownTargetType", Cause = "Unsupported target type" }
          }
        },
        ResultPath = "$.restore_targets",
        Next = "Success"
      },
      Success = { Type = "Succeed" }
    }
  })
}

resource "aws_sfn_state_machine" "restore" {
  count = var.restore_state_machine_enable ? 1 : 0
  name  = local.restore_state_machine_name
  role_arn = aws_iam_role.restore_state_machine[0].arn
  definition = local.restore_state_machine_definition
  depends_on = [aws_iam_role_policy.restore_state_machine]
}
