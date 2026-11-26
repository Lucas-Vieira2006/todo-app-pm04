# Execução local dos roles do Ansible

Os roles reais de `ansible/roles` foram executados contra dois contêineres Ubuntu 24.04 com systemd (`pm04-app` e `pm04-db`), criados a partir de um rootfs debootstrap do arquivo oficial do Ubuntu, com conexão `community.docker.docker`. O "volume EBS" é um arquivo de 1 GiB em loop device com o mesmo link `/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_<id>` usado na AWS.

Arquivos

- `preparar-alvos.sh`: cria os alvos e o disco de dados;
- `executar-sequencia.sh`: executa as seis rodadas e grava `logs/`;
- `playbook-roles.yml` e `playbook-containers.yml`: mesmos roles e ordem do `playbook.yml`;
- `vars-*.json`: parâmetros de cada rodada;
- `Dockerfile.imagem-substituta`: imagem usada no lugar de `mongo:8.0`, `caddy` e das imagens da aplicação, pois o ambiente não acessa registros públicos. Ela só responde aos healthchecks; não executa o MongoDB nem a aplicação (isso foi testado em `../teste-integracao-local.sh`).

Resultados (logs/00-resumo-sequencia.txt)

- 01 criação, `update_os=true`: app `changed=13`, db `changed=11` (SO atualizado, Docker 29.1.3 do Ubuntu, NAT, swap desativado no teste, volume formatado e montado);
- 02 mesmos parâmetros: `changed=0` nos dois alvos;
- 03 novos pacotes (htop, tree): `changed=1` nos dois alvos;
- 04 contêineres, tag inicial: criação de rede, contêineres, segredos, scripts e cron;
- 05 mesma tag: `changed=0` nos dois alvos;
- 06 tag nova: `changed=3` só na app (API, frontend e release.json com a tag anterior); banco sem alteração.

Diferenças em relação às VMs: sem swap (contêineres não permitem `swapon`), sem SSH/ProxyCommand (conexão direta pelo Docker) e sem reinicialização após atualização.
