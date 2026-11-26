#!/usr/bin/env bash
# Abre ou fecha o SSH (porta 22) da VM da aplicação apenas para o IP do runner atual.
# uso: ssh-access.sh open|close <security-group-id>
# A regra é criada fora do Terraform (não entra no state) e sempre removida ao final do job.
set -euo pipefail

action="$1"; sg="$2"
prefix="pipeline-ssh"

case "$action" in
  open)
    ip="$(curl -fsS --max-time 10 https://checkip.amazonaws.com | tr -d '[:space:]')"
    [[ "$ip" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || { echo "::error::IP do runner não identificado"; exit 1; }
    aws ec2 authorize-security-group-ingress --group-id "$sg" \
      --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$ip/32,Description=$prefix-${GITHUB_RUN_ID:-local}}]" \
      >/dev/null
    echo "SSH temporário liberado para $ip/32"
    ;;
  close)
    # Remove todas as regras temporárias da pipeline (inclusive de execuções canceladas)
    ids="$(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$sg" \
      --query "SecurityGroupRules[?FromPort==\`22\` && starts_with(Description || '', '$prefix')].SecurityGroupRuleId" \
      --output text)"
    if [[ -n "$ids" && "$ids" != "None" ]]; then
      # shellcheck disable=SC2086
      aws ec2 revoke-security-group-ingress --group-id "$sg" --security-group-rule-ids $ids >/dev/null
      echo "SSH temporário removido: $ids"
    else
      echo "Nenhuma regra SSH temporária encontrada"
    fi
    ;;
  *)
    echo "uso: $0 open|close <security-group-id>"; exit 2 ;;
esac
