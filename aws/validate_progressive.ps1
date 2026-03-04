<#
.SYNOPSIS
  Validates the progressive Terraform lab by merging delta folders in order
  and running terraform validate at each stage.
.DESCRIPTION
  Copies files from each lab stage into _tmp_progressive_validate in order:
    s3-bucket > vpc > security-group > language > website
  Then runs terraform init + terraform validate at each stage.
  Also validates website-with-modules separately.
#>

param(
    [switch]$SkipModules,
    [switch]$CleanOnly
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$tmpDir = Join-Path $root "_tmp_progressive_validate"

# Stages in order (each is a delta)
$stages = @(
    @{ Name = "s3-bucket";      Source = Join-Path $root "s3-bucket" },
    @{ Name = "vpc";            Source = Join-Path $root "vpc" },
    @{ Name = "security-group"; Source = Join-Path $root "security-group" },
    @{ Name = "language";       Source = Join-Path $root "language" },
    @{ Name = "website";        Source = Join-Path $root "website" }
)

function Clean-TmpDir {
    if (Test-Path $tmpDir) {
        # Remove .terraform and lock file but preserve the dir
        $tfDir = Join-Path $tmpDir ".terraform"
        $lockFile = Join-Path $tmpDir ".terraform.lock.hcl"
        if (Test-Path $tfDir) { Remove-Item -Recurse -Force $tfDir }
        if (Test-Path $lockFile) { Remove-Item -Force $lockFile }
        # Remove all .tf, .tfvars, .sh files  
        Get-ChildItem -Path $tmpDir -File | Where-Object { $_.Extension -in '.tf','.tfvars','.sh' } | Remove-Item -Force
    } else {
        New-Item -ItemType Directory -Path $tmpDir | Out-Null
    }
}

function Validate-Stage {
    param([string]$StageName, [string]$Dir)
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Validating: $StageName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # List current files
    Write-Host "`nFiles in folder:" -ForegroundColor Yellow
    Get-ChildItem -Path $Dir -File | Where-Object { $_.Extension -in '.tf','.tfvars','.sh' } | 
        ForEach-Object { Write-Host "  $_" }
    
    Push-Location $Dir
    try {
        Write-Host "`n--- terraform init ---" -ForegroundColor Gray
        $initResult = & terraform init -backend=false -input=false -no-color 2>&1
        $initExitCode = $LASTEXITCODE
        if ($initExitCode -ne 0) {
            Write-Host "INIT FAILED (exit $initExitCode):" -ForegroundColor Red
            $initResult | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
            return $false
        } else {
            Write-Host "  Init OK" -ForegroundColor Green
        }
        
        Write-Host "--- terraform validate ---" -ForegroundColor Gray
        $valResult = & terraform validate -no-color 2>&1
        $valExitCode = $LASTEXITCODE
        if ($valExitCode -ne 0) {
            Write-Host "VALIDATE FAILED (exit $valExitCode):" -ForegroundColor Red
            $valResult | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
            return $false
        } else {
            Write-Host "  Validate OK" -ForegroundColor Green
            return $true
        }
    } finally {
        Pop-Location
    }
}

# --- Main ---
Write-Host "Progressive Terraform Lab Validator" -ForegroundColor White
Write-Host "====================================" -ForegroundColor White

# Clean and rebuild
Clean-TmpDir
if ($CleanOnly) { Write-Host "Cleaned. Exiting."; return }

$results = @{}

foreach ($stage in $stages) {
    $name = $stage.Name
    $src  = $stage.Source
    
    Write-Host "`n>> Copying delta: $name" -ForegroundColor Magenta
    
    if (-not (Test-Path $src)) {
        Write-Host "  WARNING: Source folder '$src' not found, skipping." -ForegroundColor Yellow
        continue
    }
    
    # Copy all .tf, .tfvars, and .sh files from stage into tmp (overwriting)
    Get-ChildItem -Path $src -File | Where-Object { $_.Extension -in '.tf','.tfvars','.sh' } |
        ForEach-Object {
            Copy-Item $_.FullName -Destination $tmpDir -Force
            Write-Host "  Copied: $($_.Name)" -ForegroundColor DarkGray
        }
    
    # Need to re-init after file changes (modules may change)
    $tfDir = Join-Path $tmpDir ".terraform"
    if (Test-Path $tfDir) { Remove-Item -Recurse -Force $tfDir }
    
    $ok = Validate-Stage -StageName "After $name" -Dir $tmpDir
    $results[$name] = $ok
}

# --- Validate website-with-modules ---
if (-not $SkipModules) {
    $modulesDir = Join-Path $root "website-with-modules\space-invaders-website"
    if (Test-Path $modulesDir) {
        $ok = Validate-Stage -StageName "website-with-modules" -Dir $modulesDir
        $results["website-with-modules"] = $ok
        
        # Clean up .terraform from modules dir
        $tfDir = Join-Path $modulesDir ".terraform"
        $lockFile = Join-Path $modulesDir ".terraform.lock.hcl"
        if (Test-Path $tfDir) { Remove-Item -Recurse -Force $tfDir }
        if (Test-Path $lockFile) { Remove-Item -Force $lockFile }
    }
}

# --- Summary ---
Write-Host "`n`n====================================" -ForegroundColor White
Write-Host "  SUMMARY" -ForegroundColor White
Write-Host "====================================" -ForegroundColor White
foreach ($key in $results.Keys | Sort-Object) {
    $status = if ($results[$key]) { "PASS" } else { "FAIL" }
    $color  = if ($results[$key]) { "Green" } else { "Red" }
    Write-Host "  $key : $status" -ForegroundColor $color
}
Write-Host ""
