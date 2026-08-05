# Configuração necessária para o CI/CD funcionar

Status verificado em 04/08/2026, direto na conta GitHub (API), não por
suposição. Atualize este arquivo sempre que resolver um item.

## 1. Role de OIDC na AWS — ❌ pendente

O job `apply` falha no step "Configurar credenciais AWS via OIDC"
(confirmado na execução #29 em `main`). Isso indica que a IAM Role ainda
não existe, ou o secret abaixo não foi criado, ou a trust policy da role
não está apontando pro repositório certo.

Crie uma IAM Role com trust policy para o GitHub OIDC provider
(`token.actions.githubusercontent.com`), restrita a este repositório, e
adicione o ARN como secret:

- Secret: `AWS_ROLE_ARN`

Não temos como confirmar via API se o secret existe (o token usado só tem
permissão de leitura em "Variables", não em "Secrets") — só o comportamento
do workflow real confirma isso.

## 2. Variáveis do backend do Terraform — ✅ feito

Confirmado configurado corretamente em Settings → Secrets and variables →
Actions → Variables:

- `AWS_REGION`
- `TF_STATE_BUCKET`
- `TF_STATE_KEY`
- `TF_LOCK_TABLE`

## 3. Environments do GitHub — ⚠️ parcialmente feito

- `plan` — existe
- `production` — existe, **mas sem required reviewer configurado ainda**.
  Adicione você mesmo como required reviewer em Settings → Environments →
  production, senão o `apply` roda sozinho no merge, sem pausar pra
  aprovação manual (que era o objetivo original)
- Sobrou um environment chamado `AWS_REGION`, criado por engano numa
  tentativa anterior — não é referenciado por nenhum job, pode apagar

## 4. Variáveis de aplicação do Terraform — ❌ pendente

Os steps de `terraform plan`/`terraform apply` no workflow **não passam
nenhuma variável** (`-var`, `-var-file`, nem `TF_VAR_*`). Como
`project_name`, `region` e `environment` são obrigatórias e sem default,
isso deve falhar com "No value for required variable" assim que o plan
rodar de verdade (ainda não vimos esse erro só porque o pipeline está
parando antes, na autenticação AWS). Resolva isso antes de tentar validar
o restante:

- Opção mais simples: `TF_VAR_project_name`, `TF_VAR_region`,
  `TF_VAR_environment` como variáveis do environment `plan`/`production`
  no GitHub, lidas automaticamente pelo Terraform
- Alternativa: um `terraform.tfvars` versionado no repo (sem segredos)
