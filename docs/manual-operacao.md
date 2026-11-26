# Manual de operação para os alunos

Todas as rotinas são executadas pelo GitHub, em **Actions**, escolhendo a pipeline e clicando em **Run workflow**. Ninguém precisa entrar nos servidores. Cada execução deixa um resumo na própria página e um arquivo de evidências para download (sem senhas).

## 1. Publicar uma versão da aplicação

1. Faça push na branch `main` alterando `frontend/` ou `backend/` (ou rode **App: validar e construir imagens** manualmente).
2. Ao final, o resumo mostra a tag gerada, por exemplo `sha-1a2b3c4`.

## 2. Iniciar ou atualizar o ambiente

Pipeline **Infra: provisionar e configurar**.

- `environment`: `dev`
- `instance_name`: `vm-pm04`
- `instance_type` e `db_instance_type`: `t3.micro`
- `docker_image`: deixe vazio (usa as imagens deste repositório)
- `docker_tag`: a tag do passo 1
- `update_os`: marque para aplicar atualizações do Ubuntu
- `extra_packages`: `curl,git,unzip`

Resultado esperado: resumo com a URL `https://<ip>.sslip.io`, os contêineres saudáveis e a porta 27017 fechada. A primeira execução leva de 8 a 15 minutos; as seguintes, de 3 a 6.

## 3. Verificar a saúde

Pipeline **Ops**, `action = health`. Mostra os contêineres, disco, memória, último backup e a lista de tarefas devolvida pela API.

## 4. Consultar logs

Pipeline **Ops**, `action = logs`. Mostra as últimas 100 linhas de Caddy, frontend, API e MongoDB.

## 5. Reiniciar serviços

- `action = restart-app`: reinicia Caddy, frontend e API (não mexe nos dados).
- `action = restart-db`: reinicia o MongoDB (os dados ficam no volume persistente).

## 6. Backup e restauração

- `action = backup`: backup imediato no disco da VM e no S3. Também roda todo dia às 03:15.
- `action = restore-test`: baixa o último backup do S3, confere o checksum e restaura em um contêiner isolado (sem rede). A demonstração não é alterada.
- `action = restore-latest` com `confirm = CONFIRMAR`: substitui a lista atual pelo último backup. Antes, faz um backup de segurança.

## 7. Preparar a lista para uma apresentação

Pipeline **Ops**, `action = reset-demo-list`, `confirm = CONFIRMAR`. Faz backup, apaga todas as tarefas e recarrega as três tarefas de demonstração. Use antes de cada apresentação: a lista é compartilhada entre todos os visitantes.

Aviso aos visitantes: a lista é pública, sem login; não digitem dados pessoais.

## 8. Voltar para a versão anterior

O resumo da pipeline Infra e o arquivo `/opt/todo-app/release.json` registram a tag atual e a anterior. Execute a pipeline Infra com `docker_tag` igual à tag anterior. Os dados não são afetados.

## 9. Encerrar após a feira

Pipeline **Destroy: desativar ambiente**, `confirm = DESTRUIR-dev`. Faz um backup final no S3 e remove todos os recursos do ambiente. O resumo lista o que foi removido e o que continua gerando custo (buckets de backup e de state).

## 10. Falhas comuns

- **A pipeline para no passo 1**: parâmetro inválido ou variável do GitHub não configurada. A mensagem diz qual.
- **Erro de credencial no passo 3**: o papel OIDC não confia neste repositório ou ambiente. Confira `AWS_ROLE_ARN` e o `github_repository` usado na stack bootstrap.
- **A página não abre logo após a primeira execução**: o certificado HTTPS é emitido na primeira requisição; aguarde 1 ou 2 minutos e rode `health`.
- **`backend` não fica saudável**: a API não conecta ao banco. Rode `logs` e procure "Erro ao conectar ao MongoDB". Causas: senha do banco trocada nos Secrets depois da criação (o usuário do banco é criado só na primeira inicialização) ou VM do banco desligada.
- **Falha ao baixar imagens**: a tag não existe no GHCR. Confira a tag no resumo da pipeline App.
- **"Ambiente não provisionado" na Ops**: rode a pipeline Infra primeiro.
- **Aviso "Recurso será recriado/removido" no passo 6**: o plano vai substituir algum recurso. Os dados do MongoDB estão em volume separado; se o plano tentar remover esse volume, a pipeline é interrompida antes do apply. Para testar apenas o plano, use `plan_only`.
