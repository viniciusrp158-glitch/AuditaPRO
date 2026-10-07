$ErrorActionPreference = 'Stop'

# Promove a conta existente sem alterar senha nem sobrescrever outros metadados.
# Requer uma sessão já autenticada pelo Supabase CLI.
$projectRef = 'zlckcpeqcxmtrgbdquee'
$adminEmail = 'viniciusrp158@hotmail.com'
$supabaseCli = Join-Path $PSScriptRoot 'audita-pro-supabase\supabase.exe'
if (-not (Test-Path -LiteralPath $supabaseCli)) {
    $supabaseCli = Join-Path (Split-Path $PSScriptRoot -Parent) 'work\supabase-cli\supabase.exe'
}

$keyOutput = $null
$serviceKey = $null
$headers = $null
try {
    if (-not (Test-Path -LiteralPath $supabaseCli)) {
        throw 'Supabase CLI não encontrado. Instale-o e autentique com supabase login.'
    }

    # Captura a chave somente em memória e nunca a imprime.
    $keyOutput = (& $supabaseCli projects api-keys --project-ref $projectRef 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw 'Não foi possível consultar a chave do projeto. O CLI precisa estar autenticado e poder acessar sua configuração local.'
    }
    $keyLine = ($keyOutput -split "`r?`n" | Where-Object { $_ -match '^\s*service_role\s*\|' } | Select-Object -First 1)
    $keyMatch = [regex]::Match($keyLine, '^\s*service_role\s*\|\s*(\S+)')
    if (-not $keyMatch.Success) { throw 'A resposta do CLI não continha a chave administrativa esperada.' }
    $serviceKey = $keyMatch.Groups[1].Value
    $headers = @{ apikey = $serviceKey; Authorization = "Bearer $serviceKey" }
    $baseUrl = "https://$projectRef.supabase.co/auth/v1/admin/users"

    # A Admin API lista usuários paginados; o script mantém os resultados apenas em memória.
    $target = $null
    for ($page = 1; $page -le 100; $page++) {
        $response = Invoke-RestMethod -Method Get -Uri "$baseUrl`?page=$page&perPage=1000" -Headers $headers
        $users = @($response.users)
        $target = $users | Where-Object { $_.email -and $_.email.Equals($adminEmail,[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if ($target -or $users.Count -lt 1000) { break }
    }
    if (-not $target) { throw "A conta $adminEmail não foi encontrada em Authentication > Users. Nenhuma alteração foi feita." }

    $metadata = @{}
    if ($target.app_metadata -is [System.Collections.IDictionary]) {
        foreach ($entry in $target.app_metadata.GetEnumerator()) { $metadata[$entry.Key] = $entry.Value }
    } elseif ($target.app_metadata) {
        foreach ($property in $target.app_metadata.PSObject.Properties) { $metadata[$property.Name] = $property.Value }
    }
    if ($metadata['platform_role'] -eq 'admin') {
        Write-Output 'A conta já possui o papel Administrador no projeto Audita PRO.'
        Write-Output "E-mail: $($target.email)"
        return
    }

    $metadata['platform_role'] = 'admin'
    $body = @{ app_metadata = $metadata } | ConvertTo-Json -Depth 10 -Compress
    $updated = Invoke-RestMethod -Method Put -Uri "$baseUrl/$($target.id)" -Headers $headers -ContentType 'application/json' -Body $body
    if ($updated.app_metadata.platform_role -ne 'admin') {
        throw 'O Supabase não confirmou o papel Administrador. Confira o usuário no painel antes de tentar novamente.'
    }
    Write-Output 'Conta promovida para Administrador no projeto Audita PRO.'
    Write-Output "E-mail: $($updated.email)"
    Write-Output 'Saia e entre novamente no Audita PRO para renovar a sessão e carregar as permissões.'
}
catch {
    Write-Error $_.Exception.Message
}
finally {
    $keyOutput = $null
    $serviceKey = $null
    $headers = $null
    $body = $null
    $metadata = $null
    $target = $null
}
