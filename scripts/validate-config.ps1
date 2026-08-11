[CmdletBinding()]
param(
    [string]$RepositoryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}

$configFiles = @('template.yaml', 'override.yaml')
$builtInTargets = @('DIRECT', 'REJECT', 'REJECT-DROP', 'PASS', 'GLOBAL')
$failures = [System.Collections.Generic.List[string]]::new()

function ConvertFrom-YamlScalar {
    param([string]$Value)

    $result = $Value.Trim()
    if ($result.Length -ge 2 -and (
        ($result.StartsWith('"') -and $result.EndsWith('"')) -or
        ($result.StartsWith("'") -and $result.EndsWith("'"))
    )) {
        return $result.Substring(1, $result.Length - 2)
    }

    return $result
}

foreach ($configFile in $configFiles) {
    $path = Join-Path $RepositoryRoot $configFile
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("Missing configuration file: $configFile")
        continue
    }

    $content = Get-Content -LiteralPath $path -Raw -Encoding utf8
    $proxyGroupSection = [regex]::Match($content, '(?ms)^proxy-groups:\s*\r?\n(?<body>.*?)(?=^rules:|\z)')
    if (-not $proxyGroupSection.Success) {
        $failures.Add("${configFile}: proxy-groups section is missing")
        continue
    }

    $groupBody = $proxyGroupSection.Groups['body'].Value
    $groupMatches = [regex]::Matches($groupBody, '(?m)^\s{2}-\s+name:\s*(?<name>.+?)\s*$')
    $groupNames = @($groupMatches | ForEach-Object { ConvertFrom-YamlScalar $_.Groups['name'].Value })

    if ($groupNames.Count -eq 0) {
        $failures.Add("${configFile}: no proxy groups found")
        continue
    }

    $duplicateNames = $groupNames | Group-Object | Where-Object Count -gt 1
    foreach ($duplicateName in $duplicateNames) {
        $failures.Add("${configFile}: duplicate proxy group '$($duplicateName.Name)'")
    }

    $targets = [System.Collections.Generic.List[string]]::new()
    $proxyGroupReferences = [System.Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $groupMatches.Count; $index++) {
        $start = $groupMatches[$index].Index + $groupMatches[$index].Length
        $end = if ($index + 1 -lt $groupMatches.Count) { $groupMatches[$index + 1].Index } else { $groupBody.Length }
        $definition = $groupBody.Substring($start, $end - $start)
        $proxiesBlock = [regex]::Match($definition, '(?ms)^\s{4}proxies:\s*\r?\n(?<items>(?:^\s{6}-\s+.+\r?\n?)*)')

        if ($proxiesBlock.Success) {
            [regex]::Matches($proxiesBlock.Groups['items'].Value, '(?m)^\s{6}-\s+(?<value>.+?)\s*$') |
                ForEach-Object { $proxyGroupReferences.Add((ConvertFrom-YamlScalar $_.Groups['value'].Value)) }
        }
    }

    foreach ($reference in ($proxyGroupReferences | Sort-Object -Unique)) {
        if ($reference -notin $builtInTargets -and $reference -notin $groupNames) {
            $failures.Add("${configFile}: static proxy reference '$reference' has no matching proxy group")
        }
    }

    foreach ($line in ($content -split "`r?`n")) {
        if ($line -notmatch '^\s*-\s+(?<rule>[^#].*)$') {
            continue
        }

        $parts = $Matches['rule'].Trim() -split ','
        if ($parts[0] -eq 'MATCH' -and $parts.Count -ge 2) {
            $targets.Add($parts[1].Trim())
        }
        elseif ($parts.Count -ge 3 -and $parts[0] -match '^(DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD|GEOSITE|GEOIP|IP-CIDR|IP-CIDR6|SRC-IP-CIDR|SRC-PORT|DST-PORT)$') {
            $targets.Add($parts[2].Trim())
        }
    }

    $dnsGroupReferences = @([regex]::Matches($content, '(?m)^\s*-\s*["'']?https?://[^"''\r\n]+#(?<name>[^&"''\r\n]+)["'']?\s*$') |
        ForEach-Object { $_.Groups['name'].Value })
    if ($dnsGroupReferences.Count -gt 0) {
        $targets.AddRange([string[]]$dnsGroupReferences)
    }

    foreach ($target in ($targets | Sort-Object -Unique)) {
        if ($target -notin $builtInTargets -and $target -notin $groupNames) {
            $failures.Add("${configFile}: '$target' is referenced but no matching proxy group exists")
        }
    }

    Write-Host "${configFile}: $($groupNames.Count) proxy groups, $($proxyGroupReferences.Count + $targets.Count) checked references"
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host 'Configuration reference validation passed.'
