#!/bin/bash

# Setup GitHub Secrets for CI/CD
# This script helps you configure the required secrets for GitHub Actions

set -e

echo "🔐 GitHub Secrets Setup for CI/CD"
echo "=================================="
echo ""

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed."
    echo ""
    echo "Install it from: https://cli.github.com/"
    echo ""
    echo "Or use manual setup:"
    echo "1. Go to your GitHub repository"
    echo "2. Navigate to Settings > Secrets and variables > Actions"
    echo "3. Click 'New repository secret'"
    echo "4. Add the following secrets:"
    echo ""
    echo "   Secret Name: EC2_SSH_KEY"
    echo "   Secret Value: [Content of your aws-secrets/aws-key.pem file]"
    echo ""
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ You are not authenticated with GitHub CLI."
    echo "Run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI is installed and authenticated"
echo ""

# Check if SSH key exists
SSH_KEY_PATH="aws-secrets/aws-key.pem"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "❌ SSH key not found at: $SSH_KEY_PATH"
    echo ""
    echo "Please ensure your EC2 SSH key is located at: $SSH_KEY_PATH"
    exit 1
fi

echo "✅ SSH key found at: $SSH_KEY_PATH"
echo ""

# Get repository information
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "📦 Repository: $REPO"
echo ""

# Confirm before proceeding
read -p "Do you want to add EC2_SSH_KEY secret to this repository? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled"
    exit 1
fi

# Add the SSH key as a secret
echo "🔑 Adding EC2_SSH_KEY secret..."
gh secret set EC2_SSH_KEY < "$SSH_KEY_PATH"

if [ $? -eq 0 ]; then
    echo "✅ EC2_SSH_KEY secret added successfully!"
    echo ""
    echo "🎉 GitHub Actions CI/CD is now configured!"
    echo ""
    echo "Next steps:"
    echo "1. Push your code to the main/master branch"
    echo "2. GitHub Actions will automatically deploy to EC2"
    echo "3. Monitor the deployment at: https://github.com/$REPO/actions"
    echo ""
    echo "Manual trigger:"
    echo "  gh workflow run deploy-to-ec2.yml"
    echo ""
else
    echo "❌ Failed to add secret"
    exit 1
fi
