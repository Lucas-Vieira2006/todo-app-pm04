output "environment" {
  description = "Ambiente provisionado."
  value       = var.environment
}

output "app_url" {
  description = "Endereço público HTTPS da aplicação."
  value       = "https://${local.app_domain}"
}

output "app_domain" {
  description = "Domínio usado pelo Caddy para emitir o certificado."
  value       = local.app_domain
}

output "app_public_ip" {
  description = "Elastic IP da VM da aplicação."
  value       = aws_eip.app.public_ip
}

output "app_private_ip" {
  description = "IP privado da VM da aplicação."
  value       = aws_instance.app.private_ip
}

output "app_instance_id" {
  description = "ID da VM da aplicação."
  value       = aws_instance.app.id
}

output "app_instance_type" {
  description = "Tipo atual da VM da aplicação."
  value       = aws_instance.app.instance_type
}

output "app_security_group_id" {
  description = "Security Group da VM da aplicação (usado pela pipeline para o SSH temporário)."
  value       = aws_security_group.app.id
}

output "db_private_ip" {
  description = "IP privado da VM do MongoDB."
  value       = aws_instance.db.private_ip
}

output "db_instance_id" {
  description = "ID da VM do MongoDB."
  value       = aws_instance.db.id
}

output "db_instance_type" {
  description = "Tipo atual da VM do MongoDB."
  value       = aws_instance.db.instance_type
}

output "db_has_public_ip" {
  description = "Deve ser false: o banco não tem endereço público."
  value       = aws_instance.db.public_ip != ""
}

output "db_data_volume_id" {
  description = "Volume EBS de dados do MongoDB."
  value       = aws_ebs_volume.mongo_data.id
}

output "private_subnet_cidr" {
  description = "Sub-rede privada (usada na regra de NAT)."
  value       = aws_subnet.private.cidr_block
}

output "backup_bucket" {
  description = "Bucket de backups."
  value       = var.backup_bucket_name
}

output "aws_region" {
  description = "Região do ambiente."
  value       = var.aws_region
}
