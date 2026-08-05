# AGENTS.md — infra-network

Este arquivo é a fonte da verdade para qualquer assistente de IA (ou humano)
trabalhando neste repositório. Ele só contém fatos verificados no código
atual — nada de suposição. Se você (IA) precisar de um nome de variável, um
path de SSM, ou uma versão de provider, **confira aqui antes de inventar**.
Se editar o código, atualize este arquivo no mesmo PR — um AGENTS.md
desatualizado é pior do que nenhum, porque gera confiança falsa.

## O que este repositório faz

Provisiona a rede base na AWS (VPC, subnets públicas/privadas/databases, NAT
Gateway, Internet Gateway) e publica os IDs criados no **SSM Parameter
Store**, para que outros repositórios (`infra-cluster`) consumam sem acoplar
diretamente no state deste repositório.

Este repo **não** cria cluster, nem nada de Kubernetes. Escopo é só rede.

## Inventário real de arquivos

| Arquivo | Conteúdo |
|---|---|
| `versions.tf` | `required_version` e `required_providers` |
| `providers.tf` | provider `aws` com `default_tags` |
| `backend.tf` | bloco `backend "s3" {}` **vazio** — precisa de `-backend-config` no `terraform init` |
| `variables.tf` | `project_name`, `region`, `environment` |
| `vpc.tf` | `aws_vpc.main` — CIDR fixo `10.0.0.0/16` |
| `public_subnets.tf` | 3 subnets públicas (1a/1b/1c) + route table + IGW route |
| `private_subnets.tf` | 3 subnets privadas (1a/1b/1c) + route tables + rotas via NAT |
| `databases_subnet.tf` | 3 subnets de banco de dados (1a/1b/1c), sem rota própria de saída |
| `nat_gateway.tf` | 3 EIPs + 3 NAT Gateways (um por AZ) |
| `internet_gateway.tf` | 1 Internet Gateway |
| `api_gateway_setup.tf` | IAM role + policy attachment para logging do API Gateway na conta |
| `parameters_store.tf` | publica VPC ID + todos os subnet IDs no SSM |
| `output.tf` | outputs dos IDs dos parâmetros SSM criados |
| `terraform.tfvars.example` | exemplo de valores para as variáveis obrigatórias |

**Não existe** separação de ambiente (dev/staging/prod) — é um único diretório
flat com um único state. Não assuma a existência de `envs/dev`, `envs/prod`
etc. até que sejam criados.

## Variáveis (nomes e tipos exatos)

```hcl
variable "project_name" { type = string }  # obrigatória, sem default
variable "region"       { type = string }  # obrigatória, validada como formato de região AWS
variable "environment"  { type = string }  # obrigatória, validada: "dev" | "staging" | "prod"
```

Nenhuma outra variável existe neste repositório.

## Contrato entre repositórios — paths do SSM Parameter Store

Este é o contrato real que `infra-cluster` (e qualquer outro repo) deve
consumir. O prefixo é sempre `var.project_name`:

```
/{project_name}/vpc/vpc_id
/{project_name}/vpc/subnet_private_1a
/{project_name}/vpc/subnet_private_1b
/{project_name}/vpc/subnet_private_1c
/{project_name}/vpc/subnet_public_1a
/{project_name}/vpc/subnet_public_1b
/{project_name}/vpc/subnet_public_1c
/{project_name}/vpc/subnet_databases_1a
/{project_name}/vpc/subnet_databases_1b
/{project_name}/vpc/subnet_databases_1c
```

Todos são `String`, valor = o ID do recurso (`vpc-xxxx`, `subnet-xxxx`). Não
existe parâmetro publicado para "pod subnets" separado — o `infra-cluster`
reaproveita as subnets privadas para isso (ver o `AGENTS.md` daquele repo).

Se o nome do parâmetro mudar aqui, **quebra silenciosamente** o
`infra-cluster` — o Terraform lá só falha no `terraform init`/`plan` ao não
achar o parâmetro. Trate esse contrato como uma API pública.

## Provider e versões travadas

```hcl
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.42" }
  }
}
```

## Tags aplicadas automaticamente

Via `default_tags` no provider `aws` — não precisa (e não deve) adicionar
tags manuais de `Project`/`Environment`/`ManagedBy` em cada resource:

```
Project     = var.project_name
Environment = var.environment
ManagedBy   = "terraform"
Repository  = "infra-network"
```

## CI/CD

O workflow se chama **"Terraform Pipeline"** (não "Terraform" — o `name:`
foi renomeado em edição direta em `main`), em
`.github/workflows/terraform.yml`, com 4 jobs: `lint` (fmt/validate/tflint,
job renomeado "Lint e Validate") → `trivy-scan` ("Trivy IaC Scan": scan de
segurança com Trivy, `scan-type: config`, gera SARIF) → `plan` (comenta o
plan na PR, environment `plan`) → `apply` (roda no push em `main`, atrás do
environment `production`). Tem também um bloco `concurrency` pra evitar
execuções simultâneas no mesmo state.

O job `trivy-scan` está com `exit-code: 0` **de propósito** — decisão
tomada em `main` (commit "não falhar o job se houver vulnerabilidades,
apenas gerar o relatório"): o scan nunca bloqueia o pipeline, só alimenta a
aba Security > Code scanning. Não confunda isso com um bug esquecido.

**Status real verificado (última checagem: 04/08/2026):**
- ✅ Variables `AWS_REGION`, `TF_STATE_BUCKET`, `TF_STATE_KEY`,
  `TF_LOCK_TABLE` — configuradas e corretas
- ✅ Environments `plan` e `production` — existem
- ⚠️ Environment `production` **sem required reviewer configurado** — a
  aprovação manual antes do apply, que era o objetivo original, não está
  ativa ainda
- ⚠️ Sobrou um environment `AWS_REGION` (criado por engano numa tentativa
  anterior) — não é usado por nenhum job, pode ser apagado
- ❌ Secret `AWS_ROLE_ARN` — o job `apply` falha no step "Configurar
  credenciais AWS via OIDC" (execução #29, `main`), o que indica que a
  IAM Role de OIDC ainda não existe ou o secret não foi criado

Não assuma que o apply automático com aprovação manual está funcionando —
hoje ele falha antes de chegar no `terraform apply`.

**Importante sobre o fluxo de trabalho real**: várias mudanças recentes
neste workflow foram commitadas **direto em `main`**, sem passar por PR
(ver histórico de commits do arquivo). Isso quebra a prática de branch
protection que foi combinada — não assuma que toda mudança em `main` passou
por revisão.

## Licença

MIT. Ver seção de licenciamento consolidada no `README.md` da organização
ou pergunte ao mantenedor — a decisão e o racional estão registrados no
histórico de PRs deste repositório.

## O que NÃO existe neste repositório (não invente)

- Módulos Terraform reutilizáveis (isso vive em um repo `terraform-modules`
  separado, ainda não criado)
- Separação por ambiente
- IAM role de OIDC configurada
- Testes automatizados além de `terraform validate`/`tflint`/`trivy`
