terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5"
    }

    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1"
    }
  }

  required_version = ">= 1.4.0"
}
