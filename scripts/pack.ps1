# Build F2A HarmonyOS HAP / APP into dist\
# Requires DevEco Studio 5.0+ or Command Line Tools 26+ on this machine.

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

function Find-Tool([string]$name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $candidates = @(
    "$env:DEVECO_SDK_HOME\..\tools\hvigor\bin\hvigorw.bat",
    "$env:DEVECO_CLI_STUDIO_PATH\tools\hvigor\bin\hvigorw.bat",
    "$env:DEVECO_CLI_CLT_PATH\bin\hvigorw.bat",
    'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat',
    'D:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat',
    'C:\Program Files\Huawei\DevEco Studio\tools\ohpm\bin\ohpm.bat',
    'D:\Program Files\Huawei\DevEco Studio\tools\ohpm\bin\ohpm.bat'
  )
  foreach ($p in $candidates) {
    if ($p -and (Test-Path $p) -and ([IO.Path]::GetFileName($p) -eq $name)) {
      return $p
    }
  }
  return $null
}

function Find-ByName([string]$fileName) {
  $roots = @(
    "$env:DEVECO_CLI_STUDIO_PATH",
    "$env:DEVECO_CLI_CLT_PATH",
    'C:\Program Files\Huawei\DevEco Studio',
    'D:\Program Files\Huawei\DevEco Studio',
    'C:\Huawei\DevEco Studio',
    'D:\Huawei\DevEco Studio'
  ) | Where-Object { $_ -and (Test-Path $_) }
  foreach ($root in $roots) {
    $hit = Get-ChildItem $root -Recurse -Filter $fileName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { return $hit.FullName }
  }
  $cmd = Get-Command ($fileName -replace '\.bat$','') -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

$hvigor = Find-ByName 'hvigorw.bat'
$ohpm = Find-ByName 'ohpm.bat'
$devecocli = Get-Command devecocli -ErrorAction SilentlyContinue

if (-not $hvigor -and -not $devecocli) {
  Write-Host @'
本机没有鸿蒙构建工具，无法生成 .hap / .app 安装包。

请先安装其一：
1. DevEco Studio 5.0+（推荐）
   https://developer.huawei.com/consumer/cn/download/deveco-studio
2. Command Line Tools 26+
   https://developer.huawei.com/consumer/cn/download/command-line-tools-for-hmos

安装后用华为账号登录，在 DevEco Studio 中打开本工程并完成自动签名，再重新运行：
  powershell -ExecutionPolicy Bypass -File .\scripts\pack.ps1
'@
  exit 1
}

New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot 'dist') | Out-Null

if ($devecocli) {
  Write-Host 'Using devecocli build --build-mode release'
  & $devecocli.Source build --build-mode release
} else {
  if ($ohpm) {
    Write-Host "ohpm install via $ohpm"
    & $ohpm install
  }
  Write-Host "hvigor assembleHap via $hvigor"
  & $hvigor --mode module -p module=entry@default -p product=default assembleHap --no-daemon
}

$outputs = @()
$outputs += Get-ChildItem -Path $ProjectRoot -Recurse -Include *.hap,*.app -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\oh_modules\\|\\node_modules\\' }

if ($outputs.Count -eq 0) {
  Write-Host '构建结束，但未找到 .hap / .app。请先在 DevEco Studio 配置 Signing Configs。'
  exit 2
}

foreach ($f in $outputs) {
  Copy-Item $f.FullName (Join-Path $ProjectRoot 'dist' $f.Name) -Force
  Write-Host ("PACKAGED " + $f.FullName)
}

Write-Host ("安装包已复制到 " + (Join-Path $ProjectRoot 'dist'))
