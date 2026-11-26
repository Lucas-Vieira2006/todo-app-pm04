terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Tags aplicadas a todos os recursos que aceitam tags
  default_tags {
    tags = merge(
      {
        Project     = var.project
        Environment = var.environment
        ManagedBy   = "terraform"
        Course      = "PM-04"
      },
      var.extra_tags,
    )
  }
}
