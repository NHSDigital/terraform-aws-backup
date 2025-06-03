data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# tflint-ignore: terraform_unused_declarations
data "aws_iam_roles" "roles" {
  name_regex  = "AWSReservedSSO_Admin_.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}
