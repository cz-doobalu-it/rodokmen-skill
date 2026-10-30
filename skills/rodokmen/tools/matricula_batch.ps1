param(
    [Parameter(Mandatory = $true, Position = 0)] [string]$UrlFile,
    [Parameter(Mandatory = $true, Position = 1)] [string]$Prefix
)

$ErrorActionPreference = 'Stop'
$Magick = Join-Path $PSScriptRoot 'imagemagick\magick.exe'
if (-not (Test-Path -LiteralPath $Magick)) {
    $Command = Get-Command magick -ErrorAction SilentlyContinue
    if (-not $Command) { throw 'Chybí ImageMagick (lokální tools\imagemagick\magick.exe i příkaz magick).' }
    $Magick = $Command.Source
}

$Raw = (Get-Content -Raw -LiteralPath $UrlFile).Replace('"', '').Replace('\n', "`n")
foreach ($Line in ($Raw -split "`r?`n")) {
    if ($Line -notmatch '^\s*([0-9]+)\s+(https\S+)\s*$') { continue }
    $Page = $Matches[1]
    $Url = $Matches[2]
    $Out = "${Prefix}_${Page}.jpg"
    $Small = "${Prefix}_${Page}_s.jpg"
    if (-not (Test-Path -LiteralPath $Out) -or (Get-Item -LiteralPath $Out).Length -eq 0) {
        & (Join-Path $PSScriptRoot 'matricula_dl.ps1') -Url $Url -OutFile $Out
    }
    & $Magick $Out -resize '1900x' $Small
    if ($LASTEXITCODE -ne 0) { throw "ImageMagick selhal pro $Out." }
}
