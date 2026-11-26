# Pipelines: evidências complementares

Status: PENDENTE DE EXECUÇÃO no fork da equipe. As cinco pipelines passaram no actionlint (ver `../testes-locais/validacoes-estaticas.log`).

Capturar:

- App: execução com as duas imagens publicadas e o resumo com a tag `sha-...` (ACE-06);
- Ops `health` e `logs` (ACE-08);
- Ops `backup` seguido de `restore-test`, mostrando "RESTAURAÇÃO VALIDADA" (ACE-07);
- Ops `recreate-db` seguido de `health`, mostrando as tarefas preservadas (ACE-05);
- Ops `reset-demo-list` com `CONFIRMAR` (preparação da lista);
- Destroy ao final, com o inventário do que permanece (ACE-08, ACE-09);
- tela de Settings > Secrets mostrando apenas os nomes dos secrets (nunca valores).
