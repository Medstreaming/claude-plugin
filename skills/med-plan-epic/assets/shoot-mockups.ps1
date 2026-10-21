<#
.SYNOPSIS
  Screenshots every 0N-*.html mockup in a folder with headless Edge, writing <name>.png next to each page.
  Each page's window size comes from <meta name="mock-size" content="W,H"> (default 1600,1200).
.EXAMPLE
  & "<plugin-root>\skills\med-plan-epic\assets\shoot-mockups.ps1" -Folder E:\Git\build\HIP2\Task_38723\mockups
  & "<plugin-root>\skills\med-plan-epic\assets\shoot-mockups.ps1" -Folder ... -Only 03 -Index 1,3 -IndexOut C:\temp
#>
param(
    [Parameter(Mandatory = $true)][string]$Folder,
    [string[]]$Only,            # page prefixes to shoot, e.g. 02,03 (default: all)
    [int[]]$Index,              # also shoot index.html#N for these tabs (checks the narrower viewer frame)
    [string]$IndexOut           # where index-N.png goes (default: the folder's parent; keep it out of the mockups folder)
)
$ErrorActionPreference = 'Stop'
$Folder = (Resolve-Path -LiteralPath $Folder).Path
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw 'Microsoft Edge not found.' }
$url = 'file:///' + $Folder.Replace('\', '/')

function Shoot([string]$target, [string]$png, [string]$size, [string[]]$extra) {
    # A throwaway profile per shot avoids "profile in use" hangs when Edge (or a previous shot) is still running; retry once.
    for ($try = 1; $try -le 2; $try++) {
        if (Test-Path $png) { Remove-Item $png }
        $profile = Join-Path ([IO.Path]::GetTempPath()) ("mockshot-" + [guid]::NewGuid().ToString('N'))
        $argList = @('--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files', '--virtual-time-budget=4000',
            '--no-first-run', "--user-data-dir=$profile", "--window-size=$size", "--screenshot=$png") + $extra + @($target)
        $p = Start-Process -FilePath $edge -ArgumentList $argList -PassThru -WindowStyle Hidden
        $ok = $p.WaitForExit(60000)
        if (-not $ok) { try { $p.Kill() } catch {} }
        Remove-Item $profile -Recurse -Force -ErrorAction SilentlyContinue
        if ($ok -and (Test-Path $png)) { break }
        if ($try -eq 2) { throw "No screenshot written for $target (timed out or failed twice)" }
    }
    '{0,-40} {1,9:N0} bytes  ({2})' -f (Split-Path $png -Leaf), (Get-Item $png).Length, $size
}

Get-ChildItem $Folder -Filter '0*.html' | Sort-Object Name | ForEach-Object {
    $name = $_.BaseName
    # Compare page numbers numerically so -Only 3,6 and -Only 03,06 both work.
    if ($Only) { $num = if ($name -match '^(\d+)') { [int]$Matches[1] } else { -1 }; if (-not ($Only | Where-Object { [int]$_ -eq $num })) { return } }
    $m = [regex]::Match((Get-Content $_.FullName -Raw), '<meta\s+name="mock-size"\s+content="(\d+)\s*,\s*(\d+)"')
    $size = if ($m.Success) { "$($m.Groups[1].Value),$($m.Groups[2].Value)" } else { '1600,1200' }
    Shoot "$url/$($_.Name)" (Join-Path $Folder "$name.png") $size @()
}
if ($Index) {
    $out = if ($IndexOut) { $IndexOut } else { Split-Path $Folder -Parent }
    foreach ($n in $Index) { Shoot "$url/index.html#$n" (Join-Path $out "index-$n.png") '1500,950' @() }
}
