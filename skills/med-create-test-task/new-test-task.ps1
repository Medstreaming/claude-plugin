<#
  Creates a "Test Task" linked (Related) to a main work item and posts the approved test cases as a Discussion comment.
  Gets an Azure DevOps token from `az` and calls the REST API with Invoke-RestMethod: passing HTML or URLs with '&' through
  az.cmd breaks, because cmd.exe re-parses the arguments.
  -ValidateOnly checks the create call without saving anything (no comment is posted).
#>
param(
  [Parameter(Mandatory)][int]$MainId,
  [Parameter(Mandatory)][string]$TestCasesJson,   # [{ "Id","Title","Preconditions","Steps","Expected" }]
  [Parameter(Mandatory)][string]$Org,
  [Parameter(Mandatory)][string]$Project,
  [switch]$ValidateOnly,
  [int]$CommentOnlyOn            # retry: post the comment on this existing test task id, create nothing
)
$ErrorActionPreference = 'Stop'
$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv 2>$null
if ($LASTEXITCODE -ne 0 -or -not $token) { throw "No Azure DevOps token: run 'az login --allow-no-subscriptions -o none' and retry." }
$headers = @{ Authorization = "Bearer $token" }

function Invoke-Ado([string]$Method, [string]$Uri, $Body, [string]$ContentType = 'application/json') {
  $p = @{ Method = $Method; Uri = $Uri; Headers = $headers }
  if ($null -ne $Body) {
    $json = ConvertTo-Json -InputObject $Body -Depth 10
    $p.Body = [Text.Encoding]::UTF8.GetBytes($json); $p.ContentType = "$ContentType; charset=utf-8"
  }
  Invoke-RestMethod @p
}
function Enc([string]$s) { [Net.WebUtility]::HtmlEncode($s) -replace "`r?`n", '<br/>' }

$main = Invoke-Ado GET "$Org/$Project/_apis/wit/workitems/${MainId}?api-version=7.1"
$f = $main.fields
$title = "Verify Task ${MainId}: $($f.'System.Title')"
$desc = "<div>Verify</div>" + $(if ($f.'System.Description') { $f.'System.Description' } else { "<div>$(Enc $f.'System.Title')</div>" })

$patch = @(
  @{ op = 'add'; path = '/fields/System.Title';         value = $title }
  @{ op = 'add'; path = '/fields/System.Description';   value = $desc }
  @{ op = 'add'; path = '/fields/System.AreaPath';      value = $f.'System.AreaPath' }
  @{ op = 'add'; path = '/fields/System.IterationPath'; value = $f.'System.IterationPath' }
  @{ op = 'add'; path = '/relations/-'; value = @{ rel = 'System.LinkTypes.Related'; url = $main.url; attributes = @{ comment = 'Test task for main task' } } }
)
$validate = if ($ValidateOnly) { '&validateOnly=true' } else { '' }
$new = if ($CommentOnlyOn) { @{ id = $CommentOnlyOn } } else { Invoke-Ado POST "$Org/$Project/_apis/wit/workitems/`$Test%20Task?api-version=7.1$validate" $patch 'application/json-patch+json' }
if ($ValidateOnly) { Write-Output "VALID: '$title' (Area=$($f.'System.AreaPath'); Iteration=$($f.'System.IterationPath'))"; return }

$cases = Get-Content -Raw -Encoding utf8 $TestCasesJson | ConvertFrom-Json
$th = 'style="border:1px solid #999;padding:4px;text-align:left;vertical-align:top"'
$rows = foreach ($c in $cases) {
  "<tr><td $th>$(Enc $c.Id)</td><td $th>$(Enc $c.Title)</td><td $th>$(Enc $c.Preconditions)</td><td $th>$(Enc $c.Steps)</td><td $th>$(Enc $c.Expected)</td></tr>"
}
$html = "<p><b>Test cases for Task ${MainId}</b></p><table style=`"border-collapse:collapse`"><thead><tr>" +
  (('Test Case ID', 'Title', 'Preconditions', 'Steps', 'Expected Result' | ForEach-Object { "<th $th>$_</th>" }) -join '') +
  "</tr></thead><tbody>$($rows -join '')</tbody></table>"
Invoke-Ado POST "$Org/$Project/_apis/wit/workItems/$($new.id)/comments?api-version=7.1-preview.4" @{ text = $html } | Out-Null

Write-Output "CREATED $($new.id): $title"
Write-Output "$Org/$Project/_workitems/edit/$($new.id)"
