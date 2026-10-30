# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
param([Parameter(Mandatory)][string]$PackageDirectory,
      [Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$archive = @(Get-ChildItem -LiteralPath $PackageDirectory -Filter '*-win64.zip')
if ($archive.Count -ne 1) { throw 'Expected one Windows demo archive' }
$receipt = Get-Content -Raw -LiteralPath (Join-Path $PackageDirectory 'verification.json') | ConvertFrom-Json
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $archive[0].FullName).Hash.ToLower() -ne $receipt.archiveSha256) { throw 'Archive digest mismatch' }
$destination = Join-Path $OutputDirectory 'unpacked'
Expand-Archive -LiteralPath $archive[0].FullName -DestinationPath $destination
$exe = Join-Path $destination 'RetroRecomped-Windows-Demo/RetroRecomped.exe'
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $exe).Hash.ToLower() -ne $receipt.fusedExeSha256) { throw 'Final EXE digest mismatch' }
$start = [DateTime]::UtcNow
$env:RETRO_WINDOWS_CLOUD_SELFTEST = '1'
try {
    $process = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -PassThru `
        -RedirectStandardOutput (Join-Path $OutputDirectory 'stdout.log') `
        -RedirectStandardError (Join-Path $OutputDirectory 'stderr.log')
    if (-not $process.WaitForExit(100000)) {
        $process.Kill()
        throw 'Final EXE diagnostics timed out'
    }
    if ($process.ExitCode -ne 0) { throw "Final EXE diagnostics failed: $($process.ExitCode)" }
    $roots = @($env:APPDATA, (Join-Path $env:APPDATA 'LOVE'))
    $reports = @($roots | Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object {
        Get-ChildItem -LiteralPath $_ -Directory -Filter 'oasc-windows-cloud-qa-*' | ForEach-Object {
            $path = Join-Path $_.FullName 'cloud-selftest.json'
            if (Test-Path -LiteralPath $path) {
                $file = Get-Item -LiteralPath $path
                if ($file.LastWriteTimeUtc -ge $start.AddSeconds(-2)) { $file }
            }
        }
    })
    if ($reports.Count -ne 1) { throw 'Expected exactly one fresh isolated diagnostic report' }
    $report = Get-Content -Raw -LiteralPath $reports[0].FullName | ConvertFrom-Json
    if ($report.passed -ne $true -or $report.platform -ne 'Windows' -or $report.checks.Count -ne 9) { throw 'Native Windows checks did not all pass' }
    Copy-Item -LiteralPath $reports[0].FullName -Destination (Join-Path $OutputDirectory 'cloud-selftest.json')
    @{ schema=1; passed=$true; exeSha256=$receipt.fusedExeSha256; sourceRevision=$receipt.sourceRevision;
       checks=$report.checks; scope=$report.scope; playerCloudUploadTested=$false; nativeCartridgeGameplayTested=$false } |
        ConvertTo-Json -Depth 10 | Set-Content -Encoding utf8 (Join-Path $OutputDirectory 'native-package-test.json')
    Write-Host 'Final Windows EXE: isolated native HTTPS/profile diagnostics passed; no player account upload or cartridge gameplay.'
} finally {
    Remove-Item Env:RETRO_WINDOWS_CLOUD_SELFTEST -ErrorAction SilentlyContinue
}
