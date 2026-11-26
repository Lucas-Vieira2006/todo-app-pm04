#!/usr/bin/env bash
# Gera o inventário do Ansible a partir dos outputs do Terraform (etapa 9).
# uso: render-inventory.sh <tf-outputs.json> <inventario.yml> <chave-privada>
set -euo pipefail

outputs="$1"; inventory="$2"; key="$3"
o() { jq -er --arg k "$1" '.[$k].value' "$outputs"; }

app_ip="$(o app_public_ip)"
db_ip="$(o db_private_ip)"
[[ "$(o db_has_public_ip)" == "false" ]] || { echo "::error::A VM do banco possui IP público"; exit 1; }

cat > "$inventory" <<YAML
# Gerado por scripts/render-inventory.sh a partir dos outputs do Terraform. Não versionar.
all:
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: "$key"
    deploy_env: "$(o environment)"
    aws_region: "$(o aws_region)"
    app_domain: "$(o app_domain)"
    app_public_ip: "$app_ip"
    app_private_ip: "$(o app_private_ip)"
    db_private_ip: "$db_ip"
    db_data_volume_id: "$(o db_data_volume_id)"
    private_subnet_cidr: "$(o private_subnet_cidr)"
    backup_bucket: "$(o backup_bucket)"
  children:
    app:
      hosts:
        app-1:
          ansible_host: "$app_ip"
    db:
      hosts:
        db-1:
          ansible_host: "$db_ip"
          # O banco não tem IP público: acesso SSH pela VM da aplicação
          ansible_ssh_common_args: >-
            -o ProxyCommand="ssh -i $key -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 -W %h:%p ubuntu@$app_ip"
YAML

echo "Inventário gerado: app=$app_ip db=$db_ip (via bastion)"
