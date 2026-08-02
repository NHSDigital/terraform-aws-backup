{
  "Comment": "Restore Test Validation Orchestrator",
  "StartAt": "EnrichRestoreJob",
  "States": {
    "EnrichRestoreJob": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:backup:describeRestoreJob",
      "Parameters": {"RestoreJobId.$": "$.detail.restoreJobId"},
      "ResultPath": "$.restoreJob",
      "Next": "Route"
    },
    "Route": {
      "Type": "Choice",
      "Choices": [
        {"Variable": "$.detail.resourceType", "StringEquals": "Aurora", "Next": "InvokeValidator"},
        {"Variable": "$.detail.resourceType", "StringEquals": "RDS", "Next": "InvokeValidator"},
        {"Variable": "$.detail.resourceType", "StringEquals": "DynamoDB", "Next": "InvokeValidator"},
        {"Variable": "$.detail.resourceType", "StringEquals": "S3", "Next": "InvokeValidator"}
      ],
      "Default": "Skip"
    },
    "InvokeValidator": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "FunctionName": "${lambda_arn}",
        "Payload.$": "$"
      },
      "Next": "PublishResult"
    },
    "Skip": {
      "Type": "Pass",
      "Result": {"status": "SKIPPED", "message": "No validator implemented"},
      "ResultPath": "$.validation",
      "Next": "PublishResult"
    },
    "PublishResult": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:backup:putRestoreValidationResult",
      "Parameters": {
        "RestoreJobId.$": "$.detail.restoreJobId",
        "ValidationStatus.$": "$.status",
        "ValidationStatusMessage.$": "$.message"
      },
      "End": true
    }
  }
}
