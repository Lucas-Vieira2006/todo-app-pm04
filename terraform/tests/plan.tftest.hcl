# Testes da configuração sem acessar a AWS (provider simulado).
# Executar: terraform test  (ou tofu test)

mock_provider "aws" {
  override_data {
    target = data.aws_ami.ubuntu
    values = {
      id = "ami-0123456789abcdef0"
    }
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }

  override_data {
    target = data.aws_iam_policy_document.ec2_assume
    values = {
      json = "{}"
    }
  }

  override_data {
    target = data.aws_iam_policy_document.db_backup
    values = {
      json = "{}"
    }
  }

  mock_resource "aws_eip" {
    defaults = {
      public_ip = "203.0.113.10"
    }
  }
}

variables {
  environment        = "dev"
  instance_name      = "vm-pm04"
  instance_type      = "t3.micro"
  db_instance_type   = "t3.micro"
  ssh_public_key     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKeyOnly test@local"
  backup_bucket_name = "todo-app-backups-000000000000"
}

run "arquitetura_minima" {
  command = apply

  assert {
    condition     = aws_instance.app.subnet_id == aws_subnet.public.id && aws_instance.db.subnet_id == aws_subnet.private.id
    error_message = "A aplicação deve ficar na sub-rede pública e o banco na privada."
  }

  assert {
    condition     = aws_instance.db.associate_public_ip_address == false && aws_subnet.private.map_public_ip_on_launch == false
    error_message = "A VM do banco não pode ter IP público."
  }

  assert {
    condition     = aws_instance.app.tags["Name"] == "vm-pm04" && aws_instance.db.tags["Name"] == "vm-pm04-db"
    error_message = "instance_name deve definir o nome das VMs."
  }

  assert {
    condition     = aws_instance.app.source_dest_check == false
    error_message = "A VM da aplicação precisa de source_dest_check=false para atuar como NAT."
  }

  assert {
    condition     = output.app_url == "https://203-0-113-10.sslip.io"
    error_message = "Sem domínio próprio, a URL deve usar sslip.io com o Elastic IP."
  }
}

run "isolamento_do_banco" {
  command = apply

  assert {
    condition     = aws_vpc_security_group_ingress_rule.db_mongo_from_app.from_port == 27017 && aws_vpc_security_group_ingress_rule.db_mongo_from_app.referenced_security_group_id == aws_security_group.app.id
    error_message = "A porta 27017 deve aceitar somente o Security Group da aplicação."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.db_mongo_from_app.cidr_ipv4 == null
    error_message = "A regra do MongoDB não pode usar CIDR (internet)."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.app_ssh_admin) == 0
    error_message = "Sem admin_cidrs, não deve haver SSH permanente."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_http.from_port == 80 && aws_vpc_security_group_ingress_rule.app_https.from_port == 443
    error_message = "A aplicação deve expor 80 e 443."
  }
}

run "persistencia_e_seguranca" {
  command = apply

  assert {
    condition     = aws_ebs_volume.mongo_data.encrypted && aws_ebs_volume.mongo_data.type == "gp3" && aws_ebs_volume.mongo_data.availability_zone == aws_subnet.private.availability_zone
    error_message = "O volume de dados deve ser gp3, criptografado e na mesma zona da sub-rede do banco."
  }

  assert {
    condition     = aws_instance.app.metadata_options[0].http_tokens == "required" && aws_instance.db.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 deve ser obrigatório."
  }

  assert {
    condition     = aws_instance.app.credit_specification[0].cpu_credits == "standard" && aws_instance.db.credit_specification[0].cpu_credits == "standard"
    error_message = "Créditos de CPU devem ficar em standard (sem cobrança extra)."
  }

  assert {
    condition     = aws_instance.app.root_block_device[0].encrypted && aws_instance.db.root_block_device[0].encrypted
    error_message = "Discos raiz devem ser criptografados."
  }
}

run "dominio_proprio" {
  command = apply

  variables {
    app_domain = "todo.exemplo.com.br"
  }

  assert {
    condition     = output.app_url == "https://todo.exemplo.com.br"
    error_message = "app_domain deve substituir o sslip.io."
  }
}

run "rejeita_tipo_nao_permitido" {
  command = plan

  variables {
    instance_type = "m5.4xlarge"
  }

  expect_failures = [var.instance_type]
}

run "rejeita_ssh_aberto_para_internet" {
  command = plan

  variables {
    admin_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.admin_cidrs]
}

run "rejeita_ambiente_invalido" {
  command = plan

  variables {
    environment = "teste"
  }

  expect_failures = [var.environment]
}
