# Auditoria final (24/11/2026)

Legenda: CONCLUÍDO E VALIDADO | IMPLEMENTADO, MAS NÃO EXECUTADO | PENDENTE DE CREDENCIAIS OU AUTORIZAÇÃO | NÃO IMPLEMENTADO

- Escopo.pdf analisado: CONCLUÍDO E VALIDADO (docs/decisoes-arquiteturais.md)
- Requisitos PM-04 analisados: CONCLUÍDO E VALIDADO
- Arquitetura documentada: CONCLUÍDO E VALIDADO (README, decisões, diagrama, custos)
- Terraform implementado: CONCLUÍDO E VALIDADO localmente (validate + 7 testes com provider simulado + checkov); apply real PENDENTE DE CREDENCIAIS
- Terraform fmt validado: CONCLUÍDO E VALIDADO
- Terraform validate executado: CONCLUÍDO E VALIDADO (com OpenTofu 1.13; a pipeline usa Terraform 1.16.7)
- Terraform State persistente configurado: IMPLEMENTADO, MAS NÃO EXECUTADO (bootstrap S3 + use_lockfile; requer conta AWS)
- Ansible implementado: CONCLUÍDO E VALIDADO contra alvos Ubuntu 24.04 locais
- Ansible syntax-check executado: CONCLUÍDO E VALIDADO (+ ansible-lint perfil production)
- Docker configurado automaticamente: CONCLUÍDO E VALIDADO nos alvos locais (docker.io 29.1.3)
- Contêineres configurados: IMPLEMENTADO; lógica validada com imagens substitutas; imagens reais PENDENTE DE CREDENCIAIS
- Pipeline GitHub Actions criada: IMPLEMENTADO, MAS NÃO EXECUTADO (actionlint sem erros)
- Parâmetros dinâmicos implementados: CONCLUÍDO E VALIDADO (validate-params.sh testado com entradas válidas e inválidas)
- Terraform integrado ao Ansible: IMPLEMENTADO, MAS NÃO EXECUTADO (render-inventory.sh a partir dos outputs)
- Credenciais protegidas: CONCLUÍDO E VALIDADO (nenhum segredo no repositório; OIDC; no_log; segredos em arquivo no banco)
- Cenário 1 validado: PENDENTE DE CREDENCIAIS (camada Ansible validada localmente, rodada 01)
- Cenário 2 validado: PENDENTE DE CREDENCIAIS (camada Ansible validada localmente, rodadas 03 e 06)
- Cenário 3 validado: PENDENTE DE CREDENCIAIS (idempotência validada localmente, rodadas 02 e 05 com changed=0)
- README completo: CONCLUÍDO E VALIDADO
- Evidências organizadas: CONCLUÍDO para testes locais; evidências da nuvem PENDENTES
- Documento acadêmico em PDF produzido: CONCLUÍDO (docs/documento-final/PM04_Projeto_Final_ToDoApp.pdf); faltam nomes dos demais integrantes, link do fork e evidências reais
- Link do repositório documentado: PENDENTE (link do fork da equipe; repositório de origem documentado)
