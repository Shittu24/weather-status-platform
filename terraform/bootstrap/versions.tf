terraform {
  backend "s3" {}
  required_version = "~> 1.17.1"
  required_providers {
    aws = { source = "hashicorp/aws", version = "= 6.71.0" }
  }
}
provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["975049996360"]
  default_tags { tags = { Project = "weather-status", ManagedBy = "terraform", Environment = "portfolio-dev" } }
}
