# Check if Byparr is working properly in GitHub Actions
# This script fetches the latest workflow logs and checks for Byparr-related issues

$ErrorActionPreference = "Stop"

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     🔍 GITHUB ACTIONS BYPARR DIAGNOSTIC                    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check if gh CLI is installed
try {
    $ghVersion = gh --version 2>&1 | Select-Object -First 1
    Write-Host "✅ GitHub CLI: $ghVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ GitHub CLI not installed" -ForegroundColor Red
    Write-Host "Install: winget install --id GitHub.cli" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Get latest workflow run
Write-Host "📥 Fetching latest workflow run..." -ForegroundColor Yellow
try {
    $latestRun = gh run list --workflow="24/7 Recorder" --limit 1 --json databaseId,status,conclusion,createdAt,url | ConvertFrom-Json | Select-Object -First 1
    
    if (-not $latestRun) {
        Write-Host "❌ No workflow runs found" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "  Run #$($latestRun.databaseId)" -ForegroundColor White
    Write-Host "  Status: $($latestRun.status)" -ForegroundColor Gray
    Write-Host "  URL: $($latestRun.url)" -ForegroundColor Gray
    Write-Host ""
    
} catch {
    Write-Host "❌ Failed to fetch workflow runs: $_" -ForegroundColor Red
    exit 1
}

# Fetch logs
Write-Host "📜 Analyzing workflow logs..." -ForegroundColor Yellow
Write-Host ""

try {
    $logs = gh run view $latestRun.databaseId --log 2>&1 | Out-String
    
    # Check 1: Byparr startup
    Write-Host "[1/5] Checking Byparr startup..." -ForegroundColor Cyan
    if ($logs -match "Start Byparr") {
        Write-Host "  ✅ Byparr startup step found" -ForegroundColor Green
        
        if ($logs -match "Successfully pulled.*byparr") {
            Write-Host "  ✅ Byparr image pulled successfully" -ForegroundColor Green
        } elseif ($logs -match "Image is up to date.*byparr") {
            Write-Host "  ✅ Byparr image already up to date" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Byparr image pull status unclear" -ForegroundColor Yellow
        }
        
        if ($logs -match "byparr.*running") {
            Write-Host "  ✅ Byparr container started" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Byparr container status unclear" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ❌ Byparr startup step not found in logs" -ForegroundColor Red
    }
    Write-Host ""
    
    # Check 2: Byparr connectivity
    Write-Host "[2/5] Checking Byparr connectivity..." -ForegroundColor Cyan
    if ($logs -match "FLARESOLVERR_URL=http://byparr:8191/v1") {
        Write-Host "  ✅ Byparr URL configured: http://byparr:8191/v1" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Byparr URL not found in environment" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Check 3: Cloudflare blocks
    Write-Host "[3/5] Checking for Cloudflare blocks..." -ForegroundColor Cyan
    $cfBlockMatches = [regex]::Matches($logs, "blocked by Cloudflare|CF block|ErrCloudflareBlocked")
    if ($cfBlockMatches.Count -gt 0) {
        Write-Host "  ⚠️  Found $($cfBlockMatches.Count) Cloudflare block(s)" -ForegroundColor Yellow
        
        # Extract specific error messages
        $cfErrors = [regex]::Matches($logs, "channel was blocked by Cloudflare.*")
        if ($cfErrors.Count -gt 0) {
            Write-Host ""
            Write-Host "  Recent Cloudflare blocks:" -ForegroundColor White
            $cfErrors | Select-Object -First 5 | ForEach-Object {
                Write-Host "    • $($_.Value)" -ForegroundColor Gray
            }
        }
        
        # Check for exponential backoff
        $backoffMatches = [regex]::Matches($logs, "exponential backoff.*CF block #(\d+)")
        if ($backoffMatches.Count -gt 0) {
            $maxBlock = ($backoffMatches | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Maximum).Maximum
            Write-Host ""
            Write-Host "  ⚠️  Exponential backoff triggered (up to block #$maxBlock)" -ForegroundColor Yellow
            Write-Host "     This indicates persistent Cloudflare blocking" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ✅ No Cloudflare blocks detected" -ForegroundColor Green
    }
    Write-Host ""
    
    # Check 4: Byparr errors
    Write-Host "[4/5] Checking for Byparr errors..." -ForegroundColor Cyan
    $byparrErrors = [regex]::Matches($logs, "(?i)(byparr|flaresolverr).*(error|failed|timeout)")
    if ($byparrErrors.Count -gt 0) {
        Write-Host "  ⚠️  Found $($byparrErrors.Count) Byparr error(s)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Recent errors:" -ForegroundColor White
        $byparrErrors | Select-Object -First 5 | ForEach-Object {
            Write-Host "    • $($_.Value)" -ForegroundColor Gray
        }
        
        # Check for specific error patterns
        if ($logs -match "byparr timeout after 180s") {
            Write-Host ""
            Write-Host "  💡 Byparr timeout detected" -ForegroundColor Yellow
            Write-Host "     Cloudflare 2026 challenges are taking too long to solve" -ForegroundColor White
            Write-Host "     Solution: Use residential proxies" -ForegroundColor Gray
        }
        
        if ($logs -match "byparr challenge failed.*residential proxy") {
            Write-Host ""
            Write-Host "  💡 Challenge solver failed" -ForegroundColor Yellow
            Write-Host "     Datacenter IP is likely being blocked" -ForegroundColor White
            Write-Host "     Solution: Configure residential proxy in GitHub Secrets" -ForegroundColor Gray
        }
        
        if ($logs -match "unknown error.*NoneType") {
            Write-Host ""
            Write-Host "  💡 Byparr internal error" -ForegroundColor Yellow
            Write-Host "     This usually indicates insufficient memory or blocked IP" -ForegroundColor White
            Write-Host "     Solutions:" -ForegroundColor Gray
            Write-Host "       1. Increase Byparr memory limit in docker-compose.yml" -ForegroundColor Gray
            Write-Host "       2. Use residential proxy" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ✅ No Byparr errors detected" -ForegroundColor Green
    }
    Write-Host ""
    
    # Check 5: Recording status
    Write-Host "[5/5] Checking recording status..." -ForegroundColor Cyan
    $recordingMatches = [regex]::Matches($logs, "starting to record|recording started|stream ended")
    if ($recordingMatches.Count -gt 0) {
        Write-Host "  ✅ Found $($recordingMatches.Count) recording event(s)" -ForegroundColor Green
        
        # Check for successful recordings
        $successMatches = [regex]::Matches($logs, "recording completed|finalized")
        if ($successMatches.Count -gt 0) {
            Write-Host "  ✅ $($successMatches.Count) recording(s) completed successfully" -ForegroundColor Green
        }
    } else {
        Write-Host "  ⚠️  No recording events found" -ForegroundColor Yellow
        Write-Host "     This might indicate channels are offline or blocked" -ForegroundColor Gray
    }
    Write-Host ""
    
} catch {
    Write-Host "❌ Failed to analyze logs: $_" -ForegroundColor Red
    exit 1
}

# Summary and recommendations
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                  📊 DIAGNOSIS SUMMARY                      ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Determine overall status
$cfBlockCount = ([regex]::Matches($logs, "blocked by Cloudflare")).Count
$byparrErrorCount = ([regex]::Matches($logs, "(?i)(byparr|flaresolverr).*(error|failed|timeout)")).Count

if ($cfBlockCount -eq 0 -and $byparrErrorCount -eq 0) {
    Write-Host "✅ Status: HEALTHY" -ForegroundColor Green
    Write-Host "   Byparr is working properly, no Cloudflare blocks detected" -ForegroundColor White
} elseif ($cfBlockCount -gt 0 -and $cfBlockCount -lt 5) {
    Write-Host "⚠️  Status: DEGRADED" -ForegroundColor Yellow
    Write-Host "   Some Cloudflare blocks detected, but system is recovering" -ForegroundColor White
} else {
    Write-Host "❌ Status: BLOCKED" -ForegroundColor Red
    Write-Host "   Persistent Cloudflare blocking detected" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 Recommended Actions:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Configure Residential Proxy (CRITICAL)" -ForegroundColor White
    Write-Host "   Add these secrets to your GitHub repository:" -ForegroundColor Gray
    Write-Host "   • PROXY_URL (e.g., http://proxy.example.com:8080)" -ForegroundColor Gray
    Write-Host "   • PROXY_USERNAME" -ForegroundColor Gray
    Write-Host "   • PROXY_PASSWORD" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   Recommended providers:" -ForegroundColor Gray
    Write-Host "   • BrightData (https://brightdata.com)" -ForegroundColor Gray
    Write-Host "   • Smartproxy (https://smartproxy.com)" -ForegroundColor Gray
    Write-Host "   • Oxylabs (https://oxylabs.io)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Increase Byparr Memory" -ForegroundColor White
    Write-Host "   Edit docker-compose.yml:" -ForegroundColor Gray
    Write-Host "   Change memory limit from 1.5G to 2G" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Use Manual Cookie Extraction (Alternative)" -ForegroundColor White
    Write-Host "   Extract cookies from your browser and pass via --cookies flag" -ForegroundColor Gray
    Write-Host "   See: docs/CLOUDFLARE_BYPASS_2026.md" -ForegroundColor Gray
}

Write-Host ""
Write-Host "View full logs: $($latestRun.url)" -ForegroundColor Cyan
Write-Host ""
