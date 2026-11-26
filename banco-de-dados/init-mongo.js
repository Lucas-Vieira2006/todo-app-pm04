// Executado pela imagem oficial do MongoDB somente na primeira inicialização (diretório de dados vazio).
const fs = require('fs');

// Lê um valor de VAR_FILE (arquivo de segredo) ou de VAR (variável de ambiente)
function secret(name) {
  const file = process.env[`${name}_FILE`];
  if (file) {
    return fs.readFileSync(file, 'utf8').trim();
  }
  return process.env[name];
}

db = db.getSiblingDB('todo-app');

// Usuário próprio da aplicação, com acesso apenas ao banco todo-app.
const appUser = secret('MONGO_APP_USER');
const appPassword = secret('MONGO_APP_PASSWORD');
if (appUser && appPassword) {
  db.createUser({
    user: appUser,
    pwd: appPassword,
    roles: [{ role: 'readWrite', db: 'todo-app' }],
  });
}

// Dados iniciais de demonstração (mesmo arquivo usado pela rotina de limpeza da lista)
const seed = JSON.parse(fs.readFileSync('/docker-entrypoint-initdb.d/seed.json', 'utf8'));
db.createCollection('todos');
db.todos.insertMany(seed);
