#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="5e683e0f-b00c-48d6-9769-5aaf598de8f1"
RESOURCE_GROUP="msaidiRG"
ACR_NAME="acrmsaidigitops"
APP_NAME="msaidi-tp-gitops-ci"
GITHUB_REPO="ororck/tp-gitops-app"
GITHUB_BRANCH="main"
CREDENTIAL_NAME="github-main"

az account set --subscription "$SUBSCRIPTION_ID"
TENANT_ID=$(az account show --query tenantId -o tsv)

APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [ -z "$APP_ID" ]; then
  APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
fi

if ! az ad sp show --id "$APP_ID" >/dev/null 2>&1; then
  az ad sp create --id "$APP_ID" >/dev/null
fi

EXISTING=$(az ad app federated-credential list --id "$APP_ID" --query "[?name=='$CREDENTIAL_NAME'].name" -o tsv)
if [ -z "$EXISTING" ]; then
  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"$CREDENTIAL_NAME\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_REPO:ref:refs/heads/$GITHUB_BRANCH\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" >/dev/null
fi

ACR_ID=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)
HAS_ROLE=$(az role assignment list --assignee "$SP_OBJECT_ID" --scope "$ACR_ID" --role AcrPush --query "length(@)" -o tsv)
if [ "$HAS_ROLE" = "0" ]; then
  az role assignment create --assignee-object-id "$SP_OBJECT_ID" --assignee-principal-type ServicePrincipal \
    --role AcrPush --scope "$ACR_ID" >/dev/null
fi

echo "Set these as GitHub Actions variables on $GITHUB_REPO"
echo "AZURE_CLIENT_ID=$APP_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
