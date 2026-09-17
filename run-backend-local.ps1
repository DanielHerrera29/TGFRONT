$ErrorActionPreference = 'Stop'
$backendProject = Join-Path (Split-Path $PSScriptRoot -Parent) 'transportegutierrezBack/TransportesGutierrez.Api/TransportesGutierrez.Api.csproj'
if (-not (Test-Path -LiteralPath $backendProject)) {
    throw "No se encuentra el backend: $backendProject"
}
# Desarrollo carga los secretos locales existentes de ASP.NET; no contiene claves.
$env:ASPNETCORE_ENVIRONMENT = 'Development'
$env:PdfRetention__Enabled = 'false'
Write-Host 'Backend local: http://localhost:5116/swagger'
& dotnet run --project $backendProject --launch-profile http --urls http://localhost:5116
exit $LASTEXITCODE
