# Configuração necessária para o CI/CD funcionar

O workflow em `.github/workflows/terraform.yml` depende de itens que precisam
ser configurados manualmente no GitHub (Settings → Secrets and variables →
Actions), pois envolvem dados da sua conta AWS que este PR não tem acesso.

## 1. Role de OIDC na AWS (sem chaves estáticas)

Crie uma IAM Role com trust policy para o GitHub OIDC provider
(`token.actions.githubusercontent.com`), restrita a este repositório, e
adicione o ARN como secret:

- Secret: `AWS_ROLE_ARN`

## 2. Variáveis do backend do Terraform (não sensíveis → "Variables", não "Secrets")

- `AWS_REGION`
- `TF_STATE_BUCKET`
- `TF_STATE_KEY` (ex: `infra-network/terraform.tfstate`)
- `TF_LOCK_TABLE`

## 3. Environments do GitHub (aprovação manual antes do apply)

O token usado para automatizar este PR não tem permissão para criar
Environments via API. Configure manualmente em Settings → Environments:

- `plan` — sem restrição, usado só pelo job de plan em PRs
- `production` — adicione você mesmo como *required reviewer*, para que o
  job de `apply` fique pausado aguardando aprovação manual antes de rodar

## 4. Variáveis de aplicação do Terraform

As variáveis do próprio módulo (`project_name`, `k8s_version`, etc. — ver
`terraform.tfvars.example`) ainda precisam ser passadas ao `terraform plan`
e `terraform apply` no workflow, seja via `-var` explícito, seja via um
`terraform.tfvars` versionado (sem segredos) ou `TF_VAR_*` nas variáveis
do ambiente do GitHub.
