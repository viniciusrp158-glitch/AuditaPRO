$ErrorActionPreference = 'Stop'
$env:AUDITA_PRO_PORT = '5181'
Write-Host 'Audita PRO: http://127.0.0.1:5181/audita-pro-login.html'
node (Join-Path $PSScriptRoot 'audita-pro-dev-server.js')
