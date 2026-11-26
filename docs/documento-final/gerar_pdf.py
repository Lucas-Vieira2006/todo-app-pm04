"""Gera o documento final da entrega PM-04 em PDF (reportlab)."""
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (Image, KeepTogether, PageBreak, Paragraph, Preformatted,
                                SimpleDocTemplate, Spacer, Table, TableStyle)

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).with_name("PM04_Projeto_Final_ToDoApp.pdf")
FONT_DIR = "/usr/share/fonts/truetype/dejavu"
pdfmetrics.registerFont(TTFont("DejaVu", f"{FONT_DIR}/DejaVuSans.ttf"))
pdfmetrics.registerFont(TTFont("DejaVu-Bold", f"{FONT_DIR}/DejaVuSans-Bold.ttf"))
pdfmetrics.registerFont(TTFont("DejaVuMono", f"{FONT_DIR}/DejaVuSansMono.ttf"))
pdfmetrics.registerFontFamily("DejaVu", normal="DejaVu", bold="DejaVu-Bold")

ss = getSampleStyleSheet()
body = ParagraphStyle("body", parent=ss["Normal"], fontName="DejaVu", fontSize=10.5, leading=15,
                      alignment=TA_JUSTIFY, spaceAfter=6)
h1 = ParagraphStyle("h1", parent=body, fontName="DejaVu-Bold", fontSize=14, leading=18,
                    spaceBefore=10, spaceAfter=8, alignment=0)
h2 = ParagraphStyle("h2", parent=h1, fontSize=11.5, leading=15, spaceBefore=8, spaceAfter=4)
bullet = ParagraphStyle("bullet", parent=body, leftIndent=14, bulletIndent=4, spaceAfter=3)
small = ParagraphStyle("small", parent=body, fontSize=8.5, leading=11, alignment=0)
cell = ParagraphStyle("cell", parent=body, fontSize=8.5, leading=11, alignment=0, spaceAfter=0)
cellb = ParagraphStyle("cellb", parent=cell, fontName="DejaVu-Bold")
code = ParagraphStyle("code", fontName="DejaVuMono", fontSize=7.6, leading=9.6,
                      backColor=colors.HexColor("#f4f4f4"), borderPadding=4, spaceAfter=8)
center = ParagraphStyle("center", parent=body, alignment=TA_CENTER)

story = []
P = lambda t, s=body: story.append(Paragraph(t, s))
B = lambda items: [story.append(Paragraph(i, bullet, bulletText="•")) for i in items]


def table(rows, widths):
    data = [[Paragraph(c, cellb if r == 0 else cell) for c in row] for r, row in enumerate(rows)]
    t = Table(data, colWidths=widths, repeatRows=1)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#e8edf3")),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#b0b8c0")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 4), ("RIGHTPADDING", (0, 0), (-1, -1), 4),
    ]))
    story.append(t)
    story.append(Spacer(1, 8))


def log_excerpt(path, start_marker=None, lines=None, grep=None):
    text = (ROOT / path).read_text(encoding="utf-8").splitlines()
    if grep:
        text = [l for l in text if any(g in l for g in grep)]
    if start_marker:
        i = next(i for i, l in enumerate(text) if start_marker in l)
        text = text[i:]
    if lines:
        text = text[:lines]
    story.append(Preformatted("\n".join(text), code))


# ---------------------------------------------------------------- capa
story += [Spacer(1, 3 * cm)]
P("Centro Universitário UniAmérica Descomplica<br/>Engenharia de Software", center)
story.append(Spacer(1, 2 * cm))
P("<b>PM-04 | Projeto Final</b><br/>Automação de infraestrutura com Terraform, Ansible e CI/CD", ParagraphStyle("t", parent=center, fontSize=16, leading=22))
story.append(Spacer(1, 0.6 * cm))
P("Implantação do ToDo App na AWS para a Feira de Profissões", ParagraphStyle("st", parent=center, fontSize=12, leading=16))
story.append(Spacer(1, 2.5 * cm))
P("<b>Integrantes</b>", center)
P("Lucas Vieira dos Santos", center)
P("[PENDENTE: nome dos demais integrantes da equipe, até três no total]", center)
story.append(Spacer(1, 1.5 * cm))
P("<b>Repositório Git</b><br/>[PENDENTE: link do fork da equipe com a automação]<br/>Repositório de origem da aplicação: https://github.com/LaercioMLB/todo-app", center)
story.append(Spacer(1, 2.5 * cm))
P("Foz do Iguaçu, novembro de 2026", center)
story.append(PageBreak())

# ---------------------------------------------------------------- 1
P("1. Introdução", h1)
P("Este documento apresenta a solução de infraestrutura desenvolvida para o projeto final PM-04. A equipe atuou como "
  "profissional de Infraestrutura/DevOps contratado para publicar o ToDo App, uma lista de tarefas desenvolvida por "
  "alunos do 3º período, em um endereço público para a Feira de Profissões. A solução cria a infraestrutura na AWS com "
  "Terraform, prepara e mantém os servidores com Ansible e executa todas as mudanças por pipelines do GitHub Actions "
  "acionadas manualmente com parâmetros.")
P("O documento descreve a análise da demanda, a arquitetura e suas justificativas, a implementação das três camadas de "
  "automação, os parâmetros da pipeline, os testes realizados e a relação entre os requisitos recebidos e a "
  "infraestrutura entregue. Os resultados são separados entre o que foi efetivamente executado e o que depende da "
  "execução na conta AWS da equipe, que está registrado como pendente.")

# ---------------------------------------------------------------- 2
P("2. Análise da demanda recebida", h1)
P("Foram analisados dois documentos. O escopo do ToDo App (escopo.pdf, v1.0 de 11/11/2026) define o que o sistema "
  "precisa para funcionar; o PM-04 define o que deve ser implementado para a avaliação. Quando os dois tratam do mesmo "
  "ponto, o escopo orienta a arquitetura e o PM-04 orienta a forma de automação.")
P("2.1 A aplicação", h2)
P("O repositório contém três componentes: frontend React 19 compilado e servido por Nginx; API Node.js/Express com "
  "Mongoose na porta 5000, com as rotas GET e POST /todos e PATCH e DELETE /todos/:id; e MongoDB com um script que "
  "cria três tarefas de demonstração. A lista é compartilhada entre todos os visitantes e não há login. O sistema já "
  "rodava localmente com Docker Compose.")
P("2.2 Problemas que impedem a implantação", h2)
B([
    "o frontend chama <i>http://localhost:5000</i> fixo, o que não funciona no navegador de um visitante;",
    "a string de conexão do banco, com usuário root e senha, está escrita em <i>backend/index.js</i>;",
    "o Compose publica a porta 27017, usa credenciais de demonstração e não define volume nomeado;",
    "o CORS aceita qualquer origem e a API não verifica a disponibilidade do banco ao iniciar: se a primeira conexão "
    "falhar, o processo continua vivo, porém sem banco;",
    "as imagens usam <i>mongo:latest</i> e <i>node:18-alpine</i>, versão sem suporte desde abril de 2025.",
])
P("Esses pontos coincidem com a seção 5 do escopo, que pede expressamente sua correção. O escopo (seção 13) inclui "
  "as adaptações de configuração na entrega, e o PM-04 dispensa o desenvolvimento do sistema. Por isso as alterações no "
  "código ficaram restritas à configuração: URL base da API vinda do ambiente (vazia, ou seja, mesmo endereço da "
  "página), MONGO_URI e CORS_ORIGIN por variável de ambiente, encerramento do processo quando a primeira conexão "
  "falha (o Docker reinicia o contêiner), configuração do Nginx para encaminhar /todos, e Dockerfiles com Node 22 e "
  "API executada sem root. Rotas, métodos e comportamento da lista foram preservados.")

# ---------------------------------------------------------------- 3
P("3. Requisitos identificados", h1)
P("Requisitos explícitos do escopo:", h2)
table([
    ["ID", "Requisito", "Como foi atendido"],
    ["REQ-01", "No mínimo duas VMs; MongoDB em VM exclusiva", "VM <i>app</i> e VM <i>db</i> criadas pelo Terraform"],
    ["REQ-02", "27017 liberada só para a API; banco fora da internet", "VM do banco em sub-rede privada sem IP público; Security Group aceita 27017 apenas do SG da aplicação; porta publicada só no IP privado"],
    ["REQ-03", "Administração restrita; credencial própria no banco; segredos fora do código e dos logs", "SSH fechado por padrão e aberto só para o IP do runner durante o job; usuário <i>todo_app</i> com readWrite apenas no banco da aplicação; GitHub Secrets, OIDC e <i>no_log</i>"],
    ["REQ-04", "Armazenamento persistente, backup e restauração testada", "Volume EBS separado; backup diário para disco local e S3; rotina de restauração em contêiner isolado"],
    ["REQ-05", "URL HTTPS com frontend e API no mesmo endereço", "Caddy com Let's Encrypt em <i>&lt;ip&gt;.sslip.io</i>; Nginx encaminha /todos para a API"],
    ["REQ-06", "Reinício, saúde e diagnóstico, incluindo API-banco", "restart <i>unless-stopped</i>, healthchecks (o da API consulta o banco), rotinas de health, logs e restart"],
    ["Seções 7-10", "Pipelines de infraestrutura, entrega, operação e desativação", "infra.yml, app.yml, ops.yml, destroy.yml e ci.yml"],
    ["Seção 12", "Estimativa de custo mensal e do período", "docs/custos.md, resumida na seção 4.3"],
], [1.7 * cm, 5.6 * cm, 9.3 * cm])
P("Requisitos explícitos do PM-04: pipeline com execução manual e parâmetros que alteram o ambiente; Terraform com VM, "
  "rede e regras de acesso, variáveis, init/plan/apply pela pipeline e state preservado; atualização sem recriações "
  "desnecessárias; Ansible preparando o ambiente do zero, instalando Docker, mantendo contêineres, pacotes e o sistema "
  "operacional conforme parâmetro, com idempotência; e os três cenários de teste.")
P("Decisões da equipe (não escritas nos documentos) estão identificadas como tal no arquivo "
  "<i>docs/decisoes-arquiteturais.md</i>, que registra 24 decisões com origem e justificativa. Hipóteses adotadas porque o "
  "escopo não informa: até 50 visitantes simultâneos, dois dias de ensaio e um dia de evento, e uso de sslip.io até a "
  "organização fornecer um domínio.")

# ---------------------------------------------------------------- 4
story.append(PageBreak())
P("4. Arquitetura proposta", h1)
story.append(Image(str(ROOT / "evidencias/arquitetura/diagrama-arquitetura.png"), width=17 * cm, height=17 * cm * 784 / 2404))
P("Figura 1: arquitetura do ambiente dev na AWS (fonte: evidencias/arquitetura/arquitetura.dot).", small)
P("O visitante acessa <i>https://&lt;ip&gt;.sslip.io</i>. O Caddy, na VM da aplicação, termina o TLS e repassa ao Nginx, "
  "que entrega o React e encaminha /todos e /todos/:id ao contêiner da API. A API é o único componente que acessa o "
  "MongoDB, pela rede privada, com o usuário <i>todo_app</i>. A VM do banco não tem endereço público: sua saída para a "
  "internet (pacotes e imagem do MongoDB) passa pela VM da aplicação, que faz o NAT, e os backups seguem para o S3 por "
  "um endpoint de gateway.")
P("4.1 Justificativas das escolhas técnicas", h2)
B([
    "<b>AWS, us-east-1.</b> A equipe já possui conta, a região tem o menor preço para a família t3 e a AWS aceita OIDC do "
    "GitHub, o que elimina chaves de acesso armazenadas.",
    "<b>t3.micro com créditos standard.</b> 2 vCPU e 1 GiB atendem a lista de tarefas com o público estimado. O modo "
    "padrão da família T3 é <i>unlimited</i>, que cobra uso acima da linha de base; o modo standard limita o custo ao preço "
    "por hora. A troca para t3.small é feita pela pipeline.",
    "<b>NAT pela VM da aplicação.</b> Mantém o banco sem IP público sem pagar um NAT Gateway (US$ 0,045 por hora, cerca de "
    "US$ 32,85 por mês, mais tráfego), valor maior que o das duas VMs juntas.",
    "<b>Elastic IP.</b> A troca do tipo da VM exige parar e iniciar a instância; com IP elástico a URL e o certificado não mudam.",
    "<b>Caddy e sslip.io.</b> Certificado válido e renovado automaticamente sem domínio próprio. Basta preencher a "
    "variável APP_DOMAIN quando houver domínio.",
    "<b>Docker do repositório do Ubuntu (docker.io).</b> Sem repositório nem chave de terceiros; é atualizado pelo mesmo "
    "<i>apt</i> controlado pelo parâmetro update_os. Docker Compose não foi instalado porque os contêineres são "
    "gerenciados diretamente pelos módulos do Ansible.",
    "<b>Volume EBS dedicado ao MongoDB.</b> Recriar o contêiner, trocar o tipo da VM ou atualizar a aplicação não afeta os "
    "dados. A pipeline Infra é interrompida se o plano tentar remover esse volume.",
    "<b>State no S3 com lock nativo.</b> Bucket versionado, criptografado e privado, uma chave por ambiente e lock por "
    "arquivo (<i>use_lockfile</i>), sem DynamoDB e sem guardar state em artefatos da pipeline.",
])
P("4.2 Segurança", h2)
B([
    "SSH na VM da aplicação fechado por padrão; a pipeline libera a porta 22 apenas para o IP do runner e remove a regra "
    "ao final, mesmo em caso de falha. A VM do banco só aceita SSH a partir da VM da aplicação (bastion).",
    "SSH somente com chave e sem login de root; IMDSv2 obrigatório; discos e buckets criptografados; Security Group "
    "padrão da VPC sem regras.",
    "Senhas do MongoDB entregues ao contêiner do banco em arquivos 0400 montados somente leitura, não em variáveis de "
    "ambiente; tarefas com segredos usam <i>no_log</i>.",
    "Papel da pipeline aceito apenas para os GitHub Environments do repositório; papel da VM do banco restrito ao "
    "prefixo do próprio ambiente no bucket de backups.",
    "Tipos de VM limitados por validação, como controle de custo.",
])
P("4.3 Custos", h2)
P("Preços sob demanda de us-east-1 consultados em 24/11/2026: t3.micro a US$ 0,0104 por hora, gp3 a US$ 0,08 por GB-mês e "
  "IPv4 público a US$ 0,005 por hora; os primeiros 100 GB mensais de transferência para a internet são gratuitos. Com as "
  "duas VMs t3.micro, 38 GB de EBS e um IPv4, o custo de referência é de cerca de US$ 21,97 por mês. O período da feira, "
  "estimado em 15 dias ligados (360 horas), custa cerca de US$ 10,90; removendo o ambiente entre ensaios, três dias de "
  "ensaio mais o dia do evento custam cerca de US$ 3,00. Após a desativação continuam apenas os buckets de state e de "
  "backups, com custo de centavos. Créditos promocionais da conta não foram descontados. O cálculo, as premissas e as "
  "fontes estão em docs/custos.md.")

# ---------------------------------------------------------------- 5
story.append(PageBreak())
P("5. Implementação do Terraform", h1)
P("O código foi dividido em duas stacks. A stack <i>terraform/bootstrap</i> é executada uma única vez, localmente, com "
  "credenciais de administrador, e cria o que a pipeline precisa antes da primeira execução: o bucket do state, o bucket "
  "de backups com retenção de 30 dias, o provedor OIDC do GitHub e o papel IAM da pipeline. A stack principal, em "
  "<i>terraform/</i>, cria o ambiente e está separada por responsabilidade:")
B([
    "<i>providers.tf</i> e <i>backend.tf</i>: provider AWS 6.x com tags padrão (Project, Environment, ManagedBy, Course) e "
    "backend S3 com configuração parcial, preenchida pela pipeline com a chave <i>todo-app/&lt;env&gt;/terraform.tfstate</i>;",
    "<i>network.tf</i>: VPC, sub-redes pública e privada na mesma zona, Internet Gateway, rotas (a privada aponta para a "
    "interface da VM da aplicação) e endpoint S3;",
    "<i>security.tf</i>: Security Groups com regras como recursos separados, para que a regra SSH temporária criada pela "
    "pipeline não entre no state nem seja removida pelo Terraform;",
    "<i>compute.tf</i>, <i>storage.tf</i> e <i>iam.tf</i>: par de chaves, duas VMs Ubuntu 24.04, Elastic IP, volume de dados e "
    "papel da VM do banco;",
    "<i>variables.tf</i>, <i>outputs.tf</i>, <i>terraform.tfvars.example</i> e <i>environments/*.tfvars</i>: parâmetros com "
    "validação e CIDRs distintos por ambiente.",
])
P("Para evitar recriações, a AMI é escolhida apenas na criação (<i>ignore_changes = [ami]</i>); a troca de "
  "<i>instance_type</i> é feita no lugar; a troca de <i>instance_name</i> altera somente tags. O arquivo "
  "<i>tests/plan.tftest.hcl</i> verifica, com provider simulado, a separação das sub-redes, a ausência de IP público no "
  "banco, a regra da porta 27017, a criptografia, o IMDSv2, os créditos standard e a rejeição de parâmetros inválidos.")

P("6. Implementação do Ansible", h1)
P("O playbook <i>ansible/playbook.yml</i> recebe os parâmetros da pipeline em um arquivo JSON e executa os roles em três "
  "etapas. Na VM da aplicação: <i>os_updates</i> (sempre verifica as atualizações pendentes; aplica <i>dist-upgrade</i> e "
  "reinicia se necessário apenas com update_os=true), <i>packages</i> (pacotes base e extra_packages), <i>system</i> (fuso "
  "horário, SSH restrito e swap), <i>docker</i> (instalação, rotação de logs, live-restore e início automático) e "
  "<i>nat_gateway</i> (encaminhamento e mascaramento da sub-rede privada como serviço systemd, reaplicado quando o Docker "
  "reinicia). Na VM do banco, acessada através da VM da aplicação: os mesmos roles de sistema, <i>data_volume</i> (formata "
  "o EBS apenas se estiver vazio e monta em /srv/mongo-data), <i>mongodb</i> (contêiner mongo:8.0 publicado só no IP "
  "privado, com healthcheck e teste da credencial da aplicação) e <i>backup</i> (scripts, cron diário e rotação de log). "
  "Por fim, na VM da aplicação, <i>app_stack</i> cria a rede Docker e os contêineres backend, frontend e caddy, aguarda "
  "todos ficarem saudáveis e registra a versão atual e a anterior em /opt/todo-app/release.json.")
P("O playbook <i>verify.yml</i> confere contêineres saudáveis, política de reinício, Docker habilitado, volume montado, "
  "backup agendado e NAT; da VM da aplicação, testa a conexão privada com a porta 27017; do runner, abre a página por "
  "HTTPS, executa o fluxo completo da API (cria, conclui, reabre e exclui uma tarefa de teste) e confirma que a porta "
  "27017 não responde no IP público. O playbook <i>ops.yml</i> reúne as rotinas operacionais.")
P("A idempotência vem do uso de módulos com estado desejado, de <i>changed_when: false</i> nas consultas, do login no "
  "registro de imagens apenas quando falta imagem no host e da recriação de contêineres somente quando a imagem ou a "
  "configuração muda.")

# ---------------------------------------------------------------- 7
P("7. Integração com GitHub Actions", h1)
P("A pipeline <i>infra.yml</i> é acionada por <i>workflow_dispatch</i>, roda no GitHub Environment escolhido (secrets e "
  "aprovação por ambiente) e usa <i>concurrency</i> para impedir duas execuções simultâneas no mesmo ambiente. As etapas "
  "seguem a ordem pedida: validação dos parâmetros; instalação de Terraform 1.16.7 e Ansible 14.6.0; credenciais AWS por "
  "OIDC e chave SSH a partir do secret; terraform init, fmt -check e validate; plan salvo em arquivo, com bloqueio caso o "
  "volume de dados fosse removido; apply do plano salvo, pulado quando não há alterações; leitura dos outputs; geração do "
  "inventário e liberação temporária do SSH; execução do playbook; verificação; e resumo da execução. A remoção da regra "
  "SSH e da chave e a publicação das evidências como artifact rodam sempre, inclusive após falha.")
P("A integração entre as ferramentas ocorre pelos outputs do Terraform: <i>scripts/render-inventory.sh</i> gera o "
  "inventário com o IP público da aplicação, o IP privado do banco (acessado com ProxyCommand pela VM da aplicação), o "
  "domínio, o ID do volume de dados, a sub-rede privada e o bucket de backups. Os parâmetros da execução chegam ao "
  "Ansible por <i>pipeline-vars.json</i>, gerado pelo script de validação. Entradas do usuário nunca são interpoladas "
  "diretamente nos comandos do shell: passam por variáveis de ambiente e expressões regulares.")
P("Pipelines complementares: <i>app.yml</i> valida o código (instalação, verificação de sintaxe e build do React) e "
  "publica as imagens no GitHub Container Registry com tag <i>sha-&lt;commit&gt;</i>; <i>ops.yml</i> executa health, logs, "
  "reinício, recriação do contêiner do banco, backup, teste de restauração, limpeza da lista e restauração (as duas "
  "últimas exigem a palavra CONFIRMAR); <i>destroy.yml</i> faz um backup final e remove o ambiente, listando o que "
  "permanece; <i>ci.yml</i> executa as validações estáticas em pull requests.")

P("8. Parâmetros", h1)
table([
    ["Parâmetro", "Valores", "Efeito no ambiente"],
    ["environment", "dev, homolog, prod", "GitHub Environment, chave do state, VPC e nomes dos recursos"],
    ["instance_name", "ex.: vm-pm04", "Tag Name das VMs (o banco recebe -db); alteração apenas de tag"],
    ["instance_type", "t3.micro, t3.small, t3.medium", "Tamanho da VM da aplicação; alteração no lugar pelo Terraform"],
    ["db_instance_type", "mesmo conjunto", "Tamanho da VM do banco (adicional, exigido pelas duas VMs do escopo)"],
    ["docker_image", "vazio ou prefixo", "Origem das imagens; vazio usa ghcr.io/&lt;dono&gt;/todo-app-{frontend,backend}"],
    ["docker_tag", "ex.: sha-1a2b3c4", "Versão implantada; troca recria só os contêineres da aplicação"],
    ["update_os", "true, false", "Aplica dist-upgrade e reinicia a VM se o Ubuntu pedir"],
    ["extra_packages", "lista separada por vírgula", "Pacotes apt adicionais, validados por expressão regular"],
    ["plan_only", "true, false", "Executa somente até o plano (adicional, para revisão)"],
], [3.2 * cm, 4.2 * cm, 9.2 * cm])

# ---------------------------------------------------------------- 9
story.append(PageBreak())
P("9. Testes dos três cenários", h1)
P("O roteiro de cada cenário, com parâmetros e resultado esperado, está em evidencias/cenario-*/README.md.")
B([
    "<b>Cenário 1, criação:</b> environment=dev, t3.micro nas duas VMs, docker_tag com a tag A, update_os=false, "
    "extra_packages=curl,git,unzip. Espera-se a criação de 30 recursos, Docker e contêineres instalados e a verificação "
    "pública aprovada.",
    "<b>Cenário 2, atualização:</b> instance_type=t3.small (alteração no lugar de aws_instance.app), docker_tag com a "
    "tag B, update_os=true e extra_packages com htop. Espera-se 1 recurso alterado, contêineres da aplicação recriados, "
    "banco intacto e as tarefas preservadas.",
    "<b>Cenário 3, reexecução:</b> mesmos parâmetros do Cenário 2. Espera-se plano sem alterações, apply pulado e "
    "changed=0 no Ansible.",
])
P("<b>Situação:</b> a execução dos três cenários na AWS e no GitHub Actions ainda não foi realizada, pois depende da "
  "conta AWS e do fork do repositório da equipe. A automação está pronta e os testes abaixo foram executados no ambiente "
  "de desenvolvimento.", body)

P("10. Evidências de execução", h1)
P("10.1 Validações estáticas", h2)
P("terraform fmt e validate nas duas stacks, terraform test com 7 casos aprovados, checkov com 161 verificações "
  "aprovadas, nenhuma falha e 18 exceções justificadas no próprio código (custos como KMS dedicado, flow logs e "
  "monitoramento detalhado), syntax-check dos três playbooks, ansible-lint no perfil production sem falhas, actionlint "
  "nos cinco workflows, shellcheck e yamllint. A validação local do Terraform usou OpenTofu 1.13 com o provider "
  "hashicorp/aws 6.74.0, porque o binário do Terraform não pôde ser baixado no ambiente de desenvolvimento; a pipeline "
  "usa Terraform 1.16.7. Arquivo: evidencias/testes-locais/validacoes-estaticas.log.")
P("10.2 Roles do Ansible contra servidores Ubuntu 24.04", h2)
P("Os roles reais foram executados contra dois contêineres Ubuntu 24.04 com systemd, criados a partir do arquivo oficial "
  "do Ubuntu e usados como substitutos das VMs, com um disco em loop device no mesmo caminho do volume EBS. O resultado "
  "demonstra o comportamento esperado nos Cenários 1 a 3 para a camada Ansible:")
log_excerpt("evidencias/testes-locais/ansible-alvo-container/logs/00-resumo-sequencia.txt", grep=["###", " : ok="])
P("Na rodada 01, o Ubuntu foi atualizado, o Docker 29.1.3 foi instalado do repositório do Ubuntu, o NAT foi configurado "
  "e o volume de dados foi formatado e montado. Na 02, com os mesmos parâmetros, não houve alteração. Na 03, apenas a "
  "instalação dos novos pacotes. Nas rodadas 04 a 06 foram usadas imagens substitutas com os mesmos nomes, pois o "
  "ambiente de desenvolvimento não acessa registros públicos: a mesma tag não gerou alteração e a tag nova recriou "
  "apenas a API e o frontend, registrando a versão anterior.")
P("10.3 Aplicação adaptada e rotinas de dados", h2)
P("O teste <i>evidencias/testes-locais/teste-integracao-local.sh</i> executou a aplicação com MongoDB 8.0.23 real, API em "
  "Node 22, build de produção servido pelo Nginx com a configuração do repositório e Caddy com HTTPS, além dos scripts "
  "de backup e restauração gerados pelo Ansible, com S3 simulado. Foram 33 verificações e nenhuma falha. Trecho:")
log_excerpt("evidencias/testes-locais/teste-integracao-local.log", grep=["[OK]", "[FALHA]", "== Resultado"])
P("Esse teste também revelou um erro corrigido durante o trabalho: o filtro <i>urlencode</i> do Ansible não codifica a "
  "barra, e uma senha com \"/\" quebraria a MONGO_URI. A expressão passou a substituir a barra por %2F, e o teste usa "
  "senhas com / @ : ? #.")
P("Limites: os testes locais não cobrem o Terraform contra a AWS, as imagens oficiais em contêiner, a emissão do "
  "certificado Let's Encrypt e a rede entre VMs na VPC. Esses pontos serão evidenciados pelos artifacts das execuções "
  "reais (plano, apply, outputs, logs do Ansible e verificação externa), publicados automaticamente pela pipeline.")

# ---------------------------------------------------------------- 11
story.append(PageBreak())
P("11. Relação entre a demanda e a infraestrutura entregue", h1)
table([
    ["Critério de aceite (escopo)", "Recurso ou rotina que atende", "Situação"],
    ["ACE-01 Reprodução", "Terraform + Ansible + pipelines, parâmetros e secrets documentados no README", "Implementado; execução real pendente"],
    ["ACE-02 Duas VMs", "aws_instance.app e aws_instance.db; outputs listam IDs e tipos", "Implementado; testado com provider simulado"],
    ["ACE-03 Isolamento", "Sub-rede privada, SG 27017 só da app; teste de porta fechada na pipeline", "Implementado; execução real pendente"],
    ["ACE-04 Aplicação pública", "Caddy HTTPS; fluxo CRUD automatizado na verificação", "Fluxo validado localmente por HTTPS"],
    ["ACE-05 Persistência", "Volume EBS, rotinas restart-db e recreate-db", "Validado localmente; execução real pendente"],
    ["ACE-06 Automação", "infra.yml e app.yml com tag sha-&lt;commit&gt;; rollback pela tag anterior", "Implementado; execução real pendente"],
    ["ACE-07 Recuperação", "Backup diário e restore-test em contêiner sem rede", "Scripts validados localmente"],
    ["ACE-08 Operação", "ops.yml (health, logs, restart), destroy.yml, segredos fora do código", "Implementado"],
    ["ACE-09 Custos", "docs/custos.md", "Concluído"],
    ["ACE-10 Transferência", "docs/manual-operacao.md", "Manual pronto; ensaio com os alunos pendente"],
], [4.0 * cm, 8.0 * cm, 4.6 * cm])

P("12. Conclusão", h1)
P("A solução transforma os requisitos do escopo em infraestrutura automatizada: duas VMs com o banco isolado na rede "
  "privada, entrada única por HTTPS, dados em volume persistente com backup e restauração testados, e operações "
  "disponíveis aos alunos por pipelines, sem acesso manual aos servidores. As escolhas priorizaram baixo custo (NAT na "
  "VM da aplicação, créditos standard, sslip.io) sem abrir mão do isolamento exigido.")
P("Os testes executados comprovam a configuração das adaptações da aplicação, o funcionamento das rotinas de dados e a "
  "idempotência dos roles do Ansible. Ficam pendentes as execuções reais dos três cenários na conta AWS da equipe, cujo "
  "roteiro e coleta de evidências estão prontos. Entre as limitações conhecidas estão a ausência de alta "
  "disponibilidade, a dependência do sslip.io e do Let's Encrypt sem domínio próprio e a aceitação da chave do host na "
  "primeira conexão SSH, já que os runners são efêmeros.")

P("Referências técnicas", h1)
B([
    "Escopo do ToDo App v1.0 e PM-04 (documentos da disciplina).",
    "HashiCorp. Terraform S3 backend (use_lockfile): https://developer.hashicorp.com/terraform/language/backend/s3",
    "AWS. EC2 On-Demand Pricing: https://aws.amazon.com/ec2/pricing/on-demand/",
    "AWS. Amazon EBS pricing: https://aws.amazon.com/ebs/pricing/",
    "AWS. Public IPv4 address charge: https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/",
    "AWS. Amazon VPC pricing (NAT Gateway): https://aws.amazon.com/vpc/pricing/",
    "GitHub. About billing for GitHub Actions: https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions",
    "Ansible community.docker collection: https://docs.ansible.com/ansible/latest/collections/community/docker/",
])


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("DejaVu", 8)
    canvas.setFillColor(colors.grey)
    if doc.page > 1:
        canvas.drawString(2 * cm, 1.2 * cm, "PM-04 | ToDo App na AWS com Terraform, Ansible e GitHub Actions")
        canvas.drawRightString(A4[0] - 2 * cm, 1.2 * cm, f"Página {doc.page}")
    canvas.restoreState()


SimpleDocTemplate(str(OUT), pagesize=A4, leftMargin=2.2 * cm, rightMargin=2.2 * cm, topMargin=2 * cm,
                  bottomMargin=2 * cm, title="PM-04 Projeto Final - ToDo App",
                  author="Lucas Vieira dos Santos").build(story, onFirstPage=footer, onLaterPages=footer)
print(OUT)
