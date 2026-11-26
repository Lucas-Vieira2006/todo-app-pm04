data "aws_availability_zones" "available" {
  #checkov:skip=CKV_AWS_394:A zona é escolhida uma vez (primeira da lista) ou fixada por var.availability_zone
  state = "available"
}

# Ubuntu 24.04 LTS oficial da Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  name_prefix       = "${var.project}-${var.environment}"
  availability_zone = var.availability_zone != "" ? var.availability_zone : data.aws_availability_zones.available.names[0]

  # Sem domínio próprio, usa <ip-com-hifens>.sslip.io, que resolve para o Elastic IP
  app_domain = var.app_domain != "" ? var.app_domain : "${replace(aws_eip.app.public_ip, ".", "-")}.sslip.io"
}
