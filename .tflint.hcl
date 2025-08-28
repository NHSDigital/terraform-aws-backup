
plugin "aws" {
  enabled = true
  version = "0.41.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  plugin_dir = "~/.tflint.d/plugins"
  call_module_type = "local"
  ignore_module = {
    "does-not-work" = true
  }
}
