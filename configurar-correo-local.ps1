$ErrorActionPreference = 'Stop'
$correoBackend = Join-Path (Split-Path $PSScriptRoot -Parent) 'transportegutierrezBack/TransportesGutierrez.Api/TransportesGutierrez.Api.csproj'
if (-not (Test-Path -LiteralPath $correoBackend)) { throw 'No se encontró el proyecto del backend.' }
$correoRemitente = Read-Host 'Correo remitente configurado en Brevo'
try { $null = [System.Net.Mail.MailAddress]::new($correoRemitente) } catch { throw 'El remitente no tiene un formato de correo válido.' }
$correoClave = Read-Host 'Clave API de Brevo (entrada oculta)' -AsSecureString
$correoPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($correoClave)
try {
    $correoTexto = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($correoPointer)
    if ([string]::IsNullOrWhiteSpace($correoTexto)) { throw 'La clave no puede estar vacía.' }
    # Stdin avoids putting the key in command arguments, shell history or repository files.
    @{ 'Brevo:ApiKey' = $correoTexto; 'Brevo:SenderEmail' = $correoRemitente } |
        ConvertTo-Json -Compress | dotnet user-secrets set --project $correoBackend
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo guardar la configuración local.' }
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($correoPointer)
    $correoTexto = $null
    $correoClave.Dispose()
}
Write-Host 'Configuración local guardada. Reinicie el backend. Este script no envía correos.'
