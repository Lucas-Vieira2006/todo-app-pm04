# Cenário 2: atualização do ambiente

Status: PENDENTE DE CREDENCIAIS.

Antes: faça uma alteração visível no frontend (ou apenas um novo commit) e rode a pipeline App para obter a tag B. Cadastre uma tarefa pelo navegador para conferir a persistência.

Execução da pipeline Infra com os mesmos parâmetros do Cenário 1, exceto:

- instance_type: t3.small (alteração de infraestrutura pelo Terraform)
- docker_tag: tag B (atualização dos contêineres pelo Ansible)
- update_os: true (atualização do sistema operacional pelo Ansible)
- extra_packages: curl,git,unzip,htop (novo pacote pelo Ansible)

Resultado esperado

- passo 6: `Plan: 0 to add, 1 to change, 0 to destroy` com `instance_type: "t3.micro" -> "t3.small"` em `aws_instance.app` (alteração no lugar, sem recriação);
- passo 10: tarefas alteradas em `Aplicar atualizações do sistema operacional`, `Instalar pacotes`, `Criar e manter o contêiner da API` e `do frontend`; o MongoDB não é recriado;
- a tarefa cadastrada antes continua na lista; a URL não muda (Elastic IP);
- `/opt/todo-app/release.json` e o resumo mostram tag atual B e anterior A.

Salvar nesta pasta: prints, o artifact e o trecho do plano com a mudança de tipo.
