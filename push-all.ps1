# ============================================================
#  push-all.ps1 - 一键推送 GitHub + Gitee
#  雪域阳光方舟 · 毕设答辩双站
#
#  用法：
#    powershell -ExecutionPolicy Bypass -File push-all.ps1
#    powershell -ExecutionPolicy Bypass -File push-all.ps1 -Message "fix: ..."
#    powershell -ExecutionPolicy Bypass -File push-all.ps1 -SkipBackup
#    powershell -ExecutionPolicy Bypass -File push-all.ps1 -SkipGitee
#    powershell -ExecutionPolicy Bypass -File push-all.ps1 -SkipGitHub
#    powershell -ExecutionPolicy Bypass -File push-all.ps1 -Force
# ============================================================

param(
    [string]$Message = "update site",
    [switch]$SkipBackup = $false,
    [switch]$SkipGitee = $false,
    [switch]$SkipGitHub = $false,
    [switch]$Force = $false
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$base = $PSScriptRoot
Set-Location $base

# ---- ASCII only - safe under any Windows code page ----

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

function Push-One([string]$remote, [string]$branch) {
    Write-Host ""
    Write-Host "=== Push to $remote/$branch ===" -ForegroundColor Cyan
    $ahead = git rev-list --count "@{u}..HEAD" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  No upstream, will run first push" -ForegroundColor DarkYellow
    } elseif ([int]$ahead -gt 0) {
        Write-Host "  Local is ahead by $ahead commit(s)" -ForegroundColor Green
    } else {
        Write-Host "  Already up-to-date" -ForegroundColor DarkYellow
        return 0
    }
    if ($Force) {
        Write-Host "  (--force mode)" -ForegroundColor DarkYellow
        git push --force $remote $branch
    } else {
        git push $remote $branch
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [X] Push to $remote FAILED" -ForegroundColor Red
        return 1
    }
    Write-Host "  [OK] Push to $remote success" -ForegroundColor Green
    return 0
}

# ---- header ----
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Snow Ark - Dual Push (GitHub + Gitee)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ("Time:     {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Write-Host ("Commit:   {0}" -f $Message)
Write-Host ("Backup:   {0}" -f $(if ($SkipBackup) {'SKIP'} else {'include'}))
Write-Host ("GitHub:   {0}" -f $(if ($SkipGitHub) {'SKIP'} else {'push'}))
Write-Host ("Gitee:    {0}" -f $(if ($SkipGitee) {'SKIP'} else {'push'}))
Write-Host ""

# ---- 1. remote list ----
Write-Host "[1/4] Remote check" -ForegroundColor Yellow
$remotes = git remote -v
Write-Host $remotes
if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] Not a git repository" -ForegroundColor Red
    exit 1
}
Write-Host ""

# ---- 2. status ----
Write-Host "[2/4] Status preview" -ForegroundColor Yellow
git status --short
Write-Host ""

# ---- 3. stage + commit ----
Write-Host "[3/4] Stage + commit" -ForegroundColor Yellow
if ($SkipBackup) {
    git add -A -- ':!_backup_0529'
} else {
    git add -A
}
$stagedCount = (git diff --cached --name-only | Measure-Object -Line).Lines
if ($stagedCount -gt 0) {
    $commitMsg = "[$((Get-Date).ToString('MM-dd HH:mm'))] $Message"
    Write-Host "  Staged: $stagedCount files, committing: $commitMsg" -ForegroundColor Green
    $code = Invoke-GitCommit $commitMsg
    if ($code -ne 0) {
        Write-Host "  [!] commit returned code $code" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "  Nothing to commit (working tree clean)" -ForegroundColor DarkYellow
}
Write-Host ""

# ---- 4. push to remotes ----
Write-Host "[4/4] Pushing to remotes" -ForegroundColor Yellow
$branch = git branch --show-current
$failed = 0

if (-not $SkipGitHub) {
    $r = Push-One "origin" $branch
    if ($r -ne 0) { $failed++ }
}
if (-not $SkipGitee) {
    $r = Push-One "gitee" $branch
    if ($r -ne 0) { $failed++ }
}

# ---- summary ----
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Recent commits" -ForegroundColor Cyan
git log --oneline -5
Write-Host ""
if ($failed -eq 0) {
    Write-Host "  ALL PUSHES SUCCESS" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host "  $failed PUSH(S) FAILED (see above)" -ForegroundColor Red
    Write-Host "  Try again or check network/token" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit 1
}
Write-Host ""
Write-Host "Pages URLs:" -ForegroundColor Cyan
Write-Host "  GitHub : https://samuelszeto769-cmyk.github.io/snow-ark/" -ForegroundColor White
Write-Host "  Gitee  : https://situ-ruiqi.gitee.io/snow-ark/" -ForegroundColor White
Write-Host ""
Write-Host "Note: GitHub Pages 1-2 min, Gitee Pages needs manual Deploy button." -ForegroundColor DarkGray
