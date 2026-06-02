# ============================================================
#  Snow Ark - One-click Push Script
#  Usage:  powershell -ExecutionPolicy Bypass -File push.ps1
#          powershell -ExecutionPolicy Bypass -File push.ps1 -Message "fix: something"
#          powershell -ExecutionPolicy Bypass -File push.ps1 -SkipBackup
# ============================================================
# ASCII-only: safe under any Windows code page (GBK/UTF-8/CP437)
# Chinese characters in user-supplied arguments are forwarded to git
# via UTF-8 byte arrays, bypassing PowerShell's string parsing layer.

param(
    [string]$Message = "update site content",
    [switch]$SkipBackup = $false,
    [switch]$Force = $false   # add --force when pushing (DANGEROUS, only for non-main rewrites)
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$base = $PSScriptRoot
Set-Location $base

# ---- Helpers: safe UTF-8 commit message (avoid PowerShell argv parsing) ----
function Write-Utf8File([string]$Path, [string]$Content) {
    $utf8Bom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

function Invoke-GitCommit([string]$Msg) {
    $tmp = Join-Path $env:TEMP ("gitmsg_" + [Guid]::NewGuid().ToString("N") + ".txt")
    try {
        Write-Utf8File $tmp $Msg
        $output = git commit -F $tmp 2>&1
        $code = $LASTEXITCODE
    } finally {
        Remove-Item -Path $tmp -ErrorAction SilentlyContinue
    }
    $output | ForEach-Object { Write-Host $_ }
    return $code
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Snow Ark - Push Script"               -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Workdir: $base"
Write-Host "Time:    $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# ---------- 1. Remote check ----------
$remote = git remote get-url origin 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] No git remote configured" -ForegroundColor Red
    exit 1
}
Write-Host "[1] Remote: $remote" -ForegroundColor Green
$branch = git branch --show-current
Write-Host "    Branch: $branch" -ForegroundColor Green
Write-Host ""

# ---------- 2. Status preview ----------
Write-Host "[2] Changed files preview:" -ForegroundColor Yellow
git status --short
Write-Host ""
if (-not $SkipBackup) {
    Write-Host "    (includes _backup_0529/ ; add -SkipBackup to exclude)" -ForegroundColor DarkGray
    Write-Host ""
}

# ---------- 3. Stage ----------
if ($SkipBackup) {
    Write-Host "[3] Staging (excluding _backup_0529/)..." -ForegroundColor Yellow
    git add -A -- ':!_backup_0529'
} else {
    Write-Host "[3] Staging all changes..." -ForegroundColor Yellow
    git add -A
}
if ($LASTEXITCODE -ne 0) { exit 1 }
Write-Host "    OK" -ForegroundColor Green
Write-Host ""

# ---------- 4. Check staged changes ----------
$staged = git diff --cached --name-only
$count = ($staged | Measure-Object -Line).Lines
if ($count -gt 0) {
    Write-Host "[4] Staged: $count file(s)" -ForegroundColor Green
    $needCommit = $true
} else {
    Write-Host "[4] Nothing new to stage (working tree clean or already committed)" -ForegroundColor DarkYellow
    $needCommit = $false
}
Write-Host ""

# ---------- 5. Commit (only if there is something staged) ----------
if ($needCommit) {
    $commitMsg = "[$((Get-Date).ToString('MM-dd HH:mm'))] $Message"
    Write-Host "[5] Commit: $commitMsg" -ForegroundColor Yellow
    $code = Invoke-GitCommit $commitMsg
    if ($code -ne 0) {
        Write-Host "    [!] Commit returned code $code (may be empty or no change)" -ForegroundColor DarkYellow
    } else {
        Write-Host "    OK" -ForegroundColor Green
    }
    Write-Host ""
}

# ---------- 6. Check local-ahead vs remote ----------
# git rev-list --count @{u}..HEAD returns 0 when up-to-date, >0 when ahead
$ahead = git rev-list --count "@{u}..HEAD" 2>&1
if ($LASTEXITCODE -ne 0) {
    # No upstream tracking branch yet (first push). Treat as 0 and let push --set-upstream do its job.
    Write-Host "[6] No upstream tracking branch yet (will run first push)" -ForegroundColor DarkYellow
    $needPush = $true
} elseif ([int]$ahead -gt 0) {
    Write-Host "[6] Local is ahead of origin/$branch by $ahead commit(s)" -ForegroundColor Cyan
    $needPush = $true
} else {
    Write-Host "[6] Local is up-to-date with origin/$branch, nothing to push" -ForegroundColor DarkYellow
    $needPush = $false
}
Write-Host ""

# ---------- 7. Push ----------
if ($needPush) {
    Write-Host "[7] Pushing to origin/$branch ..." -ForegroundColor Yellow
    if ($Force) {
        Write-Host "    (--force mode, USE WITH CARE)" -ForegroundColor DarkYellow
        git push --force origin $branch
    } else {
        git push origin $branch
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[X] Push failed. Check network / credentials / upstream." -ForegroundColor Red
        exit 1
    }
    Write-Host "    OK" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "[7] Push skipped (nothing to push)" -ForegroundColor DarkYellow
    Write-Host ""
}

# ---------- 8. Recent commits ----------
Write-Host "[8] Recent commits:" -ForegroundColor Cyan
git log --oneline -5
Write-Host ""

# ---------- 9. Tip ----------
Write-Host "========================================" -ForegroundColor Green
Write-Host "  All done!"                              -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "GitHub Pages (if enabled):" -ForegroundColor Cyan
Write-Host "  https://samuelszeto769-cmyk.github.io/snow-ark/" -ForegroundColor White
Write-Host ""
Write-Host "Note: GitHub Pages usually takes 1-2 minutes to deploy." -ForegroundColor DarkGray
