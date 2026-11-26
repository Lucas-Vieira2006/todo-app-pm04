#!/usr/bin/env bash
# Valida e normaliza os parâmetros da pipeline (etapa 1).
# Lê os valores de variáveis de ambiente IN_* (nunca interpolados direto no shell do workflow)
# e gera $RUNNER_TEMP/pipeline-vars.json para o Ansible.
set -euo pipefail

fail() { echo "::error::$1"; exit 1; }

[[ "${IN_ENVIRONMENT:-}" =~ ^(dev|homolog|prod)$ ]] || fail "environment inválido: '${IN_ENVIRONMENT:-}' (use dev, homolog ou prod)"
[[ "${IN_INSTANCE_NAME:-}" =~ ^[a-z][a-z0-9-]{2,30}$ ]] || fail "instance_name inválido: use 3 a 31 caracteres minúsculos, números e hífen"
[[ "${IN_INSTANCE_TYPE:-}" =~ ^t3\.(micro|small|medium)$ ]] || fail "instance_type não permitido: ${IN_INSTANCE_TYPE:-}"
[[ "${IN_DB_INSTANCE_TYPE:-}" =~ ^t3\.(micro|small|medium)$ ]] || fail "db_instance_type não permitido: ${IN_DB_INSTANCE_TYPE:-}"

# Imagem: vazio = imagens publicadas por este repositório no GHCR
image="${IN_DOCKER_IMAGE:-}"
[[ -n "$image" ]] || image="ghcr.io/${REPO_OWNER:?}/todo-app"
image="${image,,}"
[[ "$image" =~ ^[a-z0-9][a-z0-9._/-]+$ ]] || fail "docker_image inválido: $image"

tag="${IN_DOCKER_TAG:-}"
[[ "$tag" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]] || fail "docker_tag inválido: '$tag'"
if [[ "$tag" == "latest" ]]; then
  echo "::warning::docker_tag=latest não é reproduzível; prefira a tag sha-<commit> gerada pela pipeline App"
fi

[[ "${IN_UPDATE_OS:-}" =~ ^(true|false)$ ]] || fail "update_os deve ser true ou false"

# extra_packages: lista separada por vírgula ou espaço
packages_json="$(printf '%s' "${IN_EXTRA_PACKAGES:-}" | tr -s ', ' '\n' | sed '/^$/d' | sort -u | jq -R . | jq -cs .)"
while read -r pkg; do
  [[ "$pkg" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || fail "pacote inválido em extra_packages: '$pkg'"
done < <(jq -r '.[]' <<<"$packages_json")

out="${RUNNER_TEMP:-/tmp}/pipeline-vars.json"
jq -n \
  --arg env "$IN_ENVIRONMENT" \
  --arg image "$image" \
  --arg tag "$tag" \
  --argjson update_os "$IN_UPDATE_OS" \
  --argjson packages "$packages_json" \
  --arg run_id "${GITHUB_RUN_ID:-local}" \
  '{deploy_env: $env, docker_image: $image, docker_tag: $tag, update_os: $update_os, extra_packages: $packages, verify_run_id: $run_id}' > "$out"

echo "Parâmetros validados:"
jq . "$out"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "docker_image=$image"
    echo "docker_tag=$tag"
    echo "extra_packages=$packages_json"
    echo "vars_file=$out"
  } >> "$GITHUB_OUTPUT"
fi
