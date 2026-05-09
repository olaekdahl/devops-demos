#!/usr/bin/env bash
# Extracted commands from 30-jfrog-artifactory.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

INITIALS=oe                                 # your initials
ARTIFACTORY_URL=mycompany.jfrog.io
REPO=devops-docker-local

# 1. Build local
docker build -t devops-app:1.0.0 .

# 2. Login to Artifactory
echo "$ARTIFACTORY_TOKEN" | docker login "$ARTIFACTORY_URL" -u "$ARTIFACTORY_USER" --password-stdin

# 3. Tag & push
IMAGE="$ARTIFACTORY_URL/$REPO/${INITIALS}-devops:1.0.0"
docker tag devops-app:1.0.0 "$IMAGE"
docker push "$IMAGE"

# 4. Verify via the JFrog UI (or REST):
curl -u "$ARTIFACTORY_USER:$ARTIFACTORY_TOKEN" \

# 5. Create K8s pull secret
ARTIFACTORY_USER="$ARTIFACTORY_USER" ARTIFACTORY_TOKEN="$ARTIFACTORY_TOKEN" \
  ARTIFACTORY_URL="$ARTIFACTORY_URL" bash pull-secret.sh

# 6. Deploy
sed -e "s|__ARTIFACTORY_URL__|$ARTIFACTORY_URL|" \
    deployment.yaml | kubectl apply -f -

kubectl rollout status deployment/devops-app
kubectl get svc devops-app-svc

# --- next block ---

INITIALS=oe                                 # your initials
ARTIFACTORY_URL=mycompany.jfrog.io
REPO=devops-docker-local

# 1. Build local
docker build -t devops-app:1.0.0 .

# 2. Login to Artifactory
echo "$ARTIFACTORY_TOKEN" | docker login "$ARTIFACTORY_URL" -u "$ARTIFACTORY_USER" --password-stdin

# 3. Tag & push
IMAGE="$ARTIFACTORY_URL/$REPO/${INITIALS}-devops:1.0.0"
docker tag devops-app:1.0.0 "$IMAGE"
docker push "$IMAGE"

# 4. Verify via the JFrog UI (or REST):
curl -u "$ARTIFACTORY_USER:$ARTIFACTORY_TOKEN" \

# 5. Create K8s pull secret
ARTIFACTORY_USER="$ARTIFACTORY_USER" ARTIFACTORY_TOKEN="$ARTIFACTORY_TOKEN" \
  ARTIFACTORY_URL="$ARTIFACTORY_URL" bash pull-secret.sh

# 6. Deploy
sed -e "s|__ARTIFACTORY_URL__|$ARTIFACTORY_URL|" \
    deployment.yaml | kubectl apply -f -

kubectl rollout status deployment/devops-app
kubectl get svc devops-app-svc