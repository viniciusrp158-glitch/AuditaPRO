$ErrorActionPreference = 'Stop'

$projectRef = 'zlckcpeqcxmtrgbdquee'
$supabaseCli = 'C:\Users\Vinicius Rocha\Documents\Codex\2026-10-05\co\work\supabase-cli\supabase.exe'
$adminEmail = 'auditapro2209@hotmail.com'
$apiBase = "https://$projectRef.supabase.co"
$serviceKey = $null
$passwordText = $null
$requestBody = $null
$keyOutput = $null
$ptr = [IntPtr]::Zero
$securePassword = $null

try {
    if (-not (Test-Path -LiteralPath $supabaseCli)) {
        throw 'O Supabase CLI não foi encontrado no caminho esperado.'
    }

    # Captura a saída em memória para não imprimir as chaves administrativas.
    $keyOutput = (& $supabaseCli projects api-keys --project-ref $projectRef 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw 'O Supabase CLI não conseguiu consultar as chaves. Confira se esta sessão está autenticada com supabase login.'
    }

    $serviceRoleLine = ($keyOutput -split "`r?`n" | Where-Object { $_ -match '^\s*service_role\s*\|' } | Select-Object -First 1)
    if (-not $serviceRoleLine) {
        throw 'A resposta do CLI não continha a chave service_role esperada.'
    }
    $match = [regex]::Match($serviceRoleLine, '^\s*service_role\s*\|\s*(\S+)')
    if (-not $match.Success) {
        throw 'Não foi possível interpretar a chave service_role sem exibi-la.'
    }
    $serviceKey = $match.Groups[1].Value

    $securePassword = Read-Host 'Digite a senha inicial do administrador (entrada oculta)' -AsSecureString
    if ($securePassword.Length -lt 8) {
        throw 'A senha precisa ter pelo menos 8 caracteres.'
    }

    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($securePassword)
    $passwordText = [Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)

    $payload = [ordered]@{
        email         = $adminEmail
        password      = $passwordText
        email_confirm = $true
        app_metadata  = @{ platform_role = 'admin' }
    }
    $requestBody = $payload | ConvertTo-Json -Depth 5 -Compress
    $headers = @{
        apikey        = $serviceKey
        Authorization = "Bearer $serviceKey"
    }

    $createdUser = Invoke-RestMethod -Method Post `
        -Uri "$apiBase/auth/v1/admin/users" `
        -Headers $headers `
        -ContentType 'application/json' `
        -Body $requestBody

    if ($createdUser.user) { $createdUser = $createdUser.user }
    $platformRole = $createdUser.app_metadata.platform_role
    if ($platformRole -ne 'admin') {
        throw 'O usuário foi criado, mas o Supabase não confirmou o papel de administrador. Não tente criar novamente; confira o usuário no painel Auth.'
    }

    Write-Output 'Usuário administrador criado e confirmado no Supabase.'
    Write-Output "E-mail: $($createdUser.email)"
    Write-Output "ID: $($createdUser.id)"
    Write-Output "Papel: $platformRole"
}
catch {
    if ($_.Exception.Message -match 'already been registered|already exists|User already registered') {
        Write-Error 'Este e-mail já existe no Supabase. Nenhuma senha ou permissão foi alterada; verifique o usuário em Authentication > Users antes de continuar.'
    } else {
        Write-Error $_.Exception.Message
    }
    return
}
finally {
    $serviceKey = $null
    $keyOutput = $null
    $passwordText = $null
    $requestBody = $null
    $payload = $null
    $headers = $null
    if ($ptr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($ptr)
    }
    if ($securePassword) { $securePassword.Dispose() }
}
