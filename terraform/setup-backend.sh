#!/bin/bash

# Script to set up Azure Blob Storage backend for Terraform remote state
# This script creates the necessary Azure resources for storing Terraform state

set -e

echo "🔧 Setting up Azure Blob Storage backend for Terraform remote state..."

# Variables
RESOURCE_GROUP_NAME="tfstate-rg"
STORAGE_ACCOUNT_NAME="tfstate$(openssl rand -hex 4)"
CONTAINER_NAME="tfstate"
LOCATION="East US"

echo "📋 Configuration:"
echo "   Resource Group: $RESOURCE_GROUP_NAME"
echo "   Storage Account: $STORAGE_ACCOUNT_NAME"
echo "   Container: $CONTAINER_NAME"
echo "   Location: $LOCATION"
echo ""

# Check if Azure CLI is installed and logged in
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first:"
    echo "   https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo "❌ Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

echo "✅ Azure CLI is installed and authenticated"

# Get current subscription info
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
SUBSCRIPTION_NAME=$(az account show --query name --output tsv)

echo "🔍 Using Azure subscription:"
echo "   ID: $SUBSCRIPTION_ID"
echo "   Name: $SUBSCRIPTION_NAME"
echo ""

# Create resource group for Terraform state
echo "📂 Creating resource group for Terraform state..."
az group create \
    --name $RESOURCE_GROUP_NAME \
    --location "$LOCATION" \
    --tags "purpose=terraform-state" "project=LiveEventOps" "managed_by=script"

echo "✅ Resource group '$RESOURCE_GROUP_NAME' created"

# Create storage account for Terraform state
echo "💾 Creating storage account for Terraform state..."
az storage account create \
    --name $STORAGE_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --access-tier Hot \
    --tags "purpose=terraform-state" "project=LiveEventOps" "managed_by=script"

echo "✅ Storage account '$STORAGE_ACCOUNT_NAME' created"

# Get storage account key
echo "🔑 Retrieving storage account key..."
STORAGE_KEY=$(az storage account keys list \
    --resource-group $RESOURCE_GROUP_NAME \
    --account-name $STORAGE_ACCOUNT_NAME \
    --query '[0].value' \
    --output tsv)

# Create blob container for Terraform state
echo "📦 Creating blob container for Terraform state..."
az storage container create \
    --name $CONTAINER_NAME \
    --account-name $STORAGE_ACCOUNT_NAME \
    --account-key $STORAGE_KEY \
    --public-access off

echo "✅ Blob container '$CONTAINER_NAME' created"

# Create backend configuration file
echo "📝 Creating backend configuration file..."
cat > backend-config.tfvars << EOF
resource_group_name  = "$RESOURCE_GROUP_NAME"
storage_account_name = "$STORAGE_ACCOUNT_NAME"
container_name      = "$CONTAINER_NAME"
key                 = "liveeventops.terraform.tfstate"
EOF

echo "✅ Backend configuration saved to 'backend-config.tfvars'"

# Update main.tf with correct storage account name
echo "🔄 Updating main.tf with backend configuration..."
sed -i.bak "s/tfstate\${random_string.storage_suffix.result}/$STORAGE_ACCOUNT_NAME/g" main.tf

echo "✅ Updated main.tf with storage account name"

# Display next steps
echo ""
echo "🎉 Azure Blob Storage backend setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Copy terraform.tfvars.example to terraform.tfvars"
echo "2. Update terraform.tfvars with your SSH public key and other values"
echo "3. Initialize Terraform with the backend:"
echo "   terraform init -backend-config=backend-config.tfvars"
echo "4. Plan and apply your infrastructure:"
echo "   terraform plan"
echo "   terraform apply"
echo ""
echo "🔐 Backend Configuration Details:"
echo "   Resource Group: $RESOURCE_GROUP_NAME"
echo "   Storage Account: $STORAGE_ACCOUNT_NAME"
echo "   Container: $CONTAINER_NAME"
echo "   Subscription: $SUBSCRIPTION_ID"
echo ""
echo "💡 Important: Keep the backend-config.tfvars file secure as it contains your backend configuration."
