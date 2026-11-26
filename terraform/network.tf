resource "aws_vpc" "main" {
  #checkov:skip=CKV2_AWS_11:Flow logs gerariam custo de CloudWatch; fora do escopo da feira
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

# O Security Group padrão da VPC fica sem nenhuma regra (nada usa esse grupo)
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-default-sg-bloqueado"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# Sub-rede pública: somente a VM da aplicação
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = local.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-public"
    Tier = "public"
  }
}

# Sub-rede privada: VM exclusiva do MongoDB, sem IP público
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = local.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-private"
    Tier = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# A saída da sub-rede privada passa pela VM da aplicação (NAT instance configurada pelo Ansible),
# evitando o custo fixo de um NAT Gateway.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.app.primary_network_interface_id
  }

  tags = {
    Name = "${local.name_prefix}-rt-private"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Endpoint de gateway do S3 (sem custo): backups saem da VM do banco direto para o S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "${local.name_prefix}-s3-endpoint"
  }
}
