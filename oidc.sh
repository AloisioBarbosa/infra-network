#!/bin/bash
set -euo pipefail

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
REPO_OWNER="AloisioBarbosa"
ROLE_NAME="GitHubActionsOIDCInfraNetwork"

OIDC_PROVIDER_ARN="arn:aws:iam::$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"

echo "=== Checando OIDC provider ==="
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" >/dev/null 2>&1; then
  echo "OIDC provider já existe: $OIDC_PROVIDER_ARN"
else
  echo "Criando OIDC provider..."
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
fi

echo "=== Criando trust policy ==="
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_PROVIDER_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:$REPO_OWNER/*"
        }
      }
    }
  ]
}
EOF

echo "=== Checando role $ROLE_NAME ==="
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "Role já existe: $ROLE_NAME"
else
  echo "Criando role $ROLE_NAME..."
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file://trust-policy.json
fi

echo "=== Criando policy inline ==="
cat > permissions-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "ssm:PutParameter",
        "ssm:GetParameter",
        "ssm:DeleteParameter",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
EOF

echo "=== Anexando policy à role ==="
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name InfraNetworkPermissions \
  --policy-document file://permissions-policy.json

echo "=== Role criada/atualizada com sucesso ==="
aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text

echo "=== Policies atreladas à role ==="
aws iam list-role-policies --role-name "$ROLE_NAME" --output table
