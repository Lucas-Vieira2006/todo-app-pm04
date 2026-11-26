#!/usr/bin/env bash
# Executa os roles reais do projeto contra os alvos de teste e grava os logs nesta pasta.
#  1-3: roles de sistema (os_updates, packages, system, docker, nat_gateway, data_volume)
#  4-6: roles de contêiner (mongodb, backup, app_stack) com imagens substitutas
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/../../../ansible" || exit 1
export ANSIBLE_CONFIG="$PWD/ansible.cfg" ANSIBLE_ROLES_PATH="$PWD/roles" ANSIBLE_NOCOLOR=1
MONGO_ROOT_PASSWORD="$(openssl rand -base64 24)"; MONGO_APP_PASSWORD="$(openssl rand -base64 24)"
export MONGO_ROOT_PASSWORD MONGO_APP_PASSWORD
LOGS="$HERE/logs"; mkdir -p "$LOGS"

run() {
  local name="$1" play="$2" vars="$3"
  echo "### $name ($(date -Is))" | tee "$LOGS/$name.log"
  ansible-playbook -i "$HERE/inventory.yml" "$HERE/$play" \
    -e @group_vars/all.yml -e @group_vars/app.yml -e @group_vars/db.yml -e @"$HERE/$vars" >> "$LOGS/$name.log" 2>&1
  local rc=$?
  echo "### exit=$rc" >> "$LOGS/$name.log"
  echo "$name: exit=$rc"; grep -E ' : ok=' "$LOGS/$name.log"
}

if [[ "${1:-}" != "conteineres" ]]; then
  run 01-sistema-criacao            playbook-roles.yml      vars-execucao-1.json
  run 02-sistema-mesmos-parametros  playbook-roles.yml      vars-execucao-2-mesmos-parametros.json
  run 03-sistema-novos-pacotes      playbook-roles.yml      vars-execucao-3-novos-pacotes.json
fi

# Imagens substitutas com os mesmos nomes usados pelos roles (sem acesso a registros públicos)
DBIP="$(docker exec pm04-db hostname -I | awk '{print $1}')"
for f in "$HERE"/vars-containers-*.json; do
  jq --arg ip "$DBIP" '.db_private_ip = $ip' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
for n in app db; do
  docker exec "pm04-$n" sh -c 'docker rm -f $(docker ps -aq) 2>/dev/null; docker image prune -af' >/dev/null 2>&1
  docker exec -i "pm04-$n" docker load < /tmp/standin.tar >/dev/null
done

run 04-conteineres-tag-inicial    playbook-containers.yml vars-containers-A-tag-inicial.json
run 05-conteineres-mesma-tag      playbook-containers.yml vars-containers-B-mesma-tag.json
run 06-conteineres-tag-nova       playbook-containers.yml vars-containers-C-tag-nova.json

{
  echo "### Estado final dos alvos ($(date -Is))"
  for n in app db; do
    echo "== pm04-$n"
    docker exec "pm04-$n" sh -c 'docker ps --format "{{.Names}}\t{{.Image}}\t{{.Status}}"; systemctl is-enabled docker; cat /opt/todo-app/release.json 2>/dev/null; findmnt -no SOURCE,FSTYPE /srv/mongo-data 2>/dev/null; crontab -l 2>/dev/null | grep todo; iptables -t nat -S POSTROUTING | grep 10.20 || true'
  done
} > "$LOGS/07-estado-final.txt" 2>&1
cat "$LOGS/07-estado-final.txt"
