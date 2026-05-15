# Setup GitHub Secrets for CI/CD (PowerShell)
# This script helps you configure the required secrets for GitHub Actions

$ErrorActionPreference = "Stop"

Write-Host "🔐 GitHub Secrets Setup for CI/CD" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Check if GitHub CLI is installed
$ghInstalled = Get-Command gh -ErrorAction SilentlyContinue

if (-not $ghInstalled) {
    Write-Host "❌ GitHub CLI (gh) is not installed." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install it from: https://cli.github.com/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or use manual setup:" -ForegroundColor Yellow
    Write-Host "1. Go to your GitHub repository"
    Write-Host "2. Navigate to Settings > Secrets and variables > Actions"
    Write-Host "3. Click 'New repository secret'"
    Write-Host "4. Add the following secrets:"
    Write-Host ""
    Write-Host "   Secret Name: EC2_SSH_KEY" -ForegroundColor Green
    Write-Host "   Secret Value: [Content of your aws-secrets/aws-key.pem file]" -ForegroundColor Green
    Write-Host ""
    exit 1
}

# Check if user is authenticated
try {
    gh auth status 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Not authenticated"
    }
} catch {
    Write-Host "❌ You are not authenticated with GitHub CLI." -ForegroundColor Red
    Write-Host "Run: gh auth login" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ GitHub CLI is installed and authenticated" -ForegroundColor Green
Write-Host ""

# Check if SSH key exists
$sshKeyPath = "aws-secrets/aws-key.pem"
if (-not (Test-Path $sshKeyPath)) {
    Write-Host "❌ SSH key not found at: $sshKeyPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure your EC2 SSH key is located at: $sshKeyPath" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ SSH key found at: $sshKeyPath" -ForegroundColor Green
Write-Host ""

# Get repository information
$repo = gh repo view --json nameWithOwner -q .nameWithOwner
Write-Host "📦 Repository: $repo" -ForegroundColor Cyan
Write-Host ""

# Confirm before proceeding
$confirmation = Read-Host "Do you want to add EC2_SSH_KEY secret to this repository? (y/n)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "❌ Cancelled" -ForegroundColor Red
    exit 1
}

# Add the SSH key as a secret
Write-Host "🔑 Adding EC2_SSH_KEY secret..." -ForegroundColor Cyan
Get-Content $sshKeyPath | gh secret set EC2_SSH_KEY

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ EC2_SSH_KEY secret added successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎉 GitHub Actions CI/CD is now configured!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Push your code to the main/master branch"
    Write-Host "2. GitHub Actions will automatically deploy to EC2"
    Write-Host "3. Monitor the deployment at: https://github.com/$repo/actions"
    Write-Host ""
    Write-Host "Manual trigger:" -ForegroundColor Yellow
    Write-Host "  gh workflow run deploy-to-ec2.yml"
    Write-Host ""
} else {
    Write-Host "❌ Failed to add secret" -ForegroundColor Red
    exit 1
}
