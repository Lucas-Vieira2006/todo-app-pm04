#!/usr/bin/env bash
# Teste de integração LOCAL (fora da nuvem) da aplicação adaptada e dos scripts de operação.
#
# Ambiente: o sandbox de desenvolvimento não acessa Docker Hub, GHCR nem a AWS. Por isso os
# componentes rodam como processos locais, com as mesmas versões principais usadas na nuvem:
#   - MongoDB 8.0.x real (binários conda-forge), mongosh e mongodump/mongorestore reais;
#   - API Node.js 22 (backend/index.js do repositório);
#   - build de produção do React servido por Nginx com frontend/nginx.conf;
#   - Caddy com HTTPS (certificado interno, pois não há domínio público);
#   - S3 simulado com moto (os scripts usam boto3 real apontando para o simulador);
#   - um "shim" do comando docker que executa localmente os comandos de "docker exec/cp/run/rm".
# Os scripts de backup/restauração/limpeza são renderizados pelo próprio Ansible a partir dos templates.
#
# O que este teste NÃO cobre: imagens Docker reais, Terraform na AWS, Let's Encrypt e a rede da VPC.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
MONGO_BIN="${MONGO_BIN:-/home/claude/tools/conda/env/bin}"
MONGO_LIB="$(dirname "$MONGO_BIN")/lib"
W=/tmp/todo-it
DOMAIN=todo.localtest
ROOT_PW='Root-Teste/2026@#x9QwErTy'
APP_PW='App:Teste/2026?pw#Zx8@Lk'
pass=0; failn=0
ok()   { echo "  [OK]    $*"; pass=$((pass+1)); }
bad()  { echo "  [FALHA] $*"; failn=$((failn+1)); }
check(){ local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
step() { echo; echo "== $* =="; }

cleanup() {
  set +e
  pkill -f "node index.js" ; nginx -c "$W/nginx.conf" -s stop 2>/dev/null; pkill -x caddy; pkill -f moto_server
  LD_LIBRARY_PATH="$MONGO_LIB" "$MONGO_BIN/mongod" --shutdown --dbpath "$W/data" >/dev/null 2>&1
  LD_LIBRARY_PATH="$MONGO_LIB" "$MONGO_BIN/mongod" --shutdown --dbpath "$W/restore-data" >/dev/null 2>&1
}
trap cleanup EXIT
cleanup; rm -rf "$W" /srv/backups /docker-entrypoint-initdb.d /run/secrets/todo
mkdir -p "$W"/{data,bin,logs} /srv/backups /run/secrets/todo /docker-entrypoint-initdb.d
# Wrappers: só os binários do MongoDB usam as bibliotecas do conda-forge
for b in mongod mongodump mongorestore; do
  printf '#!/bin/sh\nLD_LIBRARY_PATH="%s" exec "%s/%s" "$@"\n' "$MONGO_LIB" "$MONGO_BIN" "$b" > "$W/bin/$b"
  chmod +x "$W/bin/$b"
done
export PATH="$W/bin:$PATH"
# Tráfego local não passa pelo proxy de saída do sandbox
export NO_PROXY="localhost,127.0.0.1,$DOMAIN" no_proxy="localhost,127.0.0.1,$DOMAIN"

step "1. Versões"
mongod --version | head -1; mongosh --version | sed 's/^/mongosh /'; mongodump --version | head -1
node --version | sed 's/^/node /'; nginx -v 2>&1; caddy version | sed 's/^/caddy /'

step "2. Banco: inicialização igual ao entrypoint da imagem oficial (root + init-mongo.js + seed.json)"
cp "$REPO/banco-de-dados/init-mongo.js" "$REPO/banco-de-dados/seed.json" /docker-entrypoint-initdb.d/
printf '%s' "$ROOT_PW" > /run/secrets/todo/root_password
printf '%s' todo_app > /run/secrets/todo/app_user
printf '%s' "$APP_PW" > /run/secrets/todo/app_password
python3 -c 'import json,sys; print("password: "+json.dumps(sys.argv[1]))' "$ROOT_PW" > /run/secrets/todo/mongotools.yaml
chmod 400 /run/secrets/todo/*
mongod --port 27017 --bind_ip 127.0.0.1 --dbpath "$W/data" --fork --logpath "$W/logs/mongod-init.log" >/dev/null
mongosh --quiet --port 27017 admin --eval "db.createUser({user:'root',pwd:'$ROOT_PW',roles:['root']})" >/dev/null
MONGO_APP_USER_FILE=/run/secrets/todo/app_user MONGO_APP_PASSWORD_FILE=/run/secrets/todo/app_password \
  mongosh --quiet --port 27017 -u root -p "$ROOT_PW" --authenticationDatabase admin todo-app /docker-entrypoint-initdb.d/init-mongo.js
mongod --shutdown --dbpath "$W/data" >/dev/null
mongod --port 27017 --bind_ip 127.0.0.1 --dbpath "$W/data" --auth --wiredTigerCacheSizeGB 0.25 --fork --logpath "$W/logs/mongod.log" >/dev/null
COUNT=$(mongosh --quiet --port 27017 -u todo_app -p "$APP_PW" --authenticationDatabase todo-app todo-app --eval 'db.todos.countDocuments()')
[[ "$COUNT" == 3 ]] && ok "usuário todo_app autentica e lê as 3 tarefas de demonstração" || bad "seed esperado 3, obtido $COUNT"
if mongosh --quiet --port 27017 -u todo_app -p "$APP_PW" --authenticationDatabase todo-app todo-app \
     --eval 'db.getSiblingDB("outro-banco").teste.insertOne({x:1})' >/dev/null 2>&1; then
  bad "usuário da aplicação não deveria gravar em outro banco"
else ok "usuário da aplicação não grava fora do banco todo-app"; fi
if mongosh --quiet --port 27017 -u todo_app -p "$APP_PW" --authenticationDatabase todo-app todo-app \
     --eval 'db.getSiblingDB("admin").createUser({user:"intruso",pwd:"x",roles:["root"]})' >/dev/null 2>&1; then
  bad "usuário da aplicação não deveria criar usuários"
else ok "usuário da aplicação não cria usuários (sem privilégio administrativo)"; fi
if mongosh --quiet --port 27017 todo-app --eval 'db.todos.countDocuments()' >/dev/null 2>&1; then bad "acesso sem senha permitido"; else ok "acesso anônimo negado (autenticação ativa)"; fi

step "3. API: comportamento de inicialização"
cd "$REPO/backend"
set +e
timeout 10 node index.js >"$W/logs/api-sem-uri.log" 2>&1; c1=$?
MONGO_URI="mongodb://x:y@127.0.0.1:27999/todo-app?serverSelectionTimeoutMS=2000" timeout 20 node index.js >"$W/logs/api-sem-banco.log" 2>&1; c2=$?
set -e
[[ $c1 == 1 ]] && ok "sem MONGO_URI a API encerra com código 1" || bad "sem MONGO_URI código $c1"
[[ $c2 == 1 ]] && ok "banco indisponível: API encerra com código 1 (Docker reinicia o contêiner)" || bad "banco indisponível código $c2"

# MONGO_URI montada com a mesma expressão do role app_stack (senha com / @ : ? # codificada)
MONGO_URI=$(cd "$REPO/ansible" && ansible localhost -m debug -a "msg={{ 'mongodb://todo_app:' ~ (pw | urlencode | replace('/', '%2F')) ~ '@127.0.0.1:27017/todo-app?authSource=todo-app' }}" -e "pw=$APP_PW" 2>/dev/null | sed -n 's/^ *msg: //p')
MONGO_URI="$MONGO_URI" CORS_ORIGIN="https://$DOMAIN" NODE_ENV=production nohup node index.js >"$W/logs/api.log" 2>&1 &
for _ in $(seq 1 20); do grep -q "Conectado ao MongoDB" "$W/logs/api.log" && break; sleep 1; done
check "API conectada ao MongoDB com a credencial própria (senha com caracteres especiais)" grep -q "Conectado ao MongoDB" "$W/logs/api.log"
check "healthcheck do contêiner (wget GET /todos) responde" wget -q -O /dev/null http://127.0.0.1:5000/todos
ACAO=$(curl -s -o /dev/null -D - -H "Origin: https://$DOMAIN" http://127.0.0.1:5000/todos | grep -i '^access-control-allow-origin' | tr -d '\r' || true)
[[ "$ACAO" == *"https://$DOMAIN"* ]] && ok "CORS libera a origem configurada ($ACAO)" || bad "CORS origem configurada: '$ACAO'"
ACAO2=$(curl -s -o /dev/null -D - -H "Origin: https://site-externo.example" http://127.0.0.1:5000/todos | grep -ci '^access-control-allow-origin: https://site-externo' || true)
[[ "$ACAO2" == 0 ]] && ok "CORS não libera outra origem" || bad "CORS liberou origem externa"

step "4. Frontend: build de produção + Nginx (frontend/nginx.conf)"
cd "$REPO/frontend"
[[ -d build ]] || (npm ci --no-audit --no-fund && CI=true npm run build) >"$W/logs/frontend-build.log" 2>&1
if grep -rq "localhost:5000" build/; then bad "build ainda contém localhost:5000"; else ok "build sem endereço fixo localhost:5000"; fi
mkdir -p "$W/nginx/conf.d"
cp "$REPO/frontend/proxy_headers.inc" "$W/nginx/conf.d/"
# Diferenças apenas de ambiente: porta 8080, raiz local e upstream 127.0.0.1 em vez do DNS do Docker
sed -e "s#listen 80;#listen 8080;#" -e "s#/usr/share/nginx/html#$REPO/frontend/build#" \
    -e "/resolver 127.0.0.11/d" -e "s#http://backend:5000#http://127.0.0.1:5000#" \
    -e "s#/etc/nginx/conf.d/proxy_headers.inc#$W/nginx/conf.d/proxy_headers.inc#" \
    "$REPO/frontend/nginx.conf" > "$W/nginx/conf.d/default.conf"
cat > "$W/nginx.conf" <<NGX
pid $W/nginx.pid;
error_log $W/logs/nginx-error.log;
events {}
http { include /etc/nginx/mime.types; access_log $W/logs/nginx-access.log; include $W/nginx/conf.d/default.conf; }
NGX
nginx -t -c "$W/nginx.conf" 2>&1 | tail -1
nginx -c "$W/nginx.conf"
check "Nginx serve o index.html do React" sh -c "curl -fsS http://127.0.0.1:8080/ | grep -q '<div id=\"root\">'"
check "Nginx encaminha GET /todos para a API" sh -c "curl -fsS http://127.0.0.1:8080/todos | jq -e 'length==3'"
check "rota do React (/qualquer) devolve index.html" sh -c "curl -fsS http://127.0.0.1:8080/qualquer | grep -q 'id=\"root\"'"

step "5. Caddy: HTTPS na frente do Nginx (Caddyfile renderizado pelo Ansible)"
(cd "$REPO/ansible" && ansible localhost -m template -a "src=roles/app_stack/templates/Caddyfile.j2 dest=$W/Caddyfile.prod" -e "app_domain=$DOMAIN" >/dev/null 2>&1)
cat "$W/Caddyfile.prod" | sed 's/^/    /'
{ printf '{\n\thttp_port 8081\n\thttps_port 8443\n\tadmin off\n}\n'; sed -e "s#^$DOMAIN {#$DOMAIN {\n\ttls internal#" -e "s#frontend:80#127.0.0.1:8080#" "$W/Caddyfile.prod"; } > "$W/Caddyfile"
caddy validate --config "$W/Caddyfile" --adapter caddyfile >/dev/null 2>&1 && ok "Caddyfile válido" || bad "Caddyfile inválido"
XDG_DATA_HOME="$W/caddy" nohup caddy run --config "$W/Caddyfile" --adapter caddyfile >"$W/logs/caddy.log" 2>&1 &
C="curl -sk --resolve $DOMAIN:8443:127.0.0.1"
for _ in $(seq 1 20); do $C -o /dev/null "https://$DOMAIN:8443/" 2>/dev/null && break; sleep 1; done
check "HTTPS responde a página inicial" sh -c "$C -f https://$DOMAIN:8443/ | grep -q 'id=\"root\"'"

step "6. Fluxo funcional pelo endereço HTTPS (ACE-04): listar, cadastrar, concluir, reabrir, excluir, recarregar"
U="https://$DOMAIN:8443/todos"
L0=$($C "$U" | jq length)
NEW=$($C -X POST -H 'Content-Type: application/json' -d '{"text":"Tarefa do teste local"}' -w '\n%{http_code}' "$U")
CODE=$(tail -1 <<<"$NEW"); ID=$(head -1 <<<"$NEW" | jq -r ._id)
[[ "$CODE" == 201 ]] && ok "POST /todos -> 201 (id $ID)" || bad "POST /todos -> $CODE"
[[ $($C -X PATCH "$U/$ID" | jq .completed) == true ]] && ok "PATCH /todos/:id conclui" || bad "PATCH concluir"
[[ $($C -X PATCH "$U/$ID" | jq .completed) == false ]] && ok "PATCH /todos/:id reabre" || bad "PATCH reabrir"
$C -X PATCH "$U/$ID" >/dev/null   # deixa concluída para conferir persistência
[[ $($C "$U" | jq "[.[]|select(._id==\"$ID\")][0].completed") == true ]] && ok "recarregar mostra estado salvo no banco" || bad "estado não persistiu"
DEL_ID=$($C -X POST -H 'Content-Type: application/json' -d '{"text":"Para excluir"}' "$U" | jq -r ._id)
[[ $($C -X DELETE "$U/$DEL_ID" | jq -r .message) == "Tarefa excluída com sucesso" ]] && ok "DELETE /todos/:id exclui" || bad "DELETE"
[[ $($C -o /dev/null -w '%{http_code}' -X DELETE "$U/$DEL_ID") == 404 ]] && ok "excluir de novo -> 404" || bad "DELETE repetido"
[[ $($C -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d '{}' "$U") == 400 ]] && ok "POST sem texto -> 400" || bad "validação POST"
L1=$($C "$U" | jq length)
[[ $L1 == $((L0+1)) ]] && ok "lista final: $L1 tarefas (eram $L0)" || bad "lista final $L1, esperado $((L0+1))"

step "7. Persistência: reinício do banco mantendo o diretório de dados (ACE-05)"
mongod --shutdown --dbpath "$W/data" >/dev/null
sleep 2
mongod --port 27017 --bind_ip 127.0.0.1 --dbpath "$W/data" --auth --wiredTigerCacheSizeGB 0.25 --fork --logpath "$W/logs/mongod.log" >/dev/null
for _ in $(seq 1 30); do $C -f "$U" >/dev/null 2>&1 && break; sleep 1; done
[[ $($C "$U" | jq "[.[]|select(._id==\"$ID\")][0].completed") == true ]] && ok "tarefa e estado preservados após reinício do banco" || bad "dados perdidos após reinício"

step "8. Backup, teste de restauração isolada, limpeza da lista e restauração (scripts reais renderizados pelo Ansible)"
# S3 simulado
nohup moto_server -H 127.0.0.1 -p 5005 >"$W/logs/moto.log" 2>&1 &
export AWS_ENDPOINT_URL=http://127.0.0.1:5005 AWS_ACCESS_KEY_ID=teste AWS_SECRET_ACCESS_KEY=teste AWS_DEFAULT_REGION=us-east-1
for _ in $(seq 1 20); do curl -s "$AWS_ENDPOINT_URL" >/dev/null 2>&1 && break; sleep 1; done
python3 -c "import boto3; boto3.client('s3').create_bucket(Bucket='todo-app-backups-teste')"
# Shim do docker: "docker exec <c> cmd" roda cmd localmente; o contêiner de teste usa a porta 27018
cat > "$W/bin/docker" <<'SHIM'
#!/bin/bash
case "$1" in
  exec)
    c="$2"; shift 2
    if [[ "$c" == todo-mongo-restore-test && "$1" =~ ^mongo ]]; then b="$1"; shift; exec "$b" --port 27018 "$@"; fi
    exec "$@" ;;
  cp)   exec cp "${2#*:}" "${3#*:}" ;;
  run)  rm -rf /tmp/todo-it/restore-data; mkdir -p /tmp/todo-it/restore-data
        exec /tmp/todo-it/bin/mongod --port 27018 --bind_ip 127.0.0.1 --dbpath /tmp/todo-it/restore-data --fork --logpath /tmp/todo-it/logs/mongod-restore.log --wiredTigerCacheSizeGB 0.25 ;;
  rm)   /tmp/todo-it/bin/mongod --shutdown --dbpath /tmp/todo-it/restore-data >/dev/null 2>&1; exit 0 ;;
  *)    echo "shim: comando não suportado: $*" >&2; exit 1 ;;
esac
SHIM
chmod +x "$W/bin/docker"
cat > "$W/vars.yml" <<VARS
backup_bucket: todo-app-backups-teste
aws_region: us-east-1
deploy_env: dev
VARS
for t in todo-s3 todo-backup todo-restore-test todo-restore todo-reset-demo; do
  (cd "$REPO/ansible" && ansible localhost -m template -e @group_vars/all.yml -e @"$W/vars.yml" \
     -a "src=roles/backup/templates/$t.j2 dest=/usr/local/sbin/$t mode=0750" >/dev/null 2>&1) || bad "render $t"
done
check "scripts renderizados com bash -n / py_compile" sh -c 'for f in todo-backup todo-restore-test todo-restore todo-reset-demo; do bash -n /usr/local/sbin/$f || exit 1; done; python3 -m py_compile /usr/local/sbin/todo-s3'

echo "-- todo-backup"
/usr/local/sbin/todo-backup | sed 's/^/    /'
check "backup local e manifesto criados" sh -c 'ls /srv/backups/*.archive.gz && ls /srv/backups/*.json'
check "backup enviado ao S3 (prefixo do ambiente)" sh -c "python3 -c \"import boto3; r=boto3.client('s3').list_objects_v2(Bucket='todo-app-backups-teste',Prefix='dev/'); assert r['KeyCount']==2, r\""

echo "-- todo-restore-test (contêiner isolado)"
BEFORE=$($C "$U" | jq length)
/usr/local/sbin/todo-restore-test | sed 's/^/    /'
check "restauração validada no ambiente isolado" sh -c "test \$(( \$(/usr/local/sbin/todo-restore-test 2>&1 | grep -c 'RESTAURAÇÃO VALIDADA') )) -eq 1"
[[ $($C "$U" | jq length) == "$BEFORE" ]] && ok "banco da demonstração não foi alterado pelo teste de restauração" || bad "teste de restauração alterou a demonstração"

echo "-- todo-reset-demo"
if /usr/local/sbin/todo-reset-demo >/dev/null 2>&1; then bad "reset sem --yes deveria recusar"; else ok "todo-reset-demo exige --yes"; fi
sleep 1; /usr/local/sbin/todo-reset-demo --yes 2>&1 | tail -1 | sed 's/^/    /'
[[ $($C "$U" | jq length) == 3 ]] && ok "lista da apresentação recarregada com as 3 tarefas de demonstração" || bad "reset não restaurou o seed"

echo "-- todo-restore (banco principal, backup anterior ao reset)"
FIRST=$(ls -1tr /srv/backups/*.archive.gz | head -1 | xargs basename)
sleep 1; /usr/local/sbin/todo-restore --yes "$FIRST" 2>&1 | tail -1 | sed 's/^/    /'
[[ $($C "$U" | jq length) == "$BEFORE" ]] && ok "restauração do backup $FIRST trouxe de volta $BEFORE tarefas" || bad "restore principal"

step "Resultado: $pass verificações OK, $failn falha(s)"
[[ $failn == 0 ]]
