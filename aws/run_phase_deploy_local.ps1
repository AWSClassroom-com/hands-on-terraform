param(
    [string]$Root = "c:\Git\hands-on-terraform\aws\website-with-modules",
    [string]$TmpDir = "c:\Git\hands-on-terraform\aws\_tmp_progressive_validate",
    [string]$RunTag,
    [bool]$DestroyExistingTmpBeforeRun = $true,
    [switch]$KeepResources,
    [switch]$FreshState,
    [switch]$SkipHttpCheck
)

$ErrorActionPreference = "Stop"

$phases = @(
    "initial",
    "phase1-modularized",
    "phase2-optimized"
)

function Get-UserTag {
    param([string]$RequestedTag)

    if (-not [string]::IsNullOrWhiteSpace($RequestedTag)) {
        $tag = ($RequestedTag.ToLower() -replace "[^a-z0-9-]", "")
        if ([string]::IsNullOrWhiteSpace($tag)) { throw "RunTag is invalid after normalization." }
        if ($tag.Length -gt 18) { $tag = $tag.Substring(0, 18) }
        return $tag
    }

    $raw = if ($env:USERNAME) { $env:USERNAME } else { "userxx" }
    $prefix = ($raw.ToLower() -replace "[^a-z0-9]", "")
    if ($prefix.Length -gt 8) { $prefix = $prefix.Substring(0, 8) }

    $suffix = (Get-Random -Minimum 1000 -Maximum 9999)
    $tag = "$prefix$suffix"

    if ([string]::IsNullOrWhiteSpace($tag)) { $tag = "userxx" }
    if ($tag.Length -gt 18) { $tag = $tag.Substring(0, 18) }
    return $tag
}

function Reset-TmpForPhase {
    param([string]$Dir, [bool]$KeepState)

    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir | Out-Null
        return
    }

    Get-ChildItem -Path $Dir -Force | ForEach-Object {
        $name = $_.Name
        $preserve = $false

        if ($KeepState) {
            if ($name -eq "terraform.tfstate" -or $name -eq "terraform.tfstate.backup") {
                $preserve = $true
            }
        }

        if ($name -eq ".gitignore") {
            $preserve = $true
        }

        if (-not $preserve) {
            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Copy-Phase {
    param([string]$PhaseName)

    $src = Join-Path $Root $PhaseName
    if (-not (Test-Path $src)) {
        throw "Phase source does not exist: $src"
    }

    Copy-Item -Path (Join-Path $src "*") -Destination $TmpDir -Recurse -Force
}

function Normalize-Tfvars {
    param([string]$Dir, [string]$UserTag)

    $tfvars = Join-Path $Dir "terraform.tfvars"
    if (-not (Test-Path $tfvars)) {
        return
    }

    $content = Get-Content -Path $tfvars -Raw

    # Replace placeholder names in temp copy only.
    $content = $content -replace "<userxx>", $UserTag

    # Force known account in temp for consistency.
    $content = [regex]::Replace($content, '(?m)^\s*account\s*=\s*"[^"]*"\s*$', "account              = `"$UserTag`"")

    # Ensure phase deploys (keep this in temp only).
    $content = [regex]::Replace($content, '(?m)^\s*instance_count_max\s*=\s*\d+\s*$', "instance_count_max   = 4")

    Set-Content -Path $tfvars -Value $content -NoNewline
}

function Run-Terraform {
    param(
        [string]$Phase,
        [bool]$RequireNoChanges
    )

    Push-Location $TmpDir
    try {
        Write-Host "`n===============================" -ForegroundColor Cyan
        Write-Host "Phase: $Phase" -ForegroundColor Cyan
        Write-Host "===============================" -ForegroundColor Cyan

        terraform init -reconfigure -input=false -no-color
        if ($LASTEXITCODE -ne 0) { throw "terraform init failed ($Phase)" }

        terraform validate -no-color
        if ($LASTEXITCODE -ne 0) { throw "terraform validate failed ($Phase)" }

        $planOut = terraform plan -input=false -no-color 2>&1
        $planExit = $LASTEXITCODE
        $planOut | ForEach-Object { Write-Host $_ }
        if ($planExit -ne 0) { throw "terraform plan failed ($Phase)" }

        $summaryMatch = [regex]::Match(($planOut -join "`n"), 'Plan:\s+(\d+) to add,\s+(\d+) to change,\s+(\d+) to destroy\.')
        if (-not $summaryMatch.Success) {
            throw "Could not parse plan summary ($Phase)"
        }

        $add = [int]$summaryMatch.Groups[1].Value
        $chg = [int]$summaryMatch.Groups[2].Value
        $del = [int]$summaryMatch.Groups[3].Value

        Write-Host "Plan summary for $Phase => add=$add change=$chg destroy=$del" -ForegroundColor Yellow

        if ($RequireNoChanges -and (($add -ne 0) -or ($chg -ne 0) -or ($del -ne 0))) {
            throw "Expected no infrastructure changes in $Phase transition, but got add=$add change=$chg destroy=$del"
        }

        terraform apply -auto-approve -input=false -no-color
        if ($LASTEXITCODE -ne 0) { throw "terraform apply failed ($Phase)" }

        terraform plan -detailed-exitcode -input=false -no-color | Out-Null
        $postExit = $LASTEXITCODE
        if ($postExit -eq 1) { throw "post-apply plan failed ($Phase)" }
        if ($postExit -eq 2) { throw "post-apply plan not clean ($Phase)" }

        Write-Host "Post-apply plan is clean for $Phase" -ForegroundColor Green

        return $true
    }
    finally {
        Pop-Location
    }
}

function Destroy-IfStatePresent {
    param([string]$Reason)

    $statePath = Join-Path $TmpDir "terraform.tfstate"
    if (-not (Test-Path $statePath)) {
        Write-Host "No existing local state found in tmp. Skipping destroy ($Reason)." -ForegroundColor DarkGray
        return
    }

    Push-Location $TmpDir
    try {
        Write-Host "`nDestroy step ($Reason)" -ForegroundColor Yellow

        terraform init -reconfigure -input=false -no-color | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "terraform init failed during destroy step ($Reason)"
        }

        terraform destroy -auto-approve -input=false -no-color
        if ($LASTEXITCODE -ne 0) {
            throw "terraform destroy failed ($Reason)"
        }

        Write-Host "Destroy completed ($Reason)." -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}

function Test-App {
    param([int]$Retries = 30, [int]$SleepSeconds = 10)

    if ($SkipHttpCheck) {
        Write-Host "Skipping HTTP check by request." -ForegroundColor Yellow
        return
    }

    Push-Location $TmpDir
    try {
        $dns = terraform output -raw load_balancer_dns 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($dns)) {
            Write-Host "No load_balancer_dns output available for HTTP check." -ForegroundColor Yellow
            return
        }

        $url = "http://$dns/"
        Write-Host "Checking app endpoint: $url" -ForegroundColor Gray

        for ($i = 1; $i -le $Retries; $i++) {
            try {
                $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15
                if ($resp.StatusCode -eq 200) {
                    Write-Host "App check passed (HTTP 200)." -ForegroundColor Green
                    return
                }
            }
            catch {
                # warm-up period
            }

            Start-Sleep -Seconds $SleepSeconds
        }

        throw "App did not return HTTP 200 within timeout: $url"
    }
    finally {
        Pop-Location
    }
}

$userTag = Get-UserTag -RequestedTag $RunTag
Write-Host "Using temp lab user tag: $userTag" -ForegroundColor White

if ($FreshState) {
    Write-Host "Fresh state requested - existing local state will be cleared." -ForegroundColor Yellow
}

if ($DestroyExistingTmpBeforeRun) {
    Destroy-IfStatePresent -Reason "pre-run cleanup"
}

for ($i = 0; $i -lt $phases.Count; $i++) {
    $phase = $phases[$i]
    $keepState = $true

    if (($i -eq 0) -and $FreshState) {
        $keepState = $false
    }

    Reset-TmpForPhase -Dir $TmpDir -KeepState:$keepState
    Copy-Phase -PhaseName $phase
    Normalize-Tfvars -Dir $TmpDir -UserTag $userTag

    $requireNoChanges = ($i -gt 0)
    Run-Terraform -Phase $phase -RequireNoChanges:$requireNoChanges | Out-Null

    if ($i -eq 0) {
        # Only do full warm-up check once after initial deploy.
        Test-App
    }
}

if (-not $KeepResources) {
    Destroy-IfStatePresent -Reason "post-run cleanup"
}

Write-Host "`nAll 3 phases completed successfully with local backend in: $TmpDir" -ForegroundColor Green
