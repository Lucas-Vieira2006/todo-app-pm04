# Regras como recursos separados: regras temporárias criadas pela pipeline
# (SSH do runner) não entram no state e não são removidas pelo Terraform.

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "VM da aplicacao: HTTP/HTTPS publico"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-app-sg"
  }
}

resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db-sg"
  description = "VM do MongoDB: acesso somente a partir da VM da aplicacao"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-db-sg"
  }
}

# --- VM da aplicação -------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "app_http" {
  #checkov:skip=CKV_AWS_260:Porta 80 pública é necessária para a validação HTTP-01 do Let's Encrypt e o redirecionamento para HTTPS
  security_group_id = aws_security_group.app.id
  description       = "HTTP publico (redirecionamento e validacao do certificado)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS publico"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# SSH permanente apenas para as redes administrativas informadas (vazio por padrão)
resource "aws_vpc_security_group_ingress_rule" "app_ssh_admin" {
  for_each = toset(var.admin_cidrs)

  security_group_id = aws_security_group.app.id
  description       = "SSH administrativo"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

# Tráfego da VM do banco encaminhado pelo NAT (HTTP/HTTPS para pacotes e imagens)
resource "aws_vpc_security_group_ingress_rule" "app_nat_from_db" {
  #checkov:skip=CKV_AWS_260:Origem é o Security Group do banco, não a internet
  for_each = toset(["80", "443"])

  security_group_id            = aws_security_group.app.id
  description                  = "NAT da sub-rede privada"
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Saida liberada"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- VM do banco -----------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "db_mongo_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "MongoDB somente a partir da API"
  ip_protocol                  = "tcp"
  from_port                    = 27017
  to_port                      = 27017
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "db_ssh_from_app" {
  #checkov:skip=CKV_AWS_24:Origem é o Security Group da aplicação (bastion), não a internet
  security_group_id            = aws_security_group.db.id
  description                  = "SSH via VM da aplicacao (bastion)"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "db_all" {
  security_group_id = aws_security_group.db.id
  description       = "Saida via NAT e endpoint S3"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
