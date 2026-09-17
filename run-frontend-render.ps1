$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    Write-Host 'Frontend conectado a https://tgback-api.onrender.com'
    & flutter run -d chrome --dart-define=API_URL=https://tgback-api.onrender.com
    $renderFrontendExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $renderFrontendExitCode
