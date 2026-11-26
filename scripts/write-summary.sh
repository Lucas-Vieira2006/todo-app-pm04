#!/usr/bin/env bash
# Resumo da execução da pipeline Infra (etapa 12), em Markdown para o GITHUB_STEP_SUMMARY.
set -uo pipefail

dir="${EVIDENCE_DIR:-run-evidence}"
val() { jq -r --arg k "$1" '.[$k] // "-"' "$dir/terraform-outputs.json" 2>/dev/null || echo "-"; }
recap() { [[ -f "$1" ]] && sed 's/\x1b\[[0-9;]*m//g' "$1" | sed -n '/PLAY RECAP/,$p' | grep -E ' : ok=' || echo "(não executado)"; }

cat <<MD
## Resumo da execução: ${JOB_STATUS:-?}

**Parâmetros**

- environment: \`${IN_ENVIRONMENT:-}\`
- instance_name: \`${IN_INSTANCE_NAME:-}\` | instance_type: \`${IN_INSTANCE_TYPE:-}\` | db_instance_type: \`${IN_DB_INSTANCE_TYPE:-}\`
- imagem: \`${OUT_IMAGE:-}-{frontend,backend}:${OUT_TAG:-}\`
- update_os: \`${IN_UPDATE_OS:-}\` | extra_packages: \`${OUT_PACKAGES:-}\` | plan_only: \`${IN_PLAN_ONLY:-}\`

**Terraform**

- Plano: $(cat "$dir/plan-summary.txt" 2>/dev/null || echo "-")
- URL: $(val app_url)
- VM aplicação: $(val app_instance_id) ($(val app_instance_type)), IP público $(val app_public_ip)
- VM banco: $(val db_instance_id) ($(val db_instance_type)), IP privado $(val db_private_ip), IP público: $(val db_has_public_ip)
- Volume de dados: $(val db_data_volume_id)

**Ansible (PLAY RECAP do playbook de configuração)**

\`\`\`
$(recap "$dir/ansible-playbook.log")
\`\`\`

**Verificação externa**

\`\`\`
$(cat "$dir/external-checks.txt" 2>/dev/null || echo "(não executada)")
\`\`\`
MD
