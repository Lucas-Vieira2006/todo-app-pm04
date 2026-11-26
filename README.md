# ToDo App na nuvem: Terraform, Ansible e GitHub Actions

Projeto final PM-04 (DevOps e Infraestrutura). Implantação do ToDo App na AWS para a Feira de Profissões, com a infraestrutura criada pelo Terraform, os servidores configurados e mantidos pelo Ansible e todas as mudanças executadas por pipelines do GitHub Actions.

## 1. Apresentação

O ToDo App é uma lista de tarefas compartilhada (React + Nginx, API Node.js/Express e MongoDB) desenvolvida por alunos do 3º período. Este repositório contém a aplicação original, as adaptações de configuração exigidas pelo escopo e toda a automação de infraestrutura.

## 2. Objetivo

Disponibilizar a aplicação em um endereço público HTTPS, com frontend, API e banco integrados, banco isolado em VM própria, dados persistentes com backup e restauração testada, e procedimentos que os alunos consigam executar pelas pipelines, sem acesso manual aos servidores.

## 3. Demanda

Documentos de referência: [escopo.pdf](escopo.pdf) (demanda do sistema) e o PM-04 (critérios da disciplina). Requisitos explícitos do escopo atendidos por esta entrega:

- REQ-01: duas VMs, uma exclusiva do MongoDB;
- REQ-02: porta 27017 liberada somente para a VM da aplicação, banco sem exposição na internet;
- REQ-03: administração restrita, usuário próprio da aplicação no banco, segredos fora do código e dos logs;
- REQ-04: volume persistente, backup automático e restauração testada;
- REQ-05: URL HTTPS com frontend e API no mesmo endereço;
- REQ-06: reinício automático e verificações de saúde, incluindo a conexão da API com o banco;
- seção 5: fim do `localhost:5000` fixo, Nginx encaminhando `/todos`, credenciais por ambiente, CORS restrito e inicialização com verificação de prontidão;
- seções 7 a 10: pipelines de infraestrutura, entrega da aplicação, operação e desativação;
- seção 12: estimativa de custos em [docs/custos.md](docs/custos.md).

A rastreabilidade completa (requisito, decisão e arquivo) está em [docs/decisoes-arquiteturais.md](docs/decisoes-arquiteturais.md).

## 4. Arquitetura

```text
Visitantes (navegador)
   |  HTTPS 443 (HTTP 80 redireciona)
   v
[VPC 10.20.0.0/16 - us-east-1]
   |
   +-- Sub-rede pública 10.20.1.0/24
   |     VM 1 "aplicação" (t3.micro, Elastic IP)
   |       Caddy :80/:443  -> certificado Let's Encrypt
   |       Nginx + React   -> encaminha /todos e /todos/:id
   |       API Express     -> MONGO_URI com usuário todo_app
   |       NAT (iptables)  -> saída da sub-rede privada
   |             |
   |             | TCP 27017, somente a partir do SG da aplicação
   |             v
   +-- Sub-rede privada 10.20.2.0/24 (sem IP público)
         VM 2 "banco" (t3.micro)
           MongoDB 8.0 em contêiner, dados no volume EBS /srv/mongo-data
           backup diário (mongodump) -> endpoint S3 -> bucket de backups

Fora da VPC: bucket S3 do Terraform State (versionado, lock nativo)
             e bucket S3 de backups (retenção de 30 dias)
```

Fluxo: o navegador acessa `https://<ip>.sslip.io`; o Caddy termina o TLS e repassa ao Nginx, que entrega o React e encaminha `/todos` e `/todos/:id` para a API; somente a API acessa o MongoDB, pela rede privada, com usuário próprio.

## 5. Justificativas técnicas

As decisões completas, com origem (escopo, PM-04 ou decisão da equipe), estão em [docs/decisoes-arquiteturais.md](docs/decisoes-arquiteturais.md). Resumo:

- AWS us-east-1: conta da equipe disponível, menor preço para t3, OIDC nativo com o GitHub.
- t3.micro com créditos `standard`: suficiente para a hipótese de público da feira, sem cobrança extra por CPU.
- NAT pela VM da aplicação em vez de NAT Gateway: o banco continua sem IP público e o custo fixo de cerca de US$ 32/mês do NAT Gateway é evitado.
- Elastic IP: o endereço não muda quando a VM é parada para troca de tipo, mantendo URL e certificado.
- Caddy + sslip.io: HTTPS válido sem domínio próprio; basta definir `APP_DOMAIN` quando houver um.
- Docker do repositório Ubuntu (`docker.io`): atualizado pelo mesmo `apt` do parâmetro `update_os`.
- Volume EBS separado para o MongoDB: troca de VM, recriação de contêiner ou atualização não apagam as tarefas.
- State no S3 com lock nativo: persistente, versionado e sem tabela DynamoDB.

## 6. Tecnologias

- Terraform 1.16.7 (provider AWS 6.x), testes com `terraform test` e provider simulado
- Ansible 14.6.0 (ansible-core 2.21), coleções community.docker, community.general e ansible.posix
- GitHub Actions com OIDC para a AWS e GitHub Container Registry
- Ubuntu 24.04 LTS, Docker (pacote `docker.io`), Caddy 2.11, Nginx 1.30, Node.js 22, MongoDB 8.0
- AWS: VPC, EC2, EBS gp3, Elastic IP, Security Groups, IAM, S3, VPC endpoint

## 7. Estrutura do repositório

```text
.github/
  actions/setup-tools/      ação composta: instala Terraform e Ansible nas versões fixadas
  workflows/
    infra.yml               provisionar e configurar (parâmetros do PM-04)
    app.yml                 validar o código e publicar imagens sha-<commit>
    ops.yml                 saúde, logs, reinício, backup, teste de restauração, limpeza da lista
    destroy.yml             backup final e desativação do ambiente
    ci.yml                  validações estáticas (fmt, validate, test, lint)
terraform/
  bootstrap/                bucket do state, bucket de backups, OIDC e papel da pipeline (executar uma vez)
  providers.tf backend.tf main.tf network.tf security.tf compute.tf storage.tf iam.tf
  variables.tf outputs.tf terraform.tfvars.example
  environments/             dev.tfvars, homolog.tfvars, prod.tfvars (CIDRs por ambiente)
  tests/plan.tftest.hcl     testes de arquitetura com provider simulado
ansible/
  playbook.yml              configuração completa (app -> db -> contêineres)
  verify.yml                verificação final (etapa 11 da pipeline)
  ops.yml                   rotinas operacionais
  group_vars/               variáveis (all, app, db)
  inventory/                exemplo; o inventário real é gerado pela pipeline
  roles/                    os_updates, packages, system, docker, nat_gateway, data_volume,
                            mongodb, backup, app_stack, verify, ops
scripts/                    validação de parâmetros, inventário, SSH temporário, resumo
frontend/ backend/ banco-de-dados/   aplicação (com as adaptações de configuração)
docs/                       decisões, custos, manual de operação, escopo
evidencias/                 evidências por cenário e testes locais
```

## 8. Terraform

Duas stacks:

- `terraform/bootstrap`: executada uma única vez, localmente, com credenciais de administrador. Cria o bucket do Terraform State (versionado, criptografado, privado, só TLS), o bucket de backups (retenção de 30 dias), o provedor OIDC do GitHub e o papel IAM da pipeline, restrito aos GitHub Environments do repositório.
- `terraform/` (ambiente): VPC, sub-redes pública e privada, Internet Gateway, rotas (a privada sai pela VM da aplicação), endpoint S3, Security Groups com regras separadas, duas VMs Ubuntu 24.04, Elastic IP, volume EBS de dados e papel IAM da VM do banco (somente o prefixo do próprio ambiente no bucket de backups).

Controle de recriações: a AMI é escolhida só na criação (`ignore_changes = [ami]`); trocar `instance_type` é uma alteração no lugar (a AWS para e inicia a VM); trocar `instance_name` altera só tags; o volume de dados é um recurso separado e a pipeline Infra é interrompida se o plano tentar removê-lo.

State: backend S3 com configuração parcial e uma chave por ambiente (`todo-app/<env>/terraform.tfstate`), lock por arquivo `.tflock` (`use_lockfile = true`). A pipeline nunca guarda state em artefatos.

## 9. Ansible

`playbook.yml` executa, nesta ordem:

1. VM da aplicação: `os_updates` (verifica sempre, aplica com `update_os=true`, reinicia se necessário), `packages` (base + `extra_packages`), `system` (fuso horário, SSH só com chave, swap de 1 GiB), `docker` (instalação, rotação de logs, `live-restore`, início automático) e `nat_gateway` (encaminhamento e mascaramento para a sub-rede privada, como serviço systemd).
2. VM do banco (acessada pela VM da aplicação): os mesmos roles de sistema, `data_volume` (formata o EBS só se estiver vazio e monta em `/srv/mongo-data`), `mongodb` (contêiner `mongo:8.0` publicado só no IP privado, segredos em arquivos, healthcheck e teste da credencial da aplicação) e `backup` (scripts, cron diário e rotação de log).
3. VM da aplicação: `app_stack` (rede Docker, Caddyfile, login no GHCR só se faltar imagem, contêineres `backend`, `frontend` e `caddy` com reinício automático e healthcheck, registro da versão atual e anterior).

`verify.yml` confere os contêineres saudáveis, a política de reinício, o Docker habilitado, o volume montado, o backup agendado, o NAT, a conexão privada com a porta 27017, a página HTTPS, o fluxo completo da API pelo endereço público (cria, conclui, reabre e exclui uma tarefa de teste) e que a porta 27017 não responde pelo IP público.

Idempotência: todas as tarefas usam módulos com estado desejado; os comandos de leitura têm `changed_when: false`; o login no registro só acontece quando falta imagem; os contêineres só são recriados quando a imagem ou a configuração muda.

## 10. Pipeline Infra

Arquivo `.github/workflows/infra.yml`, execução manual (`workflow_dispatch`), um job por ambiente com `concurrency` (sem execuções simultâneas no mesmo ambiente). Etapas:

1. validar parâmetros (`scripts/validate-params.sh`);
2. preparar o ambiente (Terraform e Ansible em versões fixas);
3. configurar credenciais (OIDC) e a chave SSH a partir do secret;
4. `terraform init` com o backend S3;
5. `terraform fmt -check` e `terraform validate`;
6. `terraform plan` (com proteção do volume de dados);
7. `terraform apply` do plano salvo (pulado se não houver alterações);
8. leitura dos outputs;
9. geração do inventário e liberação de SSH temporário apenas para o IP do runner;
10. `ansible-playbook playbook.yml`;
11. `ansible-playbook verify.yml` e verificações externas (HTTP, API e porta 27017 fechada);
12. resumo no GitHub (parâmetros, plano, URL, recursos, PLAY RECAP).

Ao final, sempre: remoção da regra SSH temporária e da chave, e publicação das evidências como artifact. Qualquer falha interrompe o job e as etapas seguintes não rodam.

Outras pipelines: `app.yml` (valida o código, constrói e publica as imagens com tag `sha-<commit>`), `ops.yml` (rotinas), `destroy.yml` (desativação) e `ci.yml` (validações estáticas em PRs).

## 11. Parâmetros da pipeline Infra

- `environment`: dev, homolog ou prod. Define o GitHub Environment (secrets e aprovação), a chave do state, a VPC e os nomes dos recursos.
- `instance_name`: nome (tag Name) da VM da aplicação; a do banco recebe `-db`. Alteração só de tag.
- `instance_type`: t3.micro, t3.small ou t3.medium para a VM da aplicação. Alteração no lugar.
- `db_instance_type`: mesmo conjunto para a VM do banco (parâmetro adicional, exigido pela arquitetura de duas VMs).
- `docker_image`: prefixo das imagens; vazio usa `ghcr.io/<dono>/todo-app` (`-frontend` e `-backend`).
- `docker_tag`: versão das imagens (por exemplo `sha-1a2b3c4`); trocar a tag atualiza os contêineres de forma controlada.
- `update_os`: aplica `apt dist-upgrade` e reinicia a VM se o Ubuntu pedir.
- `extra_packages`: pacotes apt adicionais, separados por vírgula, validados por expressão regular.
- `plan_only`: executa somente até o plano (parâmetro adicional, para revisão).

## 12. Secrets e variáveis do GitHub

Variáveis do repositório (Settings > Secrets and variables > Actions > Variables), com os valores dos outputs da stack bootstrap:

- `AWS_ROLE_ARN`, `AWS_REGION`, `TF_STATE_BUCKET`, `BACKUP_BUCKET`
- `APP_DOMAIN` (opcional, por ambiente): domínio próprio; vazio usa sslip.io

Secrets de cada GitHub Environment (`dev`, `homolog`, `prod`):

- `SSH_PRIVATE_KEY`: chave privada ed25519 da pipeline (a pública é derivada dela)
- `MONGO_ROOT_PASSWORD`: senha do administrador do MongoDB (mínimo 16 caracteres)
- `MONGO_APP_PASSWORD`: senha do usuário `todo_app` (mínimo 16 caracteres)

Nenhuma chave de acesso da AWS é armazenada: a pipeline assume o papel por OIDC. O `GITHUB_TOKEN` (somente leitura de pacotes) é usado para baixar as imagens do GHCR.

## 13. Como executar

Pré-requisitos: conta AWS com permissão de administrador para o bootstrap, Terraform 1.10 ou superior, AWS CLI e um fork deste repositório com Actions habilitado.

1. Bootstrap (uma vez):

   ```bash
   cd terraform/bootstrap
   cp terraform.tfvars.example terraform.tfvars   # ajuste github_repository = "<dono>/<repo>"
   terraform init && terraform apply
   terraform output
   ```

2. Chave SSH e senhas:

   ```bash
   ssh-keygen -t ed25519 -N "" -C todo-app-pipeline -f todo_deploy
   openssl rand -base64 24   # repetir para cada senha
   ```

3. No GitHub: criar os Environments `dev`, `homolog` e `prod` (em `prod`, recomenda-se exigir aprovação), cadastrar as variáveis e os secrets da seção 12 e apagar o arquivo local da chave privada.
4. Executar **App: validar e construir imagens** e anotar a tag `sha-...`.
5. Executar **Infra: provisionar e configurar** com essa tag.

Execução local (desenvolvimento, sem nuvem):

```bash
cp .env.example .env    # troque as senhas
docker compose up --build -d
# http://localhost  (a API fica atrás do Nginx em /todos)
docker compose down     # use "down -v" para apagar também o volume do banco
```

## 14. Como atualizar a infraestrutura

Executar a pipeline Infra alterando os parâmetros. Exemplos: `instance_type` de t3.micro para t3.small (Terraform altera a VM no lugar), nova `docker_tag` (Ansible baixa a imagem e recria só os contêineres da aplicação), `update_os=true` ou novos `extra_packages` (Ansible aplica no SO). Para voltar à versão anterior, executar com a tag anterior, registrada no resumo e em `/opt/todo-app/release.json`.

## 15. Como executar os três cenários

O roteiro detalhado, com o que capturar como evidência, está em [evidencias/README.md](evidencias/README.md).

- Cenário 1 (criação): Infra com `t3.micro`, `docker_tag=<tag A>`, `update_os=false`, `extra_packages=curl,git,unzip`.
- Cenário 2 (atualização): Infra com `instance_type=t3.small`, `docker_tag=<tag B>`, `update_os=true`, `extra_packages=curl,git,unzip,htop`.
- Cenário 3 (idempotência): repetir exatamente os parâmetros do Cenário 2. Esperado: "No changes" no plano, apply pulado e `changed=0` no PLAY RECAP.

## 16. Como verificar os serviços

- resumo da pipeline Infra (etapas 11 e 12) e o artifact `evidencias-infra-...`;
- pipeline Ops com `action=health` (contêineres, recursos, último backup, lista da API) ou `action=logs`;
- navegador em outro dispositivo: abrir a URL, cadastrar, concluir, reabrir, excluir e recarregar;
- isolamento: `nc -z -w 5 <ip-publico> 27017` de qualquer máquina deve falhar.

## 17. Cuidados de segurança

- Nenhuma credencial no repositório: AWS por OIDC, senhas e chave SSH em GitHub Secrets, `.env` e inventário gerado ignorados pelo Git.
- Tarefas que manipulam senhas usam `no_log`; os segredos do MongoDB ficam em arquivos `0400` montados somente leitura (não em variáveis de ambiente do contêiner do banco).
- SSH fechado por padrão: a pipeline libera a porta 22 apenas para o IP do runner durante o job e remove a regra ao final, mesmo em caso de falha; o banco só aceita SSH a partir da VM da aplicação.
- SSH apenas com chave, sem login de root; IMDSv2 obrigatório; discos e buckets criptografados; Security Group padrão da VPC sem regras.
- Papel da pipeline restrito ao repositório e aos seus Environments; papel da VM do banco restrito ao prefixo do ambiente no bucket de backups.
- Tipos de VM limitados por validação (controle de custo) e `admin_cidrs` não aceita 0.0.0.0/0.
- Verificações executadas: `terraform validate`, `terraform test`, checkov (161 aprovadas, 0 falhas, 18 exceções justificadas no código), ansible-lint (perfil production), actionlint, shellcheck e yamllint.

## 18. Limitações conhecidas

- As execuções reais na AWS e no GitHub Actions dependem das credenciais da equipe e não fazem parte das evidências locais; veja a situação de cada cenário em [evidencias/README.md](evidencias/README.md).
- Arquitetura de demonstração: uma VM por função, sem alta disponibilidade; a VM da aplicação é ponto único de entrada e de NAT.
- A primeira conexão SSH aceita a chave do host (`accept-new`); como os runners são efêmeros, a verificação da chave do host não persiste entre execuções.
- O usuário do MongoDB é criado na primeira inicialização do volume; trocar as senhas depois exige alterar o usuário no banco antes de atualizar os Secrets.
- A senha da aplicação fica na variável `MONGO_URI` do contêiner da API (visível só para root na VM), pois o código lê a conexão do ambiente.
- Let's Encrypt via sslip.io depende de serviço externo e dos limites de emissão; um domínio próprio elimina essa dependência.
- O teste automático do React (`App.test.js`) é o modelo do create-react-app e não corresponde à interface; não é executado na pipeline.
- `unattended-upgrades` do Ubuntu continua ativo para correções de segurança, além do `update_os` controlado.
- Os scripts de backup passam a senha root ao `mongosh` dentro do contêiner do banco (visível em `ps` para root na VM durante a execução).
