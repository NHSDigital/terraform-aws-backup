terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "> 5"
    }

    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1"
    }

    validation = {
      source  = "hashicorp/validation"
      version = "~>1"
    }
  }

  required_version = ">= 1.9.5"
}
