locals {
  statemachine_definition = templatefile("${path.module}/statemachine.json.tpl", {
    lambda_arn = aws_lambda_function.validator.arn
  })
}

resource "aws_sfn_state_machine" "validation" {
  name     = local.state_machine_name
  role_arn = aws_iam_role.state_machine.arn
  definition = local.statemachine_definition
  tags     = var.tags
}

resource "aws_iam_role_policy" "allow_sfn_logs" {
  name = "${local.state_machine_name}-logs"
  role = aws_iam_role.state_machine.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents" ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

# EventBridge Rule for restore job completion
resource "aws_cloudwatch_event_rule" "restore_completed" {
  name        = "${var.name_prefix}-restore-completed"
  description = "Triggers validation on restore job completion"
  event_pattern = jsonencode({
    source      = ["aws.backup"],
    "detail-type" = ["Restore Job State Change"],
    detail = {
      status = ["COMPLETED"]
      restoreTestingPlanArn = [ var.restore_testing_plan_arn ]
    }
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "sfn_target" {
  rule      = aws_cloudwatch_event_rule.restore_completed.name
  target_id = "${var.name_prefix}-sfn"
  arn       = aws_sfn_state_machine.validation.arn
  role_arn  = aws_iam_role.eventbridge_invoke.arn
}

resource "aws_iam_role" "eventbridge_invoke" {
  name               = "${var.name_prefix}-events-invoke-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.events_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "events_assume" {
  statement {
    effect = "Allow"
    principals { type = "Service" identifiers = ["events.amazonaws.com"] }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "events_invoke_sfn" {
  name = "${var.name_prefix}-events-invoke-sfn"
  role = aws_iam_role.eventbridge_invoke.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["states:StartExecution"],
        Resource = aws_sfn_state_machine.validation.arn
      }
    ]
  })
}
