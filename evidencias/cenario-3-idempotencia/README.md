# Cenário 3: reexecução sem alterações

Status: PENDENTE DE CREDENCIAIS na AWS. A idempotência dos roles já foi comprovada localmente (ver `../testes-locais/ansible-alvo-container/logs/02-sistema-mesmos-parametros.log` e `05-conteineres-mesma-tag.log`, ambos com `changed=0`).

Execução: repetir a pipeline Infra com exatamente os parâmetros do Cenário 2.

Resultado esperado

- passo 6: `No changes. Your infrastructure matches the configuration.`;
- passo 7: pulado (não há plano a aplicar);
- passo 10: PLAY RECAP com `changed=0` nas duas VMs (pode haver `changed` em `update_os` se o Ubuntu publicar pacotes entre as duas execuções; nesse caso, repetir com `update_os=false` mostra `changed=0`);
- passo 11: serviços saudáveis, mesmos contêineres (o tempo "Up" continua contando, sem recriação).

Salvar nesta pasta: prints do plano sem alterações e do PLAY RECAP, e o artifact.
