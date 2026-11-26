terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Stack executada uma única vez, localmente, com credenciais de administrador.
  # O state fica local (terraform.tfstate, fora do Git). Depois de criado o bucket,
  # ele pode ser migrado para o S3 com: terraform init -migrate-state -backend-config=...
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Stack     = "bootstrap"
      Course    = "PM-04"
    }
  }
}
