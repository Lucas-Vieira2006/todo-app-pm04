variable "aws_region" {
  description = "Região AWS dos buckets e do papel da pipeline."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefixo dos nomes dos recursos."
  type        = string
  default     = "todo-app"
}

variable "github_repository" {
  description = "Repositório GitHub autorizado a assumir o papel, no formato owner/repo."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Use o formato owner/repo."
  }
}

variable "environments" {
  description = "GitHub Environments que podem assumir o papel da pipeline."
  type        = list(string)
  default     = ["dev", "homolog", "prod"]
}

variable "create_oidc_provider" {
  description = "Cria o provedor OIDC do GitHub. Use false se a conta já tiver um (só pode existir um por URL)."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Dias de retenção dos backups do MongoDB no S3."
  type        = number
  default     = 30
}
