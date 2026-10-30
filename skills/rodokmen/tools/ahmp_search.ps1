param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Dotaz
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$BaseUrl = 'https://katalog.ahmp.cz'
$TempDir = Join-Path ([IO.Path]::GetTempPath()) ("ahmp-" + [guid]::NewGuid().ToString('N'))
$Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
New-Item -ItemType Directory -Path $TempDir | Out-Null

function Save-Page([string]$Url, [string]$Path, [hashtable]$Form = $null) {
    if ($null -eq $Form) {
        Invoke-WebRequest -UseBasicParsing -WebSession $Session -Uri $Url -OutFile $Path | Out-Null
    } else {
        Invoke-WebRequest -UseBasicParsing -WebSession $Session -Uri $Url -Method Post -Body $Form -OutFile $Path | Out-Null
    }
}

function Run-Parser([string]$Path) {
    $CodexPython = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
    if (Test-Path -LiteralPath $CodexPython) {
        & $CodexPython -I -X utf8 (Join-Path $PSScriptRoot 'ahmp_parse.py') $Path
        return
    }
    $Python = Get-Command python -ErrorAction SilentlyContinue
    if ($Python) {
        & $Python.Source -I -X utf8 (Join-Path $PSScriptRoot 'ahmp_parse.py') $Path
        return
    }
    throw 'Chybí Python 3 (nenalezen ani runtime Codexu, ani příkaz python).'
}

try {
    $Query = [uri]::EscapeDataString($Dotaz).Replace('%20', '+')
    $SearchPath = Join-Path $TempDir 'a.html'
    Save-Page "$BaseUrl/pragapublica/searchlink?xid=7EF18906B65E11DF820F00166F1163D4&fcDb=&onlyDigi=&modeView=LIST&searchAsPhrase=&patternTxt=$Query" $SearchPath
    $SearchHtml = Get-Content -Raw -LiteralPath $SearchPath
    $SourcePage = [regex]::Match($SearchHtml, 'name="_sourcePage"\s+value="([^"]*)"').Groups[1].Value
    $Fingerprint = [regex]::Match($SearchHtml, 'name="__fp"\s+value="([^"]*)"').Groups[1].Value
    if (-not $SourcePage -or -not $Fingerprint) { throw 'Katalog AHMP nevrátil očekávané skryté parametry.' }

    $CurrentPath = Join-Path $TempDir 'p0.html'
    Save-Page "$BaseUrl/pragapublica/ViewControlImpl.action" $CurrentPath @{
        pageRows = '51'; myPageRows = ''; _sourcePage = $SourcePage; __fp = $Fingerprint
    }
    Run-Parser $CurrentPath

    foreach ($Page in 1..30) {
        $Html = Get-Content -Raw -LiteralPath $CurrentPath
        $TargetRow = $Page * 51
        $Matches = [regex]::Matches($Html, '/pragapublica/PaginatorResult\.action[^"'']*row=([0-9]+)')
        $Relative = $Matches | Where-Object { [int]$_.Groups[1].Value -eq $TargetRow } | Select-Object -First 1
        if (-not $Relative) { break }
        $Url = [System.Net.WebUtility]::HtmlDecode($Relative.Value)
        $CurrentPath = Join-Path $TempDir ("p$Page.html")
        Save-Page "$BaseUrl$Url" $CurrentPath
        Run-Parser $CurrentPath
    }
} finally {
    if (Test-Path -LiteralPath $TempDir) { Remove-Item -LiteralPath $TempDir -Recurse -Force }
}
