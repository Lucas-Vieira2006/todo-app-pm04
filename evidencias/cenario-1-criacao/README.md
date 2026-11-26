# Cenário 1: criação inicial

Status: PENDENTE DE CREDENCIAIS (execução real na AWS ainda não realizada).

Pré-requisitos: bootstrap aplicado, variáveis e secrets configurados, pipeline App executada (anote a tag `sha-...` = tag A).

Execução: Actions > Infra: provisionar e configurar > Run workflow

- environment: dev
- instance_name: vm-pm04
- instance_type: t3.micro
- db_instance_type: t3.micro
- docker_image: (vazio)
- docker_tag: tag A
- update_os: false
- extra_packages: curl,git,unzip
- plan_only: false

Resultado esperado

- passo 6: `Plan: N to add, 0 to change, 0 to destroy` (cerca de 30 recursos);
- passo 10: PLAY RECAP sem falhas, Docker instalado nas duas VMs, contêineres `todo-mongo`, `backend`, `frontend` e `caddy` criados;
- passo 11: todos os contêineres `healthy`, fluxo da API pelo HTTPS aprovado, porta 27017 fechada no IP público;
- resumo com a URL `https://<ip>.sslip.io`.

Salvar nesta pasta

- print da tela de parâmetros e da execução concluída (todas as etapas verdes);
- o artifact da execução (plano, apply, outputs, logs do Ansible, verificação externa);
- print da aplicação aberta no celular (ACE-04): cadastrar, concluir, reabrir, excluir e recarregar;
- saída de `nc -z -w 5 <ip> 27017` em outro computador (ACE-03).
