output "state_machine_arn" {
  description = "ARN of the validation Step Functions state machine"
  value       = aws_sfn_state_machine.validation.arn
}

output "validator_lambda_arn" {
  description = "ARN of the validator lambda"
  value       = aws_lambda_function.validator.arn
}

output "config_parameter_name" {
  description = "Name of SSM parameter storing validation config"
  value       = aws_ssm_parameter.config.name
}
