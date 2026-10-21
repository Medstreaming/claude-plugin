<#
.SYNOPSIS
  Converts a plan/runbook Markdown file into a standalone, single-file HTML page (inline CSS/JS, no network,
  light/dark toggle, sticky contents, copy buttons on code, print styles) using the MedStreaming runbook shell.
.EXAMPLE
  & "<plugin-root>\skills\med-plan-task\md-to-html.ps1" -Markdown .\Task_38651\PLAN_Task_38651_X.md -Kicker "Task 38651"
#>
param(
    [Parameter(Mandatory = $true)][string]$Markdown,
    [string]$Output,
    [string]$Brand = 'MEDSTREAMING / ENGINEERING',
    [string]$Kicker = '',
    [string]$Badge = 'Plan'
)
$ErrorActionPreference = 'Stop'
$Markdown = (Resolve-Path -LiteralPath $Markdown).Path
if (-not $Output) { $Output = [IO.Path]::ChangeExtension($Markdown, '.html') }
$assets = Join-Path $PSScriptRoot 'assets'
$css = [IO.File]::ReadAllText((Join-Path $assets 'shell.css'))
$js = [IO.File]::ReadAllText((Join-Path $assets 'shell.js'))
$lines = [IO.File]::ReadAllLines($Markdown, [Text.Encoding]::UTF8)

function Esc([string]$s) { return [System.Net.WebUtility]::HtmlEncode($s) }

function Inline([string]$text) {
    # Protect code spans first, then escape, then apply bold/italic/links.
    $codes = New-Object System.Collections.Generic.List[string]
    $text = [regex]::Replace($text, '`([^`]+)`', { param($m) $codes.Add($m.Groups[1].Value); "@@CODE$($codes.Count - 1)@@" })
    $text = Esc $text
    $text = [regex]::Replace($text, '\[([^\]]+)\]\(([^)\s]+)\)', '<a href="$2">$1</a>')
    $text = [regex]::Replace($text, '\*\*([^*]+)\*\*', '<strong>$1</strong>')
    $text = [regex]::Replace($text, '(?<![\w*])\*([^*\s][^*]*)\*(?![\w*])', '<em>$1</em>')
    $text = [regex]::Replace($text, '@@CODE(\d+)@@', { param($m) '<code>' + (Esc $codes[[int]$m.Groups[1].Value]) + '</code>' })
    return $text
}

$title = $null
$body = New-Object System.Text.StringBuilder
$toc = New-Object System.Collections.Generic.List[string]
$lede = $null
$section = 0
$para = New-Object System.Collections.Generic.List[string]
$listStack = New-Object System.Collections.Generic.List[object]   # each: @{ Indent; Tag }
$inCode = $false; $codeLang = ''; $code = New-Object System.Text.StringBuilder
$table = $null

function FlushPara {
    if ($para.Count -gt 0) {
        $text = Inline ($para -join ' ')
        if ($section -eq 0 -and -not $script:lede) { $script:lede = $text }
        else { [void]$body.AppendLine("<p>$text</p>") }
        $para.Clear()
    }
}
function CloseLists([int]$toIndent = -1) {
    while ($listStack.Count -gt 0 -and $listStack[$listStack.Count - 1].Indent -gt $toIndent) {
        $top = $listStack[$listStack.Count - 1]
        [void]$body.AppendLine("</li></$($top.Tag)>")
        $listStack.RemoveAt($listStack.Count - 1)
    }
}
function FlushTable {
    if ($null -ne $script:table) {
        $rows = $script:table
        [void]$body.AppendLine('<div class="tablewrap"><table class="kv"><thead><tr>' +
            (($rows[0] | ForEach-Object { '<th>' + (Inline $_) + '</th>' }) -join '') + '</tr></thead><tbody>')
        for ($r = 2; $r -lt $rows.Count; $r++) {
            [void]$body.AppendLine('<tr>' + (($rows[$r] | ForEach-Object { '<td>' + (Inline $_) + '</td>' }) -join '') + '</tr>')
        }
        [void]$body.AppendLine('</tbody></table></div>')
        $script:table = $null
    }
}
function SplitRow([string]$line) {
    $t = $line.Trim()
    if ($t.StartsWith('|')) { $t = $t.Substring(1) }
    if ($t.EndsWith('|')) { $t = $t.Substring(0, $t.Length - 1) }
    return , ($t -split '\|' | ForEach-Object { $_.Trim() })
}

foreach ($raw in $lines) {
    $line = $raw.TrimEnd()
    if ($inCode) {
        if ($line.TrimStart().StartsWith('```')) {
            $label = if ($codeLang) { " data-lang=""$(Esc $codeLang)""" } else { '' }
            [void]$body.AppendLine("<div class=""codebox""$label><pre><code>" + (Esc $code.ToString().TrimEnd("`n")) + '</code></pre></div>')
            $inCode = $false; [void]$code.Clear()
        } else { [void]$code.Append($raw).Append("`n") }
        continue
    }
    if ($line.TrimStart().StartsWith('```')) {
        FlushPara; CloseLists; FlushTable
        $inCode = $true; $codeLang = $line.Trim().Substring(3).Trim(); continue
    }
    if ($line -match '^\s*\|.*\|\s*$') {
        FlushPara; CloseLists
        if ($null -eq $table) { $table = New-Object System.Collections.Generic.List[object] }
        $table.Add((SplitRow $line)); continue
    } else { FlushTable }

    if ($line -match '^(#{1,4})\s+(.*)$') {
        FlushPara; CloseLists
        $level = $Matches[1].Length; $text = $Matches[2].Trim()
        if ($level -eq 1) { if (-not $title) { $title = $text } ; continue }
        if ($level -eq 2) {
            if ($section -gt 0) { [void]$body.AppendLine('</section>') }
            $section++
            $id = "s$section"
            $toc.Add("<li><a href=""#$id"">$(Inline $text)</a></li>")
            [void]$body.AppendLine("<section id=""$id""><h2><span class=""num"">$($section.ToString('00'))</span>$(Inline $text)</h2>")
        } else {
            [void]$body.AppendLine("<h$level>$(Inline $text)</h$level>")
        }
        continue
    }
    if ($line -match '^\s*>\s?(.*)$') {
        FlushPara; CloseLists
        [void]$body.AppendLine('<div class="callout"><p>' + (Inline $Matches[1]) + '</p></div>'); continue
    }
    if ($line -match '^(\s*)([-*]|\d+\.)\s+(.*)$') {
        FlushPara
        # Capture groups before any other -match, which would overwrite $Matches.
        $indent = $Matches[1].Length; $marker = $Matches[2]; $text = Inline $Matches[3]
        $tag = if ($marker -match '^\d') { 'ol' } else { 'ul' }
        if ($listStack.Count -eq 0 -or $indent -gt $listStack[$listStack.Count - 1].Indent) {
            $cls = if ($tag -eq 'ol') { ' class="steps"' } else { '' }
            [void]$body.Append("<$tag$cls><li>$text")
            $listStack.Add(@{ Indent = $indent; Tag = $tag })
        } else {
            CloseLists $indent
            if ($listStack.Count -gt 0 -and $listStack[$listStack.Count - 1].Tag -ne $tag) {
                CloseLists ($indent - 1)
                [void]$body.Append("<$tag><li>$text"); $listStack.Add(@{ Indent = $indent; Tag = $tag })
            } elseif ($listStack.Count -eq 0) {
                [void]$body.Append("<$tag><li>$text"); $listStack.Add(@{ Indent = $indent; Tag = $tag })
            } else { [void]$body.Append("</li><li>$text") }
        }
        continue
    }
    if ($line.Trim().Length -eq 0) { FlushPara; continue }
    if ($listStack.Count -gt 0 -and $raw -match '^\s+\S') { [void]$body.Append(' ' + (Inline $line.Trim())); continue }
    CloseLists
    $para.Add($line.Trim())
}
FlushPara; CloseLists; FlushTable
if ($section -gt 0) { [void]$body.AppendLine('</section>') }
if (-not $title) { $title = [IO.Path]::GetFileNameWithoutExtension($Markdown) }

$mdName = [IO.Path]::GetFileName($Markdown)
$pills = "<span class=""pill brand"">$(Esc $Badge)</span>" + $(if ($Kicker) { "<span class=""pill"">$(Esc $Kicker)</span>" } else { '' })
$ledeHtml = if ($lede) { "<p class=""lede"">$lede</p>" } else { '' }
$page = @"
<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="$(Esc $title)">
<title>$(Esc $title)</title>
<style>
$css
.codebox[data-lang]::before{content:attr(data-lang);display:block;font:600 11px var(--mono);color:var(--faint);padding:6px 12px 0}
</style>
</head>
<body>
<header class="topbar"><div class="topbar-in">
  <span class="brand"><span class="brand-dot"></span><strong>$(Esc $Brand)</strong><small>$(if ($Kicker) { '&#183; ' + (Esc $Kicker) })</small></span><span class="spacer"></span>
  <button class="btn" id="navToggle" type="button" aria-expanded="false">Contents</button>
  <button class="btn" id="themeBtn" type="button" title="Toggle light or dark theme"><svg viewBox="0 0 16 16" aria-hidden="true"><path d="M8 1a7 7 0 1 0 7 7 5.6 5.6 0 0 1-7-7Z"/></svg><span class="label" id="themeLbl">Dark</span></button>
  <button class="btn" onclick="window.print()" type="button" title="Print or save as PDF"><svg viewBox="0 0 16 16" aria-hidden="true"><path d="M4 1h8v4H4zm-2 5h12a1 1 0 0 1 1 1v5h-3v3H4v-3H1V7a1 1 0 0 1 1-1zm3 7h6v-4H5z"/></svg><span class="label">Print</span></button>
</div></header>
<div class="shell">
<aside class="toc collapsed" id="toc"><h2>Contents</h2><ol>
  $($toc -join '')
</ol></aside>
<main>
<header class="hero"><h1>$(Inline $title)</h1><div class="pills">$pills</div>$ledeHtml</header>
$($body.ToString())
<footer>Standalone offline page generated from <a href="$(Esc $mdName)">$(Esc $mdName)</a>. No external stylesheets, scripts, fonts, or network requests. Edit the Markdown and regenerate; do not edit this file by hand.</footer>
</main></div>
<button class="totop" id="toTop" type="button" title="Back to top" aria-label="Back to top">&#8593;</button>
<script>
$js
</script>
</body>
</html>
"@
$page = ($page -replace "`r`n", "`n") -replace "`n", "`r`n"
[IO.File]::WriteAllText($Output, $page, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "Wrote $Output"
