# infra-network

Produto de infraestrutura responsável pela rede base na AWS. Provisiona uma
VPC de alta disponibilidade, segmenta sub-redes públicas, privadas e de bancos
de dados e publica seus identificadores no AWS Systems Manager Parameter Store
para consumo pelos produtos downstream.

## Escopo do produto

Inclui:

- VPC com DNS habilitado;
- três sub-redes públicas, três privadas e três de bancos de dados, distribuídas
  entre as zonas de disponibilidade `us-east-1a`, `us-east-1b` e `us-east-1c`;
- Internet Gateway e roteamento das sub-redes públicas;
- um NAT Gateway por zona de disponibilidade para saída das sub-redes privadas;
- configuração de logging do API Gateway na conta;
- publicação dos IDs da VPC e das sub-redes no SSM Parameter Store.

Não inclui clusters Kubernetes, workloads, serviços compartilhados de
plataforma ou observabilidade. Esses recursos pertencem aos produtos downstream.

## Arquitetura

![Topologia da rede AWS](/docs/network-architecture.png)

## Planejamento das sub-redes

![Planejamento de endereçamento das sub-redes](/docs/subnet-address-plan.png)

## Dependências e contratos

O `infra-cluster` consome os parâmetros publicados sob o prefixo
`/<project_name>/vpc/`. O valor de `project_name` deve ser idêntico nos dois
repositórios; o valor operacional atual é `infra-network`.

Parâmetros publicados:

- `/infra-network/vpc/vpc_id`;
- `/infra-network/vpc/subnet_private_1a`, `1b` e `1c`;
- `/infra-network/vpc/subnet_public_1a`, `1b` e `1c`;
- `/infra-network/vpc/subnet_databases_1a`, `1b` e `1c`.

## Uso local

Pré-requisitos: Terraform 1.11 ou superior, credenciais AWS e acesso ao bucket
S3 configurado como backend.

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
```

O arquivo `terraform.tfvars` não deve ser commitado. Revise substituições e
deleções no plano antes de qualquer aplicação.

## GitHub Actions

Pull Requests executam formatação, validação, TFLint, Trivy e Terraform plan.
O push em `main` executa o apply por meio do environment `production`. Consulte
[`CI-SETUP.md`](/CI-SETUP.md) para os pré-requisitos, permissões e pendências
operacionais do pipeline.

## Operação e rollback

- Não execute plans ou applies concorrentes para o mesmo state.
- Para rollback de código, reverta o commit e gere um novo plano.
- Não altere o state manualmente sem backup e plano de migração.
- Preserve os nomes dos parâmetros SSM: eles formam o contrato público com o
  `infra-cluster`.

## Ownership

Owner: time de Cloud Platform. Mudanças em CIDRs, rotas, NAT Gateways, IAM ou no
contrato SSM exigem revisão técnica e evidência do Terraform plan.

Licença: MIT.
