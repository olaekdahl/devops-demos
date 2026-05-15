#!/usr/bin/env bash
# Provision an AWS Secrets Manager secret holding JFrog Artifactory credentials,
# plus the IAM policy + IRSA service account that External Secrets Operator
# (ESO) needs to read it. Idempotent: safe to re-run.
set -euo pipefail

# ---- Inputs ----------------------------------------------------------------
CLUSTER=${CLUSTER:-devops-cluster}
REGION=${REGION:-us-west-2}
SECRET_NAME=${SECRET_NAME:-devops/jfrog-pull-secret}
ESO_NAMESPACE=${ESO_NAMESPACE:-external-secrets}
ESO_SERVICE_ACCOUNT=${ESO_SERVICE_ACCOUNT:-external-secrets-sa}

ARTIFACTORY_URL=${ARTIFACTORY_URL:?missing ARTIFACTORY_URL (e.g. mycompany.jfrog.io)}
ARTIFACTORY_USER=${ARTIFACTORY_USER:?missing ARTIFACTORY_USER}
ARTIFACTORY_TOKEN=${ARTIFACTORY_TOKEN:?missing ARTIFACTORY_TOKEN}
ARTIFACTORY_EMAIL=${ARTIFACTORY_EMAIL:-demo@example.com}

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# ---- 1. Build the secret payload ------------------------------------------
# Stored as JSON so ExternalSecret can template a dockerconfigjson from it.
PAYLOAD=$(jq -n \
  --arg url   "$ARTIFACTORY_URL" \
  --arg user  "$ARTIFACTORY_USER" \
  --arg pass  "$ARTIFACTORY_TOKEN" \
  --arg email "$ARTIFACTORY_EMAIL" \
  '{server: $url, username: $user, password: $pass, email: $email}')

# ---- 2. Create or update the AWS Secrets Manager secret -------------------
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
  aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" --region "$REGION" \
    --secret-string "$PAYLOAD" >/dev/null
  echo "Updated AWS Secrets Manager secret: $SECRET_NAME"
else
  aws secretsmanager create-secret \
    --name "$SECRET_NAME" --region "$REGION" \
    --description "JFrog Artifactory pull credentials for $CLUSTER" \
    --secret-string "$PAYLOAD" >/dev/null
  echo "Created AWS Secrets Manager secret: $SECRET_NAME"
fi

SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id "$SECRET_NAME" --region "$REGION" --query ARN --output text)

# ---- 3. IAM policy granting read access to that secret --------------------
POLICY_NAME=DevOpsExternalSecretsReadJfrog
POLICY_ARN=arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}
POLICY_DOC=$(jq -n --arg arn "$SECRET_ARN" '{
  Version: "2012-10-17",
  Statement: [{
    Effect: "Allow",
    Action: ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
    Resource: $arn
  }]
}')

if aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
  aws iam create-policy-version \
    --policy-arn "$POLICY_ARN" \
    --policy-document "$POLICY_DOC" \
    --set-as-default >/dev/null
  echo "Updated IAM policy: $POLICY_ARN"
else
  aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOC" >/dev/null
  echo "Created IAM policy: $POLICY_ARN"
fi

# ---- 4. IRSA service account for External Secrets Operator ----------------
eksctl create iamserviceaccount \
  --cluster="$CLUSTER" --region="$REGION" \
  --namespace="$ESO_NAMESPACE" --name="$ESO_SERVICE_ACCOUNT" \
  --role-name=DevOpsExternalSecretsRole \
  --attach-policy-arn="$POLICY_ARN" \
  --override-existing-serviceaccounts \
  --approve

cat <<EOF

Done.

  AWS secret ARN : $SECRET_ARN
  IAM policy ARN : $POLICY_ARN
  IRSA SA        : $ESO_NAMESPACE/$ESO_SERVICE_ACCOUNT (role DevOpsExternalSecretsRole)

Next steps:
  1. bash install-external-secrets.sh
  2. kubectl apply -f secretstore.yaml -f externalsecret.yaml
  3. kubectl apply -f deployment.yaml
EOF
