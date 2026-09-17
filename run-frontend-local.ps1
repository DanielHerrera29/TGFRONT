$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    Write-Host 'Frontend local -> http://localhost:5116 (API local)'
    & flutter run -d chrome --web-hostname localhost --web-port 5173 --dart-define=API_URL=http://localhost:5116
    $frontendExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $frontendExitCode
