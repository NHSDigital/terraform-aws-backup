output "orchestrator_lambda_arn" {
  value       = try(aws_lambda_function.orchestrator[0].arn, null)
  description = "Manual restore validation orchestrator Lambda ARN"
}
