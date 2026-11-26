# Estimativa de custos (ACE-09)

## Premissas

- Provedor e região: AWS, us-east-1 (Norte da Virgínia).
- Moeda: dólar americano (US$), preços sob demanda, consultados em 24/11/2026.
- Mês de referência: 730 horas.
- Ambiente: somente `dev` ligado; `homolog` e `prod` existem na automação, mas não são criados.
- Período da feira (hipótese, pois a data e o público não foram informados): 14 dias de preparação e ensaio com o ambiente ligado 24 horas, mais 1 dia de evento.
- Tráfego estimado: menos de 1 GB por mês (página de cerca de 75 kB compactada e respostas JSON pequenas).

## Recursos e preços unitários

Máquinas virtuais

- VM da aplicação: t3.micro, 2 vCPU, 1 GiB, US$ 0,0104 por hora. Roda Caddy, Nginx e a API Node.js, e faz o NAT da sub-rede privada.
- VM do banco: t3.micro, 2 vCPU, 1 GiB, US$ 0,0104 por hora. MongoDB com cache limitado a 256 MB.
- Créditos de CPU em modo `standard`: não há cobrança acima do preço por hora (no modo `unlimited`, o uso sustentado acima da linha de base seria cobrado à parte).
- Alteração prevista no Cenário 2: VM da aplicação em t3.small (2 GiB), US$ 0,0208 por hora.

Armazenamento

- Disco raiz da aplicação: 16 GB gp3.
- Disco raiz do banco: 12 GB gp3.
- Volume de dados do MongoDB: 10 GB gp3, separado do disco raiz.
- Preço gp3: US$ 0,08 por GB-mês, com 3.000 IOPS e 125 MB/s incluídos (os volumes usam o desempenho básico).
- Backups: arquivos `mongodump` compactados no S3, da ordem de quilobytes para a lista de demonstração; retenção de 30 dias.
- Terraform State: alguns quilobytes no S3, com versionamento.

Rede e serviços auxiliares

- Um endereço IPv4 público (Elastic IP associado à VM da aplicação): US$ 0,005 por hora. A VM do banco não tem IP público.
- NAT Gateway: não usado. Custaria US$ 0,045 por hora mais US$ 0,045 por GB processado (cerca de US$ 32,85 por mês só de tempo ligado). A função é feita pela VM da aplicação.
- Endpoint de gateway do S3: sem custo.
- Transferência para a internet: os primeiros 100 GB por mês são gratuitos (somando todos os serviços), o que cobre com folga o tráfego previsto.
- DNS e certificado: sem custo (sslip.io e Let's Encrypt). Um domínio próprio, se a organização quiser, tem o custo do registro.
- Logs: ficam no Docker das VMs, com rotação (10 MB x 3 arquivos por contêiner). CloudWatch não é usado.
- Pipelines: os runners padrão do GitHub Actions são gratuitos em repositórios públicos; em repositório privado, consomem a cota mensal incluída no plano da conta.

## Custo mensal de referência (ambiente dev ligado o mês todo)

- 2 VMs t3.micro: 2 x 0,0104 x 730 = US$ 15,18
- 38 GB de EBS gp3: 38 x 0,08 = US$ 3,04
- 1 IPv4 público: 0,005 x 730 = US$ 3,65
- S3 (state e backups, menos de 1 GB): menos de US$ 0,10
- Transferência de dados: US$ 0,00 (dentro dos 100 GB gratuitos)
- Total: cerca de US$ 21,97 por mês

Com a VM da aplicação em t3.small o total sobe para cerca de US$ 29,56 por mês (diferença de 0,0104 x 730 = US$ 7,59).

## Custo do período da feira (15 dias ligados = 360 horas)

- VMs: 2 x 0,0104 x 360 = US$ 7,49
- EBS: 38 x 0,08 x 15/30 = US$ 1,52
- IPv4: 0,005 x 360 = US$ 1,80
- S3 e transferência: menos de US$ 0,10
- Total: cerca de US$ 10,90

Para reduzir o valor, o ambiente pode ser removido entre ensaios com a pipeline Destroy e recriado com a pipeline Infra (a lista volta aos dados de demonstração, e os backups continuam no S3). Três dias de ensaio mais o dia da feira (96 horas) custam cerca de US$ 3,00.

## O que continua gerando cobrança após a desativação

A pipeline Destroy remove VMs, volumes, Elastic IP, VPC, Security Groups e o papel IAM da VM. Permanecem:

- bucket de backups: os backups expiram em 30 dias pela regra de ciclo de vida; custo de centavos;
- bucket do Terraform State: alguns quilobytes, custo de centavos;
- papel IAM e provedor OIDC da pipeline: sem custo;
- imagens no GitHub Container Registry: sem custo para repositório público.

Para zerar a conta, esvaziar os dois buckets e executar `terraform destroy` na stack `terraform/bootstrap` (o bucket de state tem `prevent_destroy`, que precisa ser removido antes de forma intencional).

## Créditos e faixas gratuitas

Os valores acima são o custo bruto. Créditos promocionais da conta AWS, quando existirem, são abatidos à parte e não foram descontados. Contas criadas a partir de 15/07/2025 recebem créditos em vez da antiga camada gratuita de 12 meses; por isso não foi considerado nenhum desconto de free tier nas VMs, nos discos ou no IPv4.

## Fatores de variação

- tempo em que o ambiente fica ligado (o principal fator);
- troca do tipo das VMs pela pipeline;
- tráfego acima de 100 GB no mês (improvável para a feira);
- ambientes `homolog` ou `prod` ligados ao mesmo tempo (cada um repete o custo do `dev`);
- reajustes de preço da AWS após a data da consulta.

## Fontes

- Preços EC2 sob demanda e família T3: https://aws.amazon.com/ec2/pricing/on-demand/ e https://aws.amazon.com/ec2/instance-types/t3/
- Preço do gp3: https://aws.amazon.com/ebs/pricing/
- Cobrança de IPv4 público: https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/
- NAT Gateway e VPC: https://aws.amazon.com/vpc/pricing/
- Transferência gratuita de 100 GB: https://aws.amazon.com/about-aws/whats-new/2021/11/aws-price-reduction-data-transfers-internet/
- Nova camada gratuita (julho de 2025): https://aws.amazon.com/about-aws/whats-new/2025/07/aws-free-tier-credits-month-free-plan/
- Cobrança do GitHub Actions: https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions
