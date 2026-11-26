# Evidências

Situação em 24/11/2026: a automação está completa e validada localmente. As execuções reais na AWS e no GitHub Actions dependem da conta AWS e do fork do repositório da equipe e AINDA NÃO FORAM EXECUTADAS. Nenhum print ou log desta pasta foi simulado como execução real.

## O que já existe (executado de verdade)

testes-locais/

- `validacoes-estaticas.log`: terraform fmt/validate/test (7 testes com provider simulado), checkov (161 aprovadas, 0 falhas, 18 exceções justificadas), syntax-check e ansible-lint (perfil production), actionlint, shellcheck, yamllint e testes da validação de parâmetros.
- `teste-integracao-local.sh` e `.log`: aplicação adaptada rodando com MongoDB 8.0 real, API Node 22, build React servido pelo Nginx com `frontend/nginx.conf`, Caddy com HTTPS, e os scripts de backup/restauração renderizados pelo Ansible com S3 simulado (moto). 33 verificações, 0 falhas: credencial própria, privilégios mínimos, CORS, CRUD completo por HTTPS, persistência após reinício, backup, restauração isolada, limpeza da lista e restauração.
- `ansible-alvo-container/`: roles reais executados contra dois contêineres Ubuntu 24.04 com systemd (substitutos das VMs). `logs/01` a `03`: criação com `update_os=true`, reexecução com `changed=0` e novos pacotes com `changed=1`. `logs/04` a `06`: roles de contêiner com imagens substitutas: criação, mesma tag com `changed=0` e tag nova recriando só frontend e API e registrando a versão anterior.

Limites dos testes locais: não há Docker Hub, GHCR nem AWS no ambiente de desenvolvimento; por isso não cobrem Terraform contra a AWS, imagens reais em contêiner, Let's Encrypt, a rede da VPC e o NAT entre VMs.

arquitetura/: diagrama (`diagrama-arquitetura.png`, fonte `arquitetura.dot`).

## O que capturar na execução real

Cada execução da pipeline Infra publica o artifact `evidencias-infra-<env>-<n>` com `terraform-plan.txt`, `terraform-apply.txt`, `terraform-outputs.json`, `ansible-playbook.log`, `ansible-verify.log` e `external-checks.txt`. Baixe e salve na pasta do cenário, junto com prints da tela do GitHub Actions e do navegador. Os roteiros estão no README de cada pasta:

- `cenario-1-criacao/`
- `cenario-2-atualizacao/`
- `cenario-3-idempotencia/`
- `pipeline/` (pipeline App, rotinas Ops e Destroy)
