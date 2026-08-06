# Configuração necessária para o CI/CD funcionar

Status verificado em 04/08/2026. Atualize este arquivo sempre que resolver
um item — ele é a fonte da verdade sobre o que falta, não o workflow em si.

## 1. Autenticação AWS — ⚠️ mudou de OIDC para chaves estáticas

Depois de erros persistentes com `role-to-assume` (OIDC), o workflow passou
a usar `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (secrets). O bloco
`role-to-assume` original ficou **comentado** no `terraform.yml`, não
removido — se for debugar, confirme qual dos dois métodos está de fato
ativo antes de mexer.

Trade-off que vale registrar: chaves estáticas não expiram sozinhas e
ficam nos secrets do GitHub indefinidamente — diferente do OIDC, que emite
credenciais de minutos por execução. Funcional, mas é uma troca de
segurança consciente, não neutra.

## 2. Permissões da identidade AWS — ⚠️ incompleta

A policy atual cobre EC2 (rede), EKS, IAM (roles do cluster/nodes/api
gateway), SSM Parameter Store e KMS — mas **não cobre o backend do
Terraform** (bucket S3 do state). Isso já causou um erro real: 403 no
`terraform init` (`HeadObject` em `orange-ks8-logs`), porque sem
`s3:ListBucket` a AWS devolve 403 em vez de 404 mesmo pra um objeto que
ainda não existe.

**Não precisa de permissão de DynamoDB** — o lock migrou pra
`use_lockfile` (S3 native locking), então o lock file fica no próprio
bucket do state. Isso também exige `required_version >= 1.11.0` no
Terraform (já corrigido em `versions.tf` e no `TF_VERSION` do workflow —
antes estava em `1.7.5`, que não conhece esse argumento de backend).

Statements que faltam adicionar à policy:

```json
{
  "Sid": "TerraformStateBucket",
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
  "Resource": "arn:aws:s3:::orange-ks8-logs/*"
},
{
  "Sid": "TerraformStateBucketList",
  "Effect": "Allow",
  "Action": "s3:ListBucket",
  "Resource": "arn:aws:s3:::orange-ks8-logs"
}
```

Confirme se isso já foi anexado antes de assumir que o backend funciona.
Também vale confirmar se o bucket `orange-ks8-logs` tem **versionamento
habilitado** — é recomendado pela própria HashiCorp para o `use_lockfile`
funcionar de forma segura (permite recuperar o state em caso de exclusão
acidental do lock file).

## 3. Permissão para API Gateway Account — ❌ necessária

O recurso `aws_api_gateway_account` em `api_gateway_setup.tf` requer que o IAM user do Terraform tenha `apigateway:UPDATE` no resource `/account`:

```json
{
  "Sid": "ApiGatewayAccount",
  "Effect": "Allow",
  "Action": "apigateway:UPDATE",
  "Resource": "arn:aws:apigateway:us-east-1::/account"
}
```

Sem isso o apply falha com `AccessDeniedException` no `aws_api_gateway_account.main`.

## 4. Variáveis do backend do Terraform — ✅ feito

`AWS_REGION`, `TF_STATE_BUCKET`, `TF_STATE_KEY` —
configuradas como repository variables. (Nota: `TF_LOCK_TABLE` foi removido — o lock agora usa `use_lockfile` no S3.)

## 5. Environments do GitHub — ⚠️ parcialmente feito

- `plan` — existe
- `production` — existe, **mas sem required reviewer configurado ainda**.
  Sem isso o `apply` roda sozinho no merge, sem pausar pra aprovação manual
- Sobrou um environment `AWS_REGION` (engano de uma tentativa anterior) —
  não é usado por nenhum job, pode apagar

## 6. Variáveis de aplicação do Terraform — ⚠️ decidido, confirmar criação

Valores decididos para este repositório:

| Nome | Valor |
|---|---|
| `TF_VAR_project_name` | `infra-network` |
| `TF_VAR_region` | `us-east-1` |
| `TF_VAR_environment` | `dev` |

**Importante — contrato entre repositórios**: `project_name` vira o
prefixo dos paths do SSM que o `infra-cluster` consome. O `infra-cluster`
precisa usar exatamente `TF_VAR_project_name = infra-network` também — não
o nome do próprio repositório dele. Ver `AGENTS.md`, seção "Contrato entre
repositórios", para a lista completa dos paths.

Configure como repository variables (mesmo lugar de `AWS_REGION` etc.), nos
dois repositórios. Ainda não confirmamos via API se já foram criadas (o
token usado não tem permissão de leitura em Variables).
