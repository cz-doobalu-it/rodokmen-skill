param(
    [Parameter(Mandatory = $true, Position = 0)] [string]$Url,
    [Parameter(Mandatory = $true, Position = 1)] [string]$OutFile
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$TokenMatch = [regex]::Match($Url, '(?:[?&])csrf=([^&]+)')
if (-not $TokenMatch.Success) { throw 'URL neobsahuje parametr csrf.' }
$Token = [uri]::UnescapeDataString($TokenMatch.Groups[1].Value)
$Parent = Split-Path -Parent $OutFile
if ($Parent -and -not (Test-Path -LiteralPath $Parent)) { New-Item -ItemType Directory -Path $Parent | Out-Null }

$Response = Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $OutFile -Headers @{
    'User-Agent' = 'Mozilla/5.0'
    'Referer' = 'https://data.matricula-online.eu/'
    'Cookie' = "shared_csrftoken=$Token"
}
$Item = Get-Item -LiteralPath $OutFile
$ContentType = if ($Response.Headers['Content-Type']) { $Response.Headers['Content-Type'] } else { 'neznámý typ' }
Write-Output "$($Item.FullName) | $ContentType | $($Item.Length) B"
