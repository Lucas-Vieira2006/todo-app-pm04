# Decisões arquiteturais

Registro das decisões tomadas antes da implementação. Cada decisão indica se atende a um requisito explícito (escopo.pdf ou PM-04) ou se é uma escolha técnica da equipe.

Legenda de origem:

- ESC = requisito explícito do escopo.pdf (documento de demanda)
- PM04 = requisito explícito do PM-04 (critérios da disciplina)
- DEC = decisão técnica da equipe (não está escrita nos documentos)

## 1. Análise da aplicação

O ToDo App tem três componentes:

- frontend: React 19 (create-react-app / react-scripts 5) compilado e servido por Nginx;
- backend: Node.js com Express e Mongoose, porta 5000, rotas GET/POST /todos e PATCH/DELETE /todos/:id;
- banco: MongoDB com script de dados iniciais (init-mongo.js, três tarefas de demonstração).

Problemas encontrados no repositório original que impedem a implantação em nuvem (todos citados na seção 5 do escopo):

- o frontend chama `http://localhost:5000` fixo (não funciona fora da máquina local);
- a string de conexão do MongoDB, com usuário root e senha, está fixa em `backend/index.js`;
- o Compose publica a porta 27017, usa credenciais de demonstração e não tem volume nomeado;
- CORS aberto para qualquer origem;
- a API não tem verificação de prontidão: se o banco não estiver disponível na inicialização, o Mongoose falha e o processo continua rodando sem conexão;
- `mongo:latest` e `node:18-alpine` (Node 18 fora de suporte desde abril de 2025).

Necessidades identificadas: duas VMs Linux, rede privada entre elas, portas públicas 80/443 somente na VM da aplicação, porta 27017 somente na rede privada, disco persistente para o banco, armazenamento externo para backups, registro de imagens para versões identificáveis e um endereço HTTPS.

## 2. Decisões

| ID | Decisão | Origem | Justificativa |
|----|---------|--------|---------------|
| D01 | Provedor AWS, região us-east-1 | DEC (provedor livre: ESC 2 e PM04 3.2) | A equipe já tem conta AWS com créditos; us-east-1 tem o menor preço para t3. Suporte maduro no Terraform e OIDC nativo com GitHub Actions. |
| D02 | Duas VMs EC2: `app` (Caddy, Nginx/React, API) e `db` (MongoDB exclusivo) | ESC REQ-01, ACE-02 | Mínimo exigido. Não foram criados recursos adicionais pagos (load balancer, RDS, NAT Gateway). |
| D03 | t3.micro (2 vCPU, 1 GiB) para as duas VMs, com troca de tamanho pela pipeline | DEC | Carga de feira com lista compartilhada e poucas dezenas de visitantes simultâneos (hipótese, o escopo não informa público). t3.small fica disponível como alteração de infraestrutura (Cenário 2). |
| D04 | Créditos de CPU em modo `standard` | DEC | O padrão da família T3 é `unlimited`, que cobra uso acima da linha de base. `standard` limita o custo ao preço por hora. |
| D05 | VPC própria por ambiente, sub-rede pública (app) e privada (db) na mesma AZ | ESC REQ-02 | O banco não tem IP público. O volume EBS precisa estar na mesma AZ da VM. |
| D06 | Saída da VM do banco para a internet pela VM da aplicação (NAT instance), sem NAT Gateway | DEC | A VM do banco precisa baixar pacotes e a imagem do MongoDB. O NAT Gateway custa US$ 0,045/h (cerca de US$ 32/mês) mais tráfego, o que é desproporcional para a feira. A VM da aplicação faz o mascaramento (iptables) com `source_dest_check` desativado. |
| D07 | VPC Gateway Endpoint para S3 na sub-rede privada | DEC | Os backups vão direto para o S3 sem passar pelo NAT. O endpoint de gateway não tem custo. |
| D08 | Security Groups: 80/443 público só na app; 27017 e 22 na db aceitos apenas do SG da app; 22 na app fechado por padrão | ESC REQ-02, REQ-03 | Isolamento do banco (ACE-03) e administração restrita. O acesso SSH da pipeline é aberto temporariamente para o IP do runner e removido ao final do job. |
| D09 | Elastic IP na VM da aplicação | DEC | O endereço não muda quando a VM é parada para trocar o tipo (Cenário 2), então a URL e o certificado continuam válidos. |
| D10 | HTTPS com Caddy e Let's Encrypt; domínio padrão `<ip>.sslip.io`, substituível por domínio próprio | ESC REQ-05 | O escopo informa que o domínio ainda não existe. O sslip.io resolve o nome para o IP sem custo e permite certificado válido. Caddy renova o certificado sozinho. |
| D11 | Nginx do frontend encaminha `/todos` e `/todos/:id` para a API no mesmo endereço | ESC seção 5 | Frontend e API ficam no mesmo endereço público (REQ-05) e o CORS pode ser restrito à própria origem. |
| D12 | Docker instalado do repositório oficial do Ubuntu (`docker.io`) | DEC | Pacote mantido pela Canonical e atualizado pelo mesmo `apt upgrade` do parâmetro `update_os`, sem repositório nem chave GPG de terceiros. Docker Compose não é necessário porque os contêineres são gerenciados pelo módulo `community.docker.docker_container`. |
| D13 | Imagens da aplicação construídas pela pipeline `app.yml` e publicadas no GitHub Container Registry com tag `sha-<commit>` | ESC 7 (entrega), PM04 9 | Versões identificáveis e reproduzíveis. O retorno à versão anterior é executar a pipeline de infraestrutura com a tag anterior. |
| D14 | MongoDB oficial `mongo:8.0` em contêiner, dados em volume EBS separado (gp3, criptografado) montado em `/srv/mongo-data` | ESC REQ-04, ACE-05 | O volume não depende do disco raiz; recriar o contêiner ou trocar o tipo da VM não apaga as tarefas. |
| D15 | Usuário próprio da aplicação no MongoDB (`todo_app`, papel `readWrite` só no banco `todo-app`), diferente do root | ESC REQ-03 | Menor privilégio. As senhas vêm de GitHub Secrets e não aparecem em logs (`no_log`). |
| D16 | Backup diário (cron) com `mongodump` para o disco local e para S3 (versionado, retenção de 30 dias); restauração testada em contêiner isolado (`--network none`) | ESC REQ-04, ACE-07 | Restaurar sem sobrescrever a demonstração. O bucket de backup fica fora da stack do ambiente e sobrevive à desativação. |
| D17 | Terraform State em S3 com versionamento, criptografia, bloqueio de acesso público e lock nativo (`use_lockfile`) | PM04 3.2, ESC 8 | Estado persistente entre execuções sem DynamoDB. Uma chave por ambiente (`todo-app/<env>/terraform.tfstate`). |
| D18 | Stack `bootstrap` separada (bucket do state, bucket de backups, provedor OIDC e papel IAM da pipeline) | DEC | Resolve o problema "ovo e galinha": a pipeline precisa do bucket e do papel antes de rodar. É executada uma vez, localmente, com credenciais de administrador. |
| D19 | Autenticação da pipeline na AWS por OIDC, papel restrito aos ambientes do repositório | PM04 9, DEC | Nenhuma chave de acesso da AWS armazenada no GitHub. |
| D20 | AMI Ubuntu 24.04 LTS resolvida na criação, com `ignore_changes = [ami]` | PM04 3.2 | Evita que uma AMI nova publicada pela Canonical force a recriação das VMs a cada execução (Cenário 3). Atualizações do SO são feitas pelo Ansible. |
| D21 | IMDSv2 obrigatório, discos criptografados | DEC | Boas práticas de segurança sem custo. |
| D22 | Pipelines separadas: `infra.yml` (provisionar e configurar), `app.yml` (validar e construir imagens), `ops.yml` (rotinas), `destroy.yml` (desativação) | ESC 9 e 10 | O escopo pede separar reinício, limpeza da lista e remoção da infraestrutura. |
| D23 | Ambientes dev, homolog e prod com GitHub Environments, secrets por ambiente e VPCs distintas | PM04 4 | Separação de ambientes. Apenas `dev` é usado na demonstração para controlar custo. |
| D24 | Swap de 1 GiB nas VMs | DEC | t3.micro tem 1 GiB de RAM; a swap evita encerramento por falta de memória durante build de cache e no teste de restauração. |

## 3. Adaptações de configuração na aplicação

O PM-04 dispensa o desenvolvimento do sistema, e o escopo (seções 5 e 13) define que adaptações de configuração e implantação fazem parte da entrega. Foram feitas somente as alterações listadas na seção 5 do escopo, sem nova funcionalidade:

- `frontend/src/App.js`: a URL base da API passou a vir de `REACT_APP_API_URL`, vazia por padrão (mesmo endereço da página);
- `frontend/nginx.conf` (novo): encaminha `/todos` e `/todos/:id` para o contêiner `backend:5000` e serve o React;
- `backend/index.js`: string de conexão em `MONGO_URI`, origem CORS em `CORS_ORIGIN`, encerramento do processo se a primeira conexão falhar (o Docker reinicia e tenta de novo);
- Dockerfiles: Node 22 LTS, `npm ci`, execução da API como usuário sem privilégios;
- `docker-compose.yaml`: credenciais por `.env`, banco sem porta publicada, volume nomeado e verificações de saúde.

As rotas, os métodos HTTP e o comportamento da lista foram preservados.

## 4. Hipóteses registradas (escopo seção 11)

- Data, duração e público da feira não foram informados. Hipótese de dimensionamento: até 50 visitantes simultâneos, uso de um dia, preparação de duas semanas.
- Domínio não informado: usa-se `sslip.io` até a organização fornecer um domínio.
- Conta de nuvem: conta AWS da equipe, no plano pago com créditos promocionais.
