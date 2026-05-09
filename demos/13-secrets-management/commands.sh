#!/usr/bin/env bash
# Extracted commands from 13-secrets-management.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

# 1. Create OIDC provider for GitHub
aws iam create-open-id-connect-provider \

# 2. Create role with trust policy bound to your repo
cat > trust.json <<EOF
# "Principal": { "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com" },  # contains <placeholder> — edit before running
aws iam create-role --role-name gha-deploy --assume-role-policy-document file://trust.json
aws iam attach-role-policy --role-name gha-deploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
EOF