# Diagnose Byparr (FlareSolverr) Setup and Cloudflare Bypass
# This script checks if Byparr is running properly and can bypass Cloudflare

$ErrorActionPreference = "Stop"

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           🔍 BYPARR DIAGNOSTIC TOOL                        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if Docker is running
Write-Host "[1/6] Checking Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version 2>&1
    Write-Host "  ✅ Docker is installed: $dockerVersion" -ForegroundColor Green
    
    $dockerRunning = docker ps 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Docker daemon is running" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Docker daemon is not running" -ForegroundColor Red
        Write-Host "  Start Docker Desktop and try again" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "  ❌ Docker is not installed or not in PATH" -ForegroundColor Red
    Write-Host "  Install Docker Desktop from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Test 2: Check if docker-compose.yml exists
Write-Host "[2/6] Checking docker-compose.yml..." -ForegroundColor Yellow
if (Test-Path "docker-compose.yml") {
    Write-Host "  ✅ docker-compose.yml found" -ForegroundColor Green
    
    # Check if Byparr service is defined
    $composeContent = Get-Content "docker-compose.yml" -Raw
    if ($composeContent -match "byparr:") {
        Write-Host "  ✅ Byparr service is defined" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Byparr service not found in docker-compose.yml" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ❌ docker-compose.yml not found" -ForegroundColor Red
    Write-Host "  Make sure you're in the project root directory" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Test 3: Check if Byparr containers are running
Write-Host "[3/6] Checking Byparr containers..." -ForegroundColor Yellow
$byparrContainers = docker ps --filter "name=byparr" --format "{{.Names}}" 2>&1
if ($byparrContainers) {
    $containerCount = ($byparrContainers | Measure-Object -Line).Lines
    Write-Host "  ✅ Found $containerCount Byparr container(s) running:" -ForegroundColor Green
    foreach ($container in $byparrContainers) {
        $status = docker inspect $container --format "{{.State.Status}}" 2>&1
        $uptime = docker inspect $container --format "{{.State.StartedAt}}" 2>&1
        Write-Host "     • $container - Status: $status" -ForegroundColor Gray
    }
} else {
    Write-Host "  ⚠️  No Byparr containers running" -ForegroundColor Yellow
    Write-Host "  Starting Byparr with docker-compose..." -ForegroundColor Cyan
    
    try {
        docker-compose up -d byparr byparr-lb 2>&1 | Out-Null
        Write-Host "  ✅ Byparr started" -ForegroundColor Green
        Write-Host "  ⏳ Waiting 10 seconds for initialization..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    } catch {
        Write-Host "  ❌ Failed to start Byparr: $_" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# Test 4: Check if Byparr is accessible on port 8191
Write-Host "[4/6] Testing Byparr API endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:8191/v1" -Method Get -TimeoutSec 10 -ErrorAction Stop
    
    if ($response) {
        Write-Host "  ✅ Byparr API is accessible on http://localhost:8191/v1" -ForegroundColor Green
        
        # Check version info
        if ($response.version) {
            Write-Host "     Version: $($response.version)" -ForegroundColor Gray
        }
        if ($response.userAgent) {
            Write-Host "     User-Agent: $($response.userAgent)" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "  ❌ Cannot connect to Byparr API: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "  1. Check if port 8191 is already in use: netstat -ano | findstr :8191" -ForegroundColor Gray
    Write-Host "  2. Check Byparr logs: docker logs byparr-lb" -ForegroundColor Gray
    Write-Host "  3. Restart Byparr: docker-compose restart byparr byparr-lb" -ForegroundColor Gray
    exit 1
}
Write-Host ""

# Test 5: Test Cloudflare bypass with a real request
Write-Host "[5/6] Testing Cloudflare bypass (this may take 30-180 seconds)..." -ForegroundColor Yellow
Write-Host "  ⏳ Sending test request to Chaturbate..." -ForegroundColor Gray

$testUrl = "https://chaturbate.com/"
$requestBody = @{
    cmd = "request.get"
    url = $testUrl
    maxTimeout = 180000  # 180 seconds
} | ConvertTo-Json

try {
    $startTime = Get-Date
    $response = Invoke-RestMethod -Uri "http://localhost:8191/v1" -Method Post -Body $requestBody -ContentType "application/json" -TimeoutSec 200 -ErrorAction Stop
    $duration = ((Get-Date) - $startTime).TotalSeconds
    
    if ($response.status -eq "ok") {
        Write-Host "  ✅ Cloudflare bypass SUCCESSFUL (took $([math]::Round($duration, 1))s)" -ForegroundColor Green
        
        # Check if we got cookies
        if ($response.solution.cookies) {
            $cookieCount = ($response.solution.cookies | Measure-Object).Count
            Write-Host "     Cookies received: $cookieCount" -ForegroundColor Gray
            
            # Check for cf_clearance cookie (critical for Cloudflare bypass)
            $cfClearance = $response.solution.cookies | Where-Object { $_.name -eq "cf_clearance" }
            if ($cfClearance) {
                Write-Host "     ✅ cf_clearance cookie found (Cloudflare bypass working!)" -ForegroundColor Green
            } else {
                Write-Host "     ⚠️  cf_clearance cookie NOT found (may not be needed for this site)" -ForegroundColor Yellow
            }
        }
        
        # Check response content
        if ($response.solution.response) {
            $contentLength = $response.solution.response.Length
            Write-Host "     Response size: $contentLength bytes" -ForegroundColor Gray
            
            # Check if we got blocked
            if ($response.solution.response -match "Just a moment|Checking your browser|cloudflare") {
                Write-Host "     ⚠️  Response still contains Cloudflare challenge markers" -ForegroundColor Yellow
                Write-Host "     This might indicate the bypass didn't fully work" -ForegroundColor Yellow
            } else {
                Write-Host "     ✅ No Cloudflare challenge markers detected" -ForegroundColor Green
            }
        }
        
    } else {
        Write-Host "  ❌ Cloudflare bypass FAILED" -ForegroundColor Red
        Write-Host "     Status: $($response.status)" -ForegroundColor Gray
        Write-Host "     Message: $($response.message)" -ForegroundColor Gray
        
        # Common error messages and solutions
        if ($response.message -match "timeout|timed out") {
            Write-Host ""
            Write-Host "  💡 Timeout error - Cloudflare 2026 challenges are very aggressive" -ForegroundColor Yellow
            Write-Host "     Solutions:" -ForegroundColor White
            Write-Host "     1. Use residential proxies (recommended)" -ForegroundColor Gray
            Write-Host "     2. Increase Byparr memory limit in docker-compose.yml" -ForegroundColor Gray
            Write-Host "     3. Try manual cookie extraction (see docs)" -ForegroundColor Gray
        }
        
        if ($response.message -match "unknown error|NoneType") {
            Write-Host ""
            Write-Host "  💡 Byparr challenge solver failed" -ForegroundColor Yellow
            Write-Host "     This usually means:" -ForegroundColor White
            Write-Host "     • Datacenter IP is being blocked (use residential proxy)" -ForegroundColor Gray
            Write-Host "     • Not enough memory (increase to 2GB per instance)" -ForegroundColor Gray
            Write-Host "     • Cloudflare updated their protection" -ForegroundColor Gray
        }
    }
    
} catch {
    Write-Host "  ❌ Request failed: $_" -ForegroundColor Red
    
    if ($_.Exception.Message -match "timeout") {
        Write-Host ""
        Write-Host "  💡 Request timed out after 200 seconds" -ForegroundColor Yellow
        Write-Host "     Cloudflare 2026 challenges can take 3+ minutes to solve" -ForegroundColor White
        Write-Host "     Consider using residential proxies for better success rate" -ForegroundColor Gray
    }
}
Write-Host ""

# Test 6: Check environment variables for proxy configuration
Write-Host "[6/6] Checking proxy configuration..." -ForegroundColor Yellow
$envFile = ".env"
if (Test-Path $envFile) {
    $envContent = Get-Content $envFile -Raw
    
    if ($envContent -match "PROXY_URL=(.+)") {
        $proxyUrl = $matches[1].Trim()
        if ($proxyUrl -and $proxyUrl -ne "") {
            Write-Host "  ✅ Proxy configured: $proxyUrl" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  PROXY_URL is empty (using direct connection)" -ForegroundColor Yellow
            Write-Host "     Datacenter IPs are often blocked by Cloudflare" -ForegroundColor Gray
            Write-Host "     Consider using residential proxies for better success rate" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ⚠️  No proxy configured in .env file" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠️  No .env file found" -ForegroundColor Yellow
    Write-Host "     Copy .env.example to .env and configure proxy if needed" -ForegroundColor Gray
}
Write-Host ""

# Summary
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                      📊 SUMMARY                            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Byparr Status: " -NoNewline
$byparrRunning = docker ps --filter "name=byparr" --format "{{.Names}}" 2>&1
if ($byparrRunning) {
    Write-Host "✅ RUNNING" -ForegroundColor Green
} else {
    Write-Host "❌ NOT RUNNING" -ForegroundColor Red
}
Write-Host ""

Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. If Cloudflare bypass is failing, configure residential proxy in .env" -ForegroundColor Gray
Write-Host "  2. Check GitHub Actions logs: .\scripts\check-github-actions-status.ps1" -ForegroundColor Gray
Write-Host "  3. View Byparr logs: docker logs byparr-lb" -ForegroundColor Gray
Write-Host "  4. Restart services: docker-compose restart" -ForegroundColor Gray
Write-Host ""
