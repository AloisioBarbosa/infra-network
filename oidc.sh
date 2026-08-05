#!/bin/bash

# ==========================================
# Variáveis de Configuração (Edite se necessário)
# ==========================================
ACCOUNT_ID="920278691034"
GITHUB_ORG="AloisioBarbosa"
GITHUB_REPO="infra-network"
ROLE_NAME="GitHubActionsOIDCInfraNetworkRole"
POLICY_NAME="TerraformNetworkEC2Policy"
OIDC_URL="https://token.actions.githubusercontent.com"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

echo "🚀 Iniciando provisionamento do OIDC e Role IAM para GitHub Actions..."

# ==========================================
# 1. Criar o Identity Provider (OIDC)
# ==========================================
echo "🛠️  Verificando/Criando o OIDC Provider..."
# As thumbprints padrão do GitHub Actions
aws iam create-open-id-connect-provider \
  --url "${OIDC_URL}" \
  --client-id-list "sts.amazonaws.com" \
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" "1c58a3a8518e8759bf075b76b750d4f2df264fcd" \
  2>/dev/null || echo "⚠️  O provedor OIDC já existe (Isso é normal, continuando...)"

# ==========================================
# 2. Criar o arquivo da Trust Policy (OIDC)
# ==========================================
echo "📄 Gerando o arquivo trust-policy.json..."
cat <<EOF > trust-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "${OIDC_ARN}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
                }
            }
        }
    ]
}
EOF

# ==========================================
# 3. Criar a Role no IAM
# ==========================================
echo "🔐 Criando a Role ${ROLE_NAME}..."
aws iam create-role \
  --role-name "${ROLE_NAME}" \
  --assume-role-policy-document file://trust-policy.json \
  2>/dev/null || echo "⚠️  A Role já existe. Se precisar atualizar a Trust Policy, use 'aws iam update-assume-role-policy'."

# ==========================================
# 4. Criar o arquivo da Policy de Permissões (Terraform EC2/Rede)
# ==========================================
echo "📄 Gerando o arquivo permissions-policy.json..."
cat <<EOF > permissions-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "NetworkingManageEC2",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateVpc",
                "ec2:DeleteVpc",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcAttribute",
                "ec2:ModifyVpcAttribute",
                "ec2:CreateSubnet",
                "ec2:DeleteSubnet",
                "ec2:DescribeSubnets",
                "ec2:ModifySubnetAttribute",
                "ec2:CreateInternetGateway",
                "ec2:DeleteInternetGateway",
                "ec2:AttachInternetGateway",
                "ec2:DetachInternetGateway",
                "ec2:DescribeInternetGateways",
                "ec2:AllocateAddress",
                "ec2:ReleaseAddress",
                "ec2:DescribeAddresses",
                "ec2:DescribeAddressesAttribute",
                "ec2:CreateNatGateway",
                "ec2:DeleteNatGateway",
                "ec2:DescribeNatGateways",
                "ec2:CreateRouteTable",
                "ec2:DeleteRouteTable",
                "ec2:DescribeRouteTables",
                "ec2:CreateRoute",
                "ec2:DeleteRoute",
                "ec2:AssociateRouteTable",
                "ec2:DisassociateRouteTable",
                "ec2:ReplaceRouteTableAssociation",
                "ec2:CreateSecurityGroup",
                "ec2:DeleteSecurityGroup",
                "ec2:DescribeSecurityGroups",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeAccountAttributes",
                "ec2:CreateTags",
                "ec2:DeleteTags",
                "ec2:DescribeTags"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# ==========================================
# 5. Criar a Policy no IAM
# ==========================================
echo "📋 Criando a Policy ${POLICY_NAME}..."
aws iam create-policy \
  --policy-name "${POLICY_NAME}" \
  --policy-document file://permissions-policy.json \
  2>/dev/null || echo "⚠️  A Policy já existe."

# ==========================================
# 6. Anexar a Policy à Role
# ==========================================
echo "🔗 Anexando a Policy ${POLICY_NAME} à Role ${ROLE_NAME}..."
aws iam attach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

# ==========================================
# 7. Limpeza e Finalização
# ==========================================
echo "🧹 Limpando arquivos temporários..."
rm trust-policy.json permissions-policy.json

echo "✅ Concluído! A Role ${ROLE_NAME} está configurada e pronta para o Terraform."