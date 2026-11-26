resource "aws_key_pair" "deploy" {
  key_name   = "${local.name_prefix}-deploy"
  public_key = var.ssh_public_key
}

# --- VM 1: aplicação (Caddy + Nginx/React + API) e NAT da sub-rede privada -----
resource "aws_instance" "app" {
  #checkov:skip=CKV_AWS_126:Monitoramento detalhado é cobrado por instância; métricas básicas bastam para a feira
  #checkov:skip=CKV2_AWS_41:A VM da aplicação não usa APIs da AWS; sem papel IAM (menor privilégio)
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.deploy.key_name

  # Necessário para encaminhar o tráfego da VM do banco (NAT instance)
  source_dest_check = false
  ebs_optimized     = true

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.app_root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = var.instance_name
    Role = "app"
  }

  lifecycle {
    # A AMI é escolhida só na criação; atualizações do SO ficam com o Ansible.
    ignore_changes = [ami]
  }
}

resource "aws_eip" "app" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-app-eip"
  }
}

resource "aws_eip_association" "app" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app.id
}

# --- VM 2: MongoDB exclusivo, sem IP público ------------------------------------
resource "aws_instance" "db" {
  #checkov:skip=CKV_AWS_126:Monitoramento detalhado é cobrado por instância; métricas básicas bastam para a feira
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.db_instance_type
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.db.id]
  key_name                    = aws_key_pair.deploy.key_name
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.db.name
  ebs_optimized               = true

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.db_root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.instance_name}-db"
    Role = "db"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}
