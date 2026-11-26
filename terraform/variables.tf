# --- Identificação ------------------------------------------------------------
variable "aws_region" {
  description = "Região AWS do ambiente."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefixo dos nomes dos recursos."
  type        = string
  default     = "todo-app"
}

variable "environment" {
  description = "Ambiente de destino (parâmetro environment da pipeline)."
  type        = string

  validation {
    condition     = contains(["dev", "homolog", "prod"], var.environment)
    error_message = "environment deve ser dev, homolog ou prod."
  }
}

variable "extra_tags" {
  description = "Tags adicionais aplicadas a todos os recursos."
  type        = map(string)
  default     = {}
}

# --- Máquinas virtuais (parâmetros da pipeline) ----------------------------------
variable "instance_name" {
  description = "Nome (tag Name) da VM da aplicação; a VM do banco recebe o sufixo -db."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.instance_name))
    error_message = "instance_name: 3 a 31 caracteres, minúsculas, números e hífen, começando por letra."
  }
}

variable "instance_type" {
  description = "Tipo da VM da aplicação."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "instance_type permitido: t3.micro, t3.small ou t3.medium (controle de custo)."
  }
}

variable "db_instance_type" {
  description = "Tipo da VM do MongoDB."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.db_instance_type)
    error_message = "db_instance_type permitido: t3.micro, t3.small ou t3.medium (controle de custo)."
  }
}

variable "ssh_public_key" {
  description = "Chave pública SSH usada pela pipeline (derivada do secret SSH_PRIVATE_KEY)."
  type        = string

  validation {
    condition     = can(regex("^ssh-(ed25519|rsa) ", var.ssh_public_key))
    error_message = "ssh_public_key deve ser uma chave pública OpenSSH (ssh-ed25519 ou ssh-rsa)."
  }
}

variable "admin_cidrs" {
  description = "Redes com SSH permanente na VM da aplicação. Vazio = SSH só temporário pela pipeline."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.admin_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "admin_cidrs deve conter CIDRs válidos e não pode liberar 0.0.0.0/0."
  }
}

# --- Rede -------------------------------------------------------------------------
variable "availability_zone" {
  description = "Zona das VMs e do volume de dados. Vazio = primeira zona disponível."
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC do ambiente."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Sub-rede pública (VM da aplicação)."
  type        = string
  default     = "10.20.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Sub-rede privada (VM do MongoDB)."
  type        = string
  default     = "10.20.2.0/24"
}

# --- Armazenamento --------------------------------------------------------------
variable "app_root_volume_size" {
  description = "Disco raiz da VM da aplicação (GiB)."
  type        = number
  default     = 16
}

variable "db_root_volume_size" {
  description = "Disco raiz da VM do banco (GiB)."
  type        = number
  default     = 12
}

variable "db_data_volume_size" {
  description = "Volume persistente de dados do MongoDB (GiB)."
  type        = number
  default     = 10
}

variable "backup_bucket_name" {
  description = "Bucket S3 de backups criado pela stack bootstrap."
  type        = string
}

# --- Publicação -----------------------------------------------------------------
variable "app_domain" {
  description = "Domínio público da aplicação. Vazio = <ip>.sslip.io."
  type        = string
  default     = ""
}
